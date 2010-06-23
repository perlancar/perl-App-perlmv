#!perl -T

use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use FindBin '$Bin';
($Bin) = $Bin =~ /(.+)/;

our $Perl;
our $Dir;

require "$Bin/testlib.pl";
prepare_for_testing();

test_perlmv(["a.txt", "b"], {extra_opt=>"to-number-ext", verbose=>1}, ["1.txt", "2"], 'use to-number-ext');

run_perlmv({code=>'s/\.\w+$//', write=>'remove-ext'}, []);
dies_ok { run_perlmv({extra_opt=>"remove-ext"}, ["1.txt"]) } 'remove remove-ext';

end_testing();

