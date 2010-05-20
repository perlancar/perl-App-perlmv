#!perl -T

use strict;
use warnings;
use Test::More tests => 1;
use FindBin '$Bin';
($Bin) = $Bin =~ /(.+)/;

our $Perl;
our $Dir;

require "$Bin/testlib.pl";
prepare_for_testing();

create_files("1", "2", "3");

perlcp('-e', '$_++', files());
files_are('cp 1', ['1', '2', '2.1', '3', '3.1', '4']);

chdir "/";
