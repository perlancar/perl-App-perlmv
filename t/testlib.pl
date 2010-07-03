use 5.010;
use strict;
use warnings;
use FindBin '$Bin';
use File::Path qw(remove_tree);
use File::Temp qw(tempdir);
use App::perlmv;

our $Perl;
our $Bin;
our $Dir;

sub prepare_for_testing {
    # clean for -T
    ($Perl) = $^X =~ /(.+)/;
    $ENV{PATH} = "/usr/bin:/bin";
    $ENV{ENV} = "";

    my $Dir = tempdir(CLEANUP=>1);
    $ENV{TESTING_HOME} = $Dir;
    chdir $Dir or die "Can't chdir to $Dir: $!";
}

sub end_testing {
    chdir "/";
}

# each rename will be tested twice, first using the command line
# script and then using method

sub test_perlmv {
    my ($files_before, $opts, $files_after, $test_name) = @_;

    for my $which ("method", "binary") {
        my $subdir = "rand".int(90_000_000*rand()+10_000_000);
        mkdir $subdir or die "Can't mkdir $ENV{TESTING_HOME}/$subdir: $!";
        chdir $subdir or die "Can't chdir to $ENV{TESTING_HOME}/$subdir: $!";
        create_files(@$files_before);
        run_perlmv($opts, $files_before, $which);
        files_are($files_after, "$test_name ($which)");
        remove_files();
        chdir ".." or die "Can't chdir to ..: $!";
        remove_tree($subdir) or die "Can't rmdir $ENV{TESTING_HOME}/$subdir: $!";
    }
}

sub run_perlmv {
    my ($opts, $files, $which) = @_;
    $which //= "method";

    if ($which eq 'binary') {
        my $cmd = "perlmv";
        if ($opts->{mode}) {
            given ($opts->{mode}) {
                when ('c') { $cmd = "perlcp" }
                when ('s') { $cmd = "perlln_s" }
                when ('l') { $cmd = "perlln" }
            }
        }
        $cmd = "$Bin/../bin/$cmd";
        my @cmd = ($Perl, $cmd);
        for (keys %$opts) {
            my $v = $opts->{$_};
            given ($_) {
                when ('code')          { push @cmd, "-e", $v }
                when ('compile')       { push @cmd, "-c" }
                when ('dry_run')       { push @cmd, "-d" }
                when ('mode')          { } # already processed above
                when ('extra_opt')     { } # will be processed later
                when ('before_rmtree') { } # will be processed later
                when ('overwrite')     { push @cmd, "-o" }
                when ('parents')       { push @cmd, "-p" }
                when ('reverse_order') { push @cmd, "-r" }
                when ('verbose')       { push @cmd, "-v" }
                default { die "BUG: Can't handle opts{$_} yet!" }
            }
        }
        if ($opts->{extra_opt}) { push @cmd, $opts->{extra_opt} }
        do { /(.*)/; push @cmd, $1 } for @$files;
        #print "#DEBUG: system(", join(", ", @cmd), ")\n";
        system @cmd;
        die "Can't system(", join(" ", @cmd), "): $?" if $?;
    } else {
        my $pmv = App::perlmv->new;
        for (keys %$opts) {
            my $v = $opts->{$_};
            if ($_ eq 'extra_opt') {
                $pmv->{code} = $pmv->load_scriptlet($v);
            } else {
                $pmv->{$_} = $v;
            }
        }
        print "#DEBUG: {", join(", ", map {"$_=>$opts->{$_}"} sort keys %$opts), "} rename(", join(", ", @$files), ")\n";
        if ($opts->{compile}) {
            $pmv->compile_code;
        } elsif ($opts->{write}) {
            $pmv->store_scriptlet($opts->{write}, $opts->{code});
        } elsif ($opts->{delete}) {
            $pmv->delete_user_scriptlet($opts->{delete});
        } else {
            $pmv->rename(@$files);
        }
    }
    $opts->{before_rmtree}->() if $opts->{before_rmtree};
}

# to avoid filesystem differences, we always sort and convert to
# lowercase first, and we never play with case-sensitivity.

sub create_files {
    do {open F, ">$_"; close F} for map { lc } @_;
}

sub remove_files {
    for (<*>) { my ($f) = /(.+)/; unlink $f }
}
sub files {
    my @res = sort { $a cmp $b } map { lc } <*>;
    print "#DEBUG: files() = ", join(", ", map {"'$_'"} @res), "\n";
    @res;
}

sub files_are {
    my ($files, $test_name) = @_;
    my @rfiles = files();
    my $rfiles = "[" . join(", ", @rfiles) . "]";
    if (ref($files) eq 'CODE') {
        ok($files->(\@rfiles), $test_name);
    } else {
        $files = "[" . join(", ", @$files) . "]";
        # compare as string, e.g. "[1, 2, 3]" vs "[1, 2, 3]" so
        # differences are clearly shown in test output (instead of
        # is_deeply output, which i'm not particularly fond of)
        is($rfiles, $files, $test_name);
    }
}

1;
