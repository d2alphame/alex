package Alex;

use v5.34;
use strict;
use warnings;

use Carp;
use Readonly;
use Keyword::Declare;


=pod

Each output match is a hash ref with the following structure
{

  type => integer # The type of the token that matched
  name => string  # The name of the token that matched
  text => string  # The text or content that matched
  lineno => integer # Line number where the match was found. Useful for error reporting
  position => integer # The character position within the line, where the match was found. Useful for error reporting
  line => string # The line of text in which the match was found. Useful for error reporting

}

=cut

BEGIN {
  # If you think up any more special tokens, add them to this list
  Readonly::Array our @special_tokens => qw(
      eofile
      sofile
      eoline
      soline
      invalid
      abort
    );
  my $this = __PACKAGE__;
  {
    no strict 'refs';
    for my $i (0 .. $#special_tokens) {
      *{"$this" . "::lx_" . $special_tokens[$i]} = sub () { $i }
    }
  }
}
my $special_tokens = \@Alex::special_tokens;

sub alex {

  my %params    = @_;
  my $filename  = $params { filename  };
  my $buffer    = $params { buffer    };
  my $emit      = $params { emit      };
  my $threshold = $params { threshold };
  my $tokens    = $params { tokens    };

  my $eofile = {
    type     => lx_eofile,
    name     => "end-of-file",
    text     => undef,
    lineno   => undef,
    position => undef,
    line     => undef
  };

  my $sofile = {
    type     => lx_sofile,
    name     => "start-of-file",
    text     => "",
    lineno   => 1,
    position => 0,
    line     => undef
  };

  my $abort = {
    type     => lx_abort,
    name     => "abort",
    text     => undef,
    lineno   => undef,
    position => undef,
    line     => undef
  };

  # Don't emit these tokens by default. This is configurable 
  my $emit_sofile = 0;
  my $emit_soline = 0;
  my $emit_eoline = 0;

  for(@$emit) {
    if($_ == lx_sofile) { $emit_sofile = 1 } ;
    if($_ == lx_soline) { $emit_soline = 1 } ;
    if($_ == lx_eoline) { $emit_eoline = 1 } ;
  }

  unless(-e $filename && -f $filename) { croak "File '$filename' does not exist or is not a regular file" }
  open my $file, '<', $filename or croak "Could not open file '$filename': $!\n";

  # Getting here means the file opened successfully. So put start-of-file on the buffer
  push @$buffer, $sofile if($emit_sofile);

  # Read the first line from the file.
  my $line = <$file>;

  return bless sub { 

    state $invalid_count = 0;

    # Make eofile sticky. If we get eofile at any point, return eofile from then on
    state $got_eofile = 0;
    if($got_eofile) {
      push @$buffer, $eofile;
      return
    }

    # Make abort sticky just like eofile. If we've ever seen 'abort', then push abort
    state $got_abort = 0;
    if($got_abort) {
      push @$buffer, $abort;
      return
    }

    while(defined $line) {
      # At the beginning of the line, pos $line would be equal to 0
      unless(pos $line) {
        if($emit_soline) {
          $invalid_count = 0; # Reset invalid count for every valid token.
          push @$buffer, {
            type     => lx_soline,
            name     => "start-of-line",
            text     => "",
            lineno   => $.,
            position => 0,
            line     => $line
          }
        }
      }
      
      # Check if the regex has reached the end of the line and push end-of-line if so
      if($line =~ /\G$/gc) {
        if($emit_eoline) {
          $invalid_count = 0;
          push @$buffer, {
            type     => lx_eoline,
            name     => "end-of-line",
            text     => "\n",
            lineno   => $.,
            position => pos($line),
            line     => $line 
          }
        }
        $line = <$file> ;
        next;
      }

      # Match tokens.
      state $pos;
      my $match;
      for my $token(@$tokens) {
        $pos = pos($line);  # Grab current pos before matching. This will be useful later.
        if($line =~ /\G($token->{pattern})/gc) {
          $match = $1; my $len = length $1;
          if($token->{action}){
            my $accept = $token->{action}($match, $len);
            unless($accept){
              pos($line) = $pos; # Don't forget to reset pos in case the action rejects the match.
              next;
            }
          }
          $invalid_count = 0; # Reset invalid count for every valid token.
          push @$buffer, {
            type     => $token->{type},
            name     => $token->{name},
            text     => $match,
            lineno   => $.,
            position => $pos,
            line     => $line
          };
          return;
        }
      }
      # If we get here, it means we've exhausted the tokens and there's no match.
      $line =~ /\G(.)/gc;
      $match = $1; 
      push @$buffer, {
        type     => lx_invalid,
        name     => "invalid-token",
        text     => $match,
        lineno   => $.,
        position => pos($line),
        line     => $line
      };
      ++$invalid_count;
      if($invalid_count == $threshold){
        push @$buffer, $abort;
        $got_abort = 1;
      }
      return
    }
    # Getting here means $line is undefined meaning we're at the end of the file
    $got_eofile = 1;
    push @$buffer, $eofile;
    return;

  }, __PACKAGE__;
}


