package Alex;

use 5.030000;
use strict;
use warnings;
use Carp;

our @ISA = qw();
our $VERSION = '0.01';


=pod

$lexer_factory, here, is an anonymous subroutine which is a factory for
producing lexers.

=head1 Parameters

=over

=item C<$filename> Scalar. Name of the file to parse

=item C<$tokens> Array of Hash refs. The hashes describe the tokens

=item C<$mismatch> Code ref. This runs whenever there's a mismatch

=back

=head1 Return

Returns a lexer as a closure.

=head1 Remarks

Whenever the Lexer is called for a token, one of 2 things could happen. The
lexer could return a true value which would represent a successfully matched
token or it could return a false value which means it has come to the end of the
file.

=head2 The C<$tokens> Parameter

The $tokens parameter is an array ref where each element is a hash ref.
Each of the hash ref has the following structure:

  {
    pattern => qr/pattern/,
    action => sub { ... },
    value => $a_value
  }

C<pattern> and C<value> are required but not C<action> .
The lexer matches C<pattern> and if there is a match, C<action> is called (if
present).
If C<action> returns a true value, then C<value> is returned as the value of the
token.
The C<action> is passed 2 parameters - the text or characters that
matched the pattern, and the length of the match
C<action> should return a true value to accept the match or a false value to
disregard it as a failed match.

Other items may optionally be added to the hash. The lexer does not do
anything with them.

=head2 The C<$mismatch> Parameter

The C<$mismatch> parameter is a code ref. It is run whenever there is
a mismatch.  

=head3 Parameters passed to C<$mismatch>

C<$mismatch> is passed a hash with the following values

=over

=item C<filename>
The name of the file where the mismatch happened

=item C<lineno>
The line number on which the mismatch happened

=item C<position>
The position within the line where the mismatch happened

=item C<token>
The actual character that could not be matched

=item C<line>
The line of text with the mismatch

=back

=cut

my $lexer_factory = sub {

  # We need at least 2 parameters. The $filename and the $tokens array
  # ref
  my $params_len = scalar @_;
  if($params_len < 2) {
    # Croak (and die) if there's less than 2 parameters
    croak "The lexer requires at least 2 parameters.\n";
  }
  elsif($params_len > 3) {
    # Issue a warning if there's more than 3 parameters
    carp "WARNING: Too many parameters.\n";
  }

  my ($filename, $tokens, $mismatch) = @_;    # Fetch the parameters

  croak "The file $filename does not exist.\n" unless(-e $filename);

  # Check that $tokens is an array ref.
  if(ref $tokens ne 'ARRAY') {
    croak "The tokens parameter should be an array ref.\n"
  }

  # We provide this _mismatch as default, in case this subroutine was
  # called without the $mismatch parameter
  my $_mismatch = sub {
    my %details = @_;
    croak <<~ "EOERROR";
    Error in file $details{filename}
    On line $details{lineno}, at position $details{position}
    Unrecognized token $details{char}
    $details{line}
    EOERROR
  };

  # If the $mismatch parameter was passed in, check to ensure that it
  # is a code ref
  if($mismatch) {
    if(ref $mismatch ne 'CODE') {
      croak "The mismatch parameter should be a code ref.\n"
    }
  }
  else {
    # If the subroutine was called without the $mismatch parameter, assign
    # the default $_mismatch which has been defined.
    $mismatch = $_mismatch;
  }

  # Check the size of the file. If the file is empty, then wer're done. There's
  # nothing to do.
  return 0 unless(-s $filename);

  # Open the passed in filename parameter.
  open(my $file,  '<', $filename)
    or croak "Could not open $filename: $!\n";
  
  my $line = <$file>;   # Read the first line from the file

  # Return the lexer as a closure.
  return sub {

    # Check if the regex has reached the end of a line and read the next
    # line if so.
    if($line =~ /\G(?=$)/gc) {
      return 0 if eof($file);    # Return 0 if we're at the end of the file
      $line = <$file>;           # Read the next line from the file

      # If we can't read the next line, then we're at the end of the file
      return 0 unless($line);
    }
    # if($line =~ /\G$/gcx) {
    #   return 0 if eof($file);
    #   $line = <$file>;    # Read the next line from the file

    #   # If we can't read the next line, then we're at the end of the file
    #   return 0 unless(defined $line);
    # }

    # Match tokens
    for(@$tokens) {
      # Each token should be represented as a hash ref
      if(ref $_ ne 'HASH') {
        croak "Each token should be defined as a hash ref.\n";
      }

      # Die if there's no 'pattern' key in a token's hash
      unless($_->{pattern}) {
        croak "Missing or undefined 'pattern' key in token's hash.\n";
      }

      # Die if there's no 'value' key in a token's hash. NOte that this would
      # also die of $_->{value} is 0 or a false value
      unless($_->{value}) {
        croak "Missing or undefined 'value' key in token's hash.\n";
      }

      # Attempt to match tokens
      if($line =~ / \G ($_->{pattern}) /gcx) {

        # Get the text that matched
        my $text = $1;

        # Get the length of the matched text
        my $len = length $1;

        # Do the action if it's present
        if($_->{action}) {
          unless(ref $_->{action} eq 'CODE') {
            croak "If the action of a token is present, it should be a CODE ref.\n";
          }
          # This is needed so that pos($line) can be reset in case $action ()
          # returns false.
          my $prev = pos($line);
          my $valid = $_->{action}($1, $len);

          # Attempt next token if 'action' returns false
          unless($valid) { pos($line) =  $prev; next };
        }

        return $_->{value};         # Return the value of the token
      }

    }

    # If we ever get here, then the array of tokens has been exhausted
    # without a match, get the offending character and call $mismatch
    $line =~ /\G(.)/gcx;

    my $mis = $mismatch->(
      filename => $filename,
      lineno => $.,
      position => pos($line),
      char => $1,
      line => $line
    );

    # Mismatch is expected to `die`. If it doesn't, however, it is expected to
    # return either a true value or a false value (undefined counts as false).
    # If it returns a true value, then that value is returned from the lexer
    # as a valid token. If it returns a false value instead, then we call our
    # default $_mismatch and die.
    return $mis if $mis;

    $mis = $_mismatch->(
      filename => $filename,
      lineno => $.,
      position => pos($line),
      char => $1,
      line => $line
    );

  }
};



