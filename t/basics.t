#!perl -T

use strict;
use warnings;
use Test::More tests => 6;
use File::Temp qw(tempdir);
use FindBin '$Bin'; ($Bin) = $Bin =~ /(.+)/;

my ($perl) = $^X =~ /(.+)/;

my $dir = tempdir(CLEANUP=>1);
chdir $dir or die "Can't chdir to $dir: $!";
$ENV{TESTING_HOME} = $dir;
$ENV{PATH} = "/usr/bin:/bin";
$ENV{ENV} = "";

create_files("a.txt", "b1.txt", "c2.txt", "d3");

perlmv('-ve', 's/\.txt/.text/i', files());
files_are('-e', ['a.text', 'b1.text', 'c2.text', 'd3']);

perlmv('-d', 'to-number-ext', files());
files_are('-d (dry-run)', ['a.text', 'b1.text', 'c2.text', 'd3']);

perlmv('-v', 'to-number-ext', files());
files_are('use builtin scriptlet (to-number-ext)', ['1.text', '2.text', '3.text', '4']);

perlmv('-e', 's/\..+//g', '-w', 'remove-ext');
perlmv('remove-ext', files());
files_are('use saved scriptlet', ['1', '2', '3', '4']);

perlmv('-D', 'remove-ext');

perlmv('-e', '$_="a"', files());
files_are('automatic .\d+ suffix on conflict', ['a', 'a.1', 'a.2', 'a.3']);

perlmv('-oe', '$_="b"', files());
files_are('-o (overwrite)', ['b']);

chdir "/";

sub create_files {
    do {open F, ">$_"; close F} for @_;
}

sub files {
    my @res = sort map { lc } glob("*");
    #print "DEBUG: files() = ", join(", ", @res), "\n";
    @res;
}

sub files_are {
    my ($tname, $files) = @_;
    my @rfiles = files();
    is_deeply(\@rfiles, $files, $tname);
}

sub perlmv {
    my @args;
    do { /(.*)/; push @args, $1 } for @_;
    my @cmd =($perl, "$Bin/../bin/perlmv", @args);
    system @cmd;
    #print "DEBUG: system(", join(", ", @cmd), ")\n";
    die "Can't system(", join(" ", @cmd), "): $?" if $?;
}
