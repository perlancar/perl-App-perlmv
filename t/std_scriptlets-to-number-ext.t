#!perl

use 5.010;
use strict;
use warnings;

use Test::More tests => 2;
use FindBin '$Bin';
require "$Bin/testlib.pl";
prepare_for_testing();

test_perlmv(["a", "b.txt", "c.mp3"], {extra_opt=>"to-number-ext"}, ["1", "2.txt", "3.mp3"], 'to-number-ext');

end_testing();
