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

perlln('-e', '$_++', files());
files_are('ln 1', ['1', '2', '2.1', '3', '3.1', '4']);

# XXX actually test that an extra link is created, via stat()

chdir "/";
