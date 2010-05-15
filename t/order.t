#!perl -T

use strict;
use warnings;
use Test::More tests => 2;
use FindBin '$Bin';
($Bin) = $Bin =~ /(.+)/;

our $Perl;
our $Dir;

require "$Bin/testlib.pl";
prepare_for_testing();

create_files("1", "2", "3");

perlmv('-e', '$_++', files());
files_are('-r 1', ['2.1', '3.1', '4']);

remove_files();
create_files("1", "2", "3");
perlmv('-re', '$_++', files());
files_are('-r 2', ['2', '3', '4']);

chdir "/";
