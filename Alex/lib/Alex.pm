package Alex;

use 5.030000;
use strict;
use warnings;

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

The following should be taken note of when using this module

=over

=item The Lexer

The value passed to the lexer provides hints to it.
Pass a value of 1 to hint that you're trying to lookahead
Not passing any parameters hints that you want to get a token

=item The C<$tokens> Parameter

The $tokens parameter is an array ref where each element is a hash ref.
Each of the hash ref has the following structure:

  {
    regex => qr/pattern/,
    action => sub { ... }
  }

Both C<regex> and C<action> are required.
The lexer matches C<regex> and if there is a match, C<action> is called.
The C<action> is passed 2 parameters - the text or characters that
matched the pattern, and the value of the last matched token.
C<action> should return a true value to accept the match. This is
usually the value of the token. It should return a false value to
indicate that this is actually a mismatch.

=item The C<$mismatch> Parameter

The C<$mismatch> parameter is a code ref. It is run whenever there is
a mismatch or when C<action> returns a false value.  

=back

=cut

my $lexer_factory = sub {

  my ($filename, $tokens, $mismatch) = @_;    # Fetch the parameters
  my $previous = 0;                           # Previous token

  # We provide this mismatch as default, in case this subroutine was
  # called without the $mismatch parameter
  my $_mismatch = sub {

  };

  # Return the lexer as a closure.
  return sub {

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
      # If there's anything in the buffer, pop it and return it
      if(@buffer) {
        $tok = shift @buffer;
        return $tok;
      }
      else {
        # If the buffer is empty, get the next token from the lexer
        # and return it
        $tok = $lexer->();
        return $tok
      }
    }

    # Getting here means a parameter was passed into this closure.
    $k = shift;
    $len = scalar @buffer;  # Get the number of tokens in the buffer
    
    # If there isn't enough tokens in the buffer to lookahead, then
    # fill up the buffer with just enough tokens
    until($len >= $k) {
      # The parameter value 1, here, tells the lexer we're just trying
      # to lookahead
      my $t = $lex->(1);
      # If the lexer returns a valid token, push it onto the buffer
      if($t) {
        push @buffer, $t
        $len++  # Keep track of number of tokens on the buffer
      }
      else {
        # The lexer is expected to return a false value if it couldn't
        # return a token. For example, reaching the end of the file, or
        # encountering an invalid token
        return $t;
      }

      # Now that buffer has been filled, we can comfortably look ahead
      $tok = $buffer[$k - 1];
      return $tok;
    }


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
