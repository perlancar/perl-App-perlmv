#!perl -T

BEGIN {
    $symlink_exists = eval { symlink("",""); 1 };
    unless ($symlink_exists) {
        require Test::More;
        Test::More::plan(skip_all => 'symlink not available on this platform');
    }
}

use strict;
use warnings;
use Test::More tests => 4;
use FindBin '$Bin';
($Bin) = $Bin =~ /(.+)/;

our $Perl;
our $Dir;

require "$Bin/testlib.pl";
prepare_for_testing();

create_files("1", "2", "3");

perlln_s('-e', '$_++', files());
files_are('ln_s 1', ['1', '2', '2.1', '3', '3.1', '4']);

ok((-l "2.1"), "symlink created for 1");
ok((-l "3.1"), "symlink created for 2");
ok((-l "4")  , "symlink created for 3");

chdir "/";
