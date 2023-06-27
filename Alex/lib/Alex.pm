package Alex;

use 5.030000;
use strict;
use warnings;

our @ISA = qw();
our $VERSION = '0.01';


=pod

$lexer_factory, here, is an anonymous subroutine which is a factory for
producing lexers. 

=cut

my $lexer_factory = sub {
  # Return the lexer as a closure.
  return sub {

  }
};



=pod

This is the C<new()> subroutine. Call it to get yourself a shiny new
lexer

=head1 Parameters

=item C<$filename> Scalar (I<required>). Name of the file to lex
=item C<$tokens> Array ref (I<required>). Array of Hash refs   
=item C<$mismatch> Code ref (I<optional>). Run when there's a mismatch

=cut

sub new {

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