=pod

TODO: 
1.  Adjust the C<create()> subroutine to use a list which is assigned to a hash.
    Add a C<eofile> token to the list of parameters. This token should be returned 
    when the end of the file is reached. 
    This would make it easier for the user to detect the end of the file instead
    of having to check for a false value.

2.  Adjust C<next_token()> and C<peek_token()> to return the C<eofile> when end
    of file is reached.

3.  Let C<create> take its parameters like this:
      sub create {
        %params = @_;
        ...
      }
    Call it like this:
      my $lexer = Alex->create(
        filename => 'file.txt',
        tokens => [...],    # So long tokens is an arrayref
        eofile => 50    # Or whatever value the user wants
        mismatch => sub { ... } # This is optional
      );

4.  By default, use a token type value of 0 for end-of-file.

This is the C<create> subroutine. It returns a lexer object. The lexer object
provides the methods C<next_token> and C<peek_token>. It is expected to be
called using the arrow object notation.

Each token passed in the C<tokens> array ref should be a hash ref with the following keys:
  {
    pattern => qr/pattern/,   # The regex pattern to match the token
    action => sub { ... },    # Optional. A code ref that runs when the token is matched. It should return a true value to accept the match or a false value to reject it.
    type => $a_value          # The value to return when this token is matched and accepted by the action (if present)
    name => "token_name"      # Optional. Useful for error reporting. It is recommended to have this.
  }

  name => "token_name" would be useful for debugging and error reporting. For example, the lexer could report the following error:
  "Expected token 'token_name' but got 'actual_token' instead on line 5 of file.txt"
=cut

sub create {
  my $class = shift;

  my $filename;
  my $tokens;
  my $eofile;
  my $mismatch;
  my $file;
  
  # Use $will_croak to track whether we should croak or not.
  # Also accumulate as many error messages as possible in $will_croak so that we can report all them
  # at once instead of just the first error we encounter.
  my $will_croak = "";

  if(scalar(@_) % 2) { 
    {
      my $l = $_[-1];
      $will_croak .= "Parameter '" . $l . "' doesn't have a value. Pass name => value pairs.\n";
    }
  }

  # Extract the parameters into an hash
  my %config = @_;

  # Do the sanity checks here.
  eval {

    # -------- Sanity checks for file and filename --------
    # =====================================================

    if($config{filename}) {
      $filename = $config{filename};
    }
    else {
      $will_croak .= "Missing or undefined parameter 'filename'\n";
    }
    # Ensure that $filename is a simple scalar
    if(ref $filename) { 
      $will_croak .= "The filename should be a simple scalar containing the name of the file.\n"
    }
    # Ensure that the file exists and is a regular file
    unless(-e $filename && -f $filename) {
      $will_croak .= "The file $filename does not exist or is not a regular file.\n";
    }
    open $file, '<', $filename or $will_croak .= "Could not open file $filename: $!\n";

    # -------- Sanity checks for eofile token --------
    # =================================================

    if(exists($config{eofile}) && defined($config{eofile})) {
      $eofile = $config{eofile};
    }
    else {
      $eofile = 0;   # Default value for end-of-file token type
    }

    # -------- Sanity checks for tokens --------
    # ==========================================

    if($config{tokens}) {
      $tokens = $config{tokens};
      # Ensure that $tokens is an array ref
      if(ref $tokens ne 'ARRAY') {
        $will_croak .= "The tokens parameter should be an array ref.\n";
      }
    }
    else {
      $will_croak .= "Missing or undefined parameter 'tokens'\n";
    }

    # -------- Sanity checks for mismatch handler --------
    # ====================================================

    if(exists($config{mismatch}) && defined($config{mismatch})) {
      $will_croak .= "The mismatch parameter should be a code ref if it is present.\n" if(ref $mismatch ne 'CODE');
      $mismatch = $config{mismatch};
    }
    else {
      # Provide a default mismatch handler
      $mismatch = sub {
        my %details = @_;
        croak <<~ "EOERROR";
        Error in file $details{filename}
        On line $details{lineno}, at position $details{position}
        Unrecognized token $details{char}
        $details{line}
        EOERROR
      };
    }
  }

  croak $will_croak if $will_croak;  # If there were any sanity check errors, report them and die

  my $line;
  $line = <$file>;   # Read the first line from the file
  return [$eofile, ""] unless(defined $line);  # First line being undefined means empty file

  return bless sub {
    state @buffer;    # Token buffer for lookahead

    my $param = shift;  # Get the parameter passed to this closure, if any
    return \@buffer if(defined $param && $param == 1);

    # Match tokens
    for(@$tokens) {
      # Do per-token sanity checks
      croak "Each token should be defined as a hash ref.\n" unless(ref $_ eq 'HASH');
      unless(exists $_->{pattern} && defined $_->{pattern}) {
        croak "Missing or undefined 'pattern' key in token's hash.\n";
      }
      unless(exists $_->{type} && defined $_->{type}) {
        croak "Missing or undefined 'type' key in token's hash.\n";
      }
      # If we've reached the end of the line, read the next line
      if($line =~ /\G$/gc) {
        $line = <$file>;
        return [$eofile, ""] unless(defined $line);  # End of file
      }
      if($line =~ /\G($_->{pattern})/gc) {
        if($_->{action}) {
          unless(ref $_->{action} eq 'CODE') {
            croak "If the action of a token is present, it should be a CODE ref.\n";
          }
          my $prev = pos($line);
          my $valid = $_->{action}($1, length $1);
          unless($valid) { pos($line) = $prev; next };
        }
        my $text = $1;
        my $len = length $1;
        return [$_->{type}, $text]
      }
    }
    # If we get here, then the array of tokens has been exhausted without a match
    $line =~ /\G(.)/gcx;
    $mismatch->(
      filename => $filename,
      lineno => $.,
      position => pos($line),
      char => $1,
      line => $line
    );
  }, $class;
}



