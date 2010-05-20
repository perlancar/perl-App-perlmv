#!perl -T

use strict;
use warnings;
use Test::More tests => 6;
use FindBin '$Bin';
($Bin) = $Bin =~ /(.+)/;

our $Perl;
our $Dir;

require "$Bin/testlib.pl";
prepare_for_testing();

create_files("a.txt", "b1.txt", "c2.txt", "d3");

perlmv('-ve', 's/\.txt/.text/i', files());
files_are('-e', ['a.text', 'b1.text', 'c2.text', 'd3']);

perlmv('-d', 'to-number-ext', files());
files_are('-d (dry-run)', ['a.text', 'b1.text', 'c2.text', 'd3']);

perlmv('-v', 'to-number-ext', files());
files_are('use builtin scriptlet (to-number-ext)', ['1.text', '2.text', '3.text', '4']);

perlmv('-e', 's/\..+//g', '-w', 'remove-ext');

perlmv('-s', 'remove-ext');

perlmv('remove-ext', files());
files_are('use saved scriptlet', ['1', '2', '3', '4']);

perlmv('-D', 'remove-ext');

perlmv('-e', '$_="a"', files());
files_are('automatic .\d+ suffix on conflict', ['a', 'a.1', 'a.2', 'a.3']);

perlmv('-oe', '$_="b"', files());
files_are('-o (overwrite)', ['b']);

chdir "/";

