#!perl -T

use strict;
use warnings;
use Test::More tests => 4;
use File::Temp qw(tempdir);
use FindBin '$Bin'; ($Bin) = $Bin =~ /(.+)/;

my ($perl) = $^X =~ /(.+)/;

my $dir = tempdir(CLEANUP=>1);
chdir $dir or die "Can't chdir to $dir: $!";
$ENV{TESTING_HOME} = $dir;
$ENV{PATH} = "/usr/bin:/bin";

create_files("A.txt", "B1.txt", "C2.txt", "c.txt");

perlmv('-ve', '$_=lc', files());
files_are('lc 1 (-e)', ['a.txt', 'b1.txt', 'c.txt', 'c2.txt']);

perlmv('-d', 'uc', files());
files_are('uc 1 (-d)', ['a.txt', 'b1.txt', 'c.txt', 'c2.txt']);

perlmv('-v', 'uc', files());
files_are('uc 2 (-v)', ['A.TXT', 'B1.TXT', 'C.TXT', 'C2.TXT']);

perlmv('-e', 's/\d+//g', '-w', 'remove-digits');
perlmv('remove-digits', files());
files_are('remove-digits 1', ['A.TXT', 'B.TXT', 'C.TXT', 'C.TXT.1']);

perlmv('-D', 'remove-digits');

chdir "/";

sub create_files {
    do {open F, ">$_"; close F} for @_;
}

sub files {
    my @res = sort {lc($a) cmp lc($b)} glob("*");
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