sub next_token {
  my $lexer = shift;
  my $token_ref;
  # Get the array ref of the lexer's token buffer.
  my $buffer = $lexer->(1);
  if(scalar @$buffer) { $token_ref = shift @$buffer }
  else                { $token_ref = $lexer->(); }
  for(@_){
    return $token_ref if $token_ref->[0] == $_;
  }
  # If we get here, then it means the next token is not any of our expected tokens
}



sub peek_token {
  my $lexer = shift;
  my $k = shift;
  my $buffer = $lexer->(1);
  my $diff = $k - (scalar @$buffer);
  if($diff > 0) {
    for(1 .. $diff) {
      push @$buffer, $lexer->();
    }
  }
  my $token_ref = $buffer->[$k - 1];
  for(@_){
    return $token_ref if $token_ref->[0] == $_;
  }
  # If we get here, then it means the next token is not a token we're expecting to
  # get when we look ahead
}





=pod

This is the C<new()> subroutine. Call it to get yourself a shiny new
lexer

=head1 Parameters

=over

=item C<$filename> Scalar (I<required>). Name of the file to lex

=item C<$tokens> Array ref (I<required>). Array of Hash refs   

=item C<$mismatch> Code ref (I<optional>). Run when there's a mismatch

=back

=head1 Return
Returns a closure which can be called to get a token or to look ahead.
The returned closure is a wrapper around the lexer itself

=cut

sub new {

  # Go get a lexer with parameters passed to us
  my $lexer = $lexer_factory->(@_);
  my $tok;
  my @buffer;             # Token buffer. Used for lookahead
  my $k;

  # Closure will be returned to the user. This acts as a wrapper for
  # actual lexer
  # Call it without parameter to get the next token
  # Call it with a number to lookahead.
  return sub {

    # For tracking the number of tokens in the lookahead buffer
    my $len;
    
    # If no parameter was passed, then get next token
    unless(@_) {
      # If there's anything in the buffer, then return the first token in the buffer
      if(@buffer) {
        $tok = shift @buffer;
        return $tok;
      }
      else {
        # If the buffer is empty, get the next token from the lexer
        # and return it
        return $lexer->();
      }
    }

    # Getting here means a parameter was passed into this closure.
    $k = shift;
    $len = scalar @buffer;  # Get the number of tokens in the buffer

    
    # If there isn't enough tokens in the buffer to lookahead, then
    # fill up the buffer with just enough tokens
    until($len >= $k) {

      my $t = $lexer->();

      # If the lexer returns a valid token, push it onto the buffer
      if($t) {
        push @buffer, $t;
        $len++; # Keep track of number of tokens on the buffer
        next;
      }
      else {
        # The lexer is expected to return a false value if it couldn't
        # return a token. For example, reaching the end of the file, or
        # encountering an invalid token
        return $t;
      }
    }

    # Now that buffer has been filled, we can comfortably look ahead
    $tok = $buffer[$k - 1];
    return $tok;
  }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Alex - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Alex;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Alex, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Deji Adegbite, E<lt>deji@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2023 by Deji Adegbite

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.30.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
