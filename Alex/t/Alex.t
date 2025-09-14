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

unless(-d $alex_working_directory) {
    mkdir $alex_working_directory or die "Could not create directory: $!\n";
}

unless(-d $alex_test_working_directory) {
    mkdir $alex_test_working_directory or die "Could not create directory: $!\n";
}

chdir $alex_test_working_directory;

my $filename = generate_random_string(12);
my @tokens = ();
my $mismatch_code = sub { die "Mismatch\n" };
my $random_string = "random string";

open(my $file, '>>', $filename) or die "Could not create file $filename. $!\n";
say $file "E seun, mo dupe";

dies_ok { Alex::new() } 'Dies when no parameters are passed to new()';
dies_ok { Alex::new($filename) } 'Dies when only one parameter is passed to new()';
dies_ok { Alex::new(
    generate_random_string(),
    \@tokens,
    $mismatch_code,
)} 'Dies if file to parse does not exist';


my $warning = warning { Alex::new(
    $filename,
    \@tokens,
    $mismatch_code,
    $random_string
)};
is($warning, "WARNING: Too many parameters.\n", 'Warns when more than 3 parameters are passed');
done_testing;

# Subroutine for generating a random string
sub generate_random_string {
    my $len = shift;
    $len ||= 16;
    my $str = '';
    my @chars = ('a' .. 'z', 'A' .. 'Z', '0' .. '9', '_', '-');
    $str .=  $chars[ int(rand(@chars))] for(1..$len);
    return $str;
}