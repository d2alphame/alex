# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Alex.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warnings;
BEGIN { use_ok('Alex') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# Temporary working directory for tests
my $alex_working_directory = '/tmp/Alex';
my $alex_test_working_directory = "$alex_working_directory/test";

mkdir $alex_working_directory or die "Could not create directory: $!\n";
mkdir $alex_test_working_directory or die "Could not create directory: $!\n";

my $filename = generate_random_string(12);
my @tokens = ();
my $mismatch_code = sub { die "Mismatch\n" };
my $random_string = "random string";

dies_ok { Alex::new() } 'Dies when no parameters are passed to new()';
dies_ok { Alex::new($filename) } 'Dies when o';
# warning { Alex::new(
#     $filename,
#     \@tokens,
#     $mismatch_code,
#     $random_string
# ) } 'Warns when more than 3 parameters are passed';
done_testing;

# Subroutine for generating a random string
sub generate_random_string {
    my $len = shift;
    $len ||= 16;
    my $str = '';
    my @chars = ('a' .. 'z', 'A' .. 'Z', '0' .. '9', '_', '-');
    $str .=  $chars[ int(rand(@chars))] for(1..$len);
}