# Receives a list of expected tokens and returns the next token if it's in the list
sub alex_next {

  my $lexer      = shift;
  my $buffer     = shift;
  my $unexpected;
  {
    no strict 'refs';
    my $caller = caller; 
    $unexpected = *{"$caller" . "::__alex_unexpected__"};
  }
  
  # If the buffer is empty, call the lexer to get a token
  $lexer->() unless(@$buffer);
  my $token = shift @$buffer;
  return $token unless(@_); # If no expected tokens were provided, just return the next token
  for(@_) {
    return $token if($_ == $token->{type});
  }
  $unexpected->($token, @_); # Notify by calling the 'unexpected()' callback, which is expected to 'die()'
  return {
    type     => lx_abort,
    name     => "abort",
    text     => undef,
    lineno   => undef,
    position => undef,
    line     => undef
  };
}


sub alex_peek {
  my $lexer      = shift;
  my $buffer     = shift;
  my $k = shift;
  $k ||= 1;

  push @$buffer, $lexer->() while(@$buffer < $k);
  return $buffer->[$k - 1];
}


sub alex_scan {

}


sub alex_fill {

  my $lexer  = shift;
  my $buffer = shift;
  my $count  = shift;

  $count ||= 5;

  push @$buffer, $lexer->() while(@$buffer < $count);
  return scalar(@$buffer);
}


sub alex_find {

}


sub alex_seq {

}



sub import {

  my $package  = shift;
  my $tokens   = shift;
  my $caller   = caller;

  my $count    = scalar(@$tokens);
  my @names;

  {
    no strict 'refs';

    for my $j (0 .. $count - 1) {
      $tokens->[$j]{type} = $j;
      *{"$caller" . "::lx_" . $tokens->[$j]{name}} = sub () { $j };  # Create a constant subroutine for each token type
      push @names, $tokens->[$j]{name};
    }

    for my $i (0 .. @$special_tokens - 1) {
      my $k = $count + $i;
     *{"$caller" . "::lx_" . $special_tokens->[$i]} = sub () { $k };  # Constant sub routines for the special token types
    }

    # Make the names token Readonly and add to caller's namespace
    Readonly::Array @names => @names;
    *{"$caller" . "::AlexTokenNames"} = \@names;

    *{"$caller" . "::Alex"} = sub {
      state $emit       = [];
      state $threshold  = 10;
      state $unexpected = sub { "Custom handler" };
      my %params;

      # Called in void context means just configure
      unless(defined wantarray) {
        %params     = @_;
        $emit       = $params { emit       } // [];
        $threshold  = $params { threshold  } // 6;
        $unexpected = $params { unexpected } // sub {
          my $msg;
          my $found = shift;
          if($found->{type} == lx_abort) {
            croak "Error: Terminated due to too many invalid tokens.\n";
          }
          if($found->{type} == lx_invalid) {
            $msg = "Found invalid token "
          }
        };

        *{"$caller" . "::__alex_unexpected__"} = $unexpected;
        return;
      }
      # Called in scalar context means give me a lexer
      unless(wantarray){
        %params = @_;
        my $filename = shift;
        my $buffer   = shift;
        return alex
                filename  => $filename,
                buffer    => $buffer,
                emit      => $emit,
                threshold => $threshold,
                tokens    => $tokens;
      }
    };
  }

  # Grab the 'alex' keyword and process it
  keyword alex (String $filename, Block $block) {
    return <<~"EOAlex";
    {
      my \@__alex_buffer__;
      my \$__lexer__ = Alex($filename, \\\@__alex_buffer__);
      my sub alex_next { my \$t = \$__lexer__->alex_next(\\\@__alex_buffer__, \@_) ; return \$t }
      my sub alex_peek { my \$t = \$__lexer__->alex_peek(\\\@__alex_buffer__, \@_) ; return \$t }
      my sub alex_fill { my \$t = \$__lexer__->alex_fill(\\\@__alex_buffer__, \@_) ; return \$t }
      $block
    }
    EOAlex
  }
}

1