# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Alex.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warnings ':all';
#use Test::Trap;

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
my $mismatch_code = sub { die "Mismatch\n" };
my $random_string = "random string";
my $tokens = [(
    {
        pattern => qr/\s+/,
        action  => sub { return 1; }
    },
    {
        pattern => qr/\d+/,
        action  => sub { return 1; }
    },
    {
        pattern => qr/\w+/,
        action  => sub { return 1; }
    }
)];

open(my $file, '>>', $filename) or die "Could not create file $filename. $!\n";
say $file "1234 abcd";
close $file;

dies_ok { Alex::new() } 'Dies when no parameters are passed to Alex::new()';
dies_ok { Alex::new($filename) } 'Dies when only one parameter is passed to Alex::new()';
dies_ok { Alex::new(generate_random_string(), $tokens)} 'Dies if file to parse does not exist';
is(warning(sub { warn "You've been warned!\n" }), "You've been warned!\n", "Warns correctly");
my $warning = warning (sub {Alex::new($filename, $tokens, $mismatch_code, generate_random_string())});
is($warning, "WARNING: Too many parameters.\n");

# is(warning (sub {Alex::new $filename, $tokens, $mismatch_code, generate_random_string()}),
#    "WARNING: Too many parameters.\n", 'Warns when more than 3 parameters are passed to Alex::new');

# my $warning = warning { Alex::new(
#     $filename,
#     $tokens,
#     $mismatch_code,
#     $random_string
# )};
#is($warning, "WARNING: Too many parameters.\n", 'Warns when more than 3 parameters are passed');

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