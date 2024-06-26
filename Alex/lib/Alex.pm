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

  # Open the passed in filename parameter.
  open(my $file,  '<', $filename)
    or croak "Could not open $filename: $!\n";
  
  my $line = <$file>;   # Read the first line from the file
  
  # First line undefined means the file is empty
  return 0 unless(defined $line);


  # Return the lexer as a closure.
  return sub {

    # Check if the regex has reached the end of a line and read the next
    # line if so.
    if($line =~ /\G$/gcx) {
      $line = <$file>;    # Read the next line from the file

      # If we can't read the next line, then we're at the end of the file
      return 0 unless(defined $line);
    }

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
        # If there's a match, first get its length
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

A. U. Thor, E<lt>deji@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2023 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.30.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
