package App::perlmv;
# ABSTRACT: Rename files using Perl code.

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use Getopt::Std;

=for Pod::Coverage .+

=cut

sub new {
    my ($class) = @_;

    # determine home
    my $homedir;
    if ($ENV{TESTING_HOME}) {
        $homedir = $ENV{TESTING_HOME};
    } else {
        eval { require File::HomeDir; $homedir = File::HomeDir->my_home };
        if (!$homedir) { $homedir = $ENV{HOME} }
        die "FATAL: Can't determine home directory\n" unless $homedir;
    }

    bless {
        dry_run => 0,
        homedir => $homedir,
        overwrite => 0,
        process_dir => 1,
        process_symlink => 1,
        recursive => 0,
        verbose => 0,
        mode => 'rename',
    }, $class;
}

sub load_scriptlet {
    my ($self, $name) = @_;
    $self->load_scriptlets();
    die "FATAL: Can't find scriptlet `$name`"
        unless $self->{scriptlets}{$name};
    $self->{scriptlets}{$name}{code};
}

sub load_scriptlets {
    my ($self) = @_;
    if (!$self->{scriptlets}) {
        $self->{scriptlets} = $self->find_scriptlets();
    }
}

sub find_scriptlets {
    my ($self) = @_;
    my $res = {};

    eval { require App::perlmv::scriptlets::std };
    if (%App::perlmv::scriptlets::std::scriptlets) {
        $res->{$_} = { code=>$App::perlmv::scriptlets::std::scriptlets{$_},
                       from=>"App::perlmv::scriptlets::std.pm" }
            for keys %App::perlmv::scriptlets::std::scriptlets;
    }

    eval { require App::perlmv::scriptlets };
    if (%App::perlmv::scriptlets::scriptlets) {
        $res->{$_} = { code=>$App::perlmv::scriptlets::scriptlets{$_},
                       from=>"App::perlmv::scriptlets.pm" }
            for keys %App::perlmv::scriptlets::scriptlets;
    }

    if (-d "/usr/share/perlmv/scriptlets") {
        local $/;
        for (glob "/usr/share/perlmv/scriptlets/*") {
            my $name = $_; $name =~ s!.+/!!;
            open my($fh), $_;
            my $code = <$fh>;
            $res->{$name} = { code=>$code, from => $_ }
                if $code;
        }
    }

    if (-d "$self->{homedir}/.perlmv/scriptlets") {
        local $/;
        for (glob "$self->{homedir}/.perlmv/scriptlets/*") {
            my $name = $_; $name =~ s!.+/!!;
            open my($fh), $_;
            my $code = <$fh>;
            $res->{$name} = { code=>$code, from => $_ }
                if $code;
        }
    }

    $res;
}

sub valid_scriptlet_name {
    my ($self, $name) = @_;
    $name =~ m/^[A-Za-z_][0-9A-Za-z_-]*$/;
}

sub store_scriptlet {
    my ($self, $name, $code) = @_;
    die "FATAL: Invalid scriptlet name `$name`\n"
        unless $self->valid_scriptlet_name($name);
    die "FATAL: Code not specified\n" unless $code;
    unless (-d "$self->{homedir}/.perlmv") {
        mkdir "$self->{homedir}/.perlmv" or
            die "FATAL: Can't mkdir `$self->{homedir}/.perlmv`: $!\n";
    }
    unless (-d "$self->{homedir}/.perlmv/scriptlets") {
        mkdir "$self->{homedir}/.perlmv/scriptlets" or
            die "FATAL: Can't mkdir `$self->{homedir}/.perlmv/scriptlets`: ".
                "$!\n";
    }
    # XXX warn existing file, unless -o
    open my($fh), ">$self->{homedir}/.perlmv/scriptlets/$name";
    print $fh $code;
    close $fh or
        die "FATAL: Can't write to $self->{homedir}/.perlmv/scriptlets/$name: ".
            "$!\n";
}

sub delete_user_scriptlet {
    my ($self, $name) = @_;
    unlink "$self->{homedir}/.perlmv/scriptlets/$name";
}

sub compile_code {
    my ($self) = @_;
    my $code = $self->{code};
    no strict;
    no warnings;
    local $_ = "-TEST";
    $App::perlmv::code::TESTING = 1;
    eval "package App::perlmv::code; $code";
    die "FATAL: Code doesn't compile: code=$code, errmsg=$@\n" if $@;
}

sub run_code {
    my ($self) = @_;
    my $code = $self->{code};
    no strict;
    no warnings;
    $App::perlmv::code::TESTING = 0;
    my $orig_ = $_;
    my $res = eval "package App::perlmv::code; $code";
    die "FATAL: Code doesn't compile: code=$code, errmsg=$@\n" if $@;
    if (defined($res) && length($res) && $_ eq $orig_) { $_ = $res }
}

sub process_items {
    my ($self, @items) = @_;
    @items = $self->{reverse_order} ? (reverse sort @items) : (sort @items);
    for my $item (@items) {
        next if !$self->{process_symlink} && (-l $item);
        if (-d _) {
            next unless $self->{process_dir};
            if ($self->{recursive}) {
                my $cwd = getcwd();
                if (chdir $item) {
                    print "INFO: chdir `$cwd/$item` ...\n" if $self->{verbose};
                    local *D;
                    opendir D, ".";
                    my @d = grep { $_ ne '.' && $_ ne '..' } readdir D;
                    closedir D;
                    $self->process_items(@d);
                    chdir $cwd or die "FATAL: Can't go back to `$cwd`: $!\n";
                } else {
                    warn "WARN: Can't chdir to `$cwd/$item`, skipped\n";
                }
            }
        }
        $self->process_item($item);
    }
}

sub process_item {
    my ($self, $filename) = @_;

    local $_ = $filename;
    my $old = $filename;
    $self->run_code($self->{code});
    my $new = $_;

    return if abs_path($old) eq abs_path($new);

    my $cwd = getcwd();
    my $orig_new = $new;
    unless ($self->{overwrite}) {
        my $i = 1;
        while (1) {
            if ((-e $new) || exists $self->{_exists}{"$cwd/$new"}) {
                $new = "$orig_new.$i";
                $i++;
            } else {
                last;
            }
        }
        $self->{_exists}{"$cwd/$new"}++;
    }
    my $action;
    if (!defined($self->{mode}) || $self->{mode} =~ /^(rename|r)$/) {
        $action = "rename";
    } elsif ($self->{mode} =~ /^(copy|c)$/) {
        $action = "copy";
    } elsif ($self->{mode} =~ /^(symlink|sym|s)$/) {
        $action = "symlink";
    } elsif ($self->{mode} =~ /^(hardlink|h|link|l)$/) {
        $action = "link";
    } else {
        die "Unknown mode $self->{mode}, please use one of: ".
            "rename (r), copy (c), symlink (s), or link (l).";
    }
    print "DRYRUN: " if $self->{dry_run};
    print "$action `$old` -> `$new`\n" if $self->{verbose};
    unless ($self->{dry_run}) {
        my $res;

        if ($self->{create_intermediate_dirs}) {
            my ($vol, $dir, $file) = File::Spec->splitpath($new);
            unless (-e $dir) {
                make_path($dir, {error => \my $err});
                for (@$err) {
                    my ($file, $message) = %$_;
                    warn "ERROR: Can't mkdir `$dir`: $message" .
                        ($file eq '' ? '' : " ($file)") . "\n";
                }
                return if @$err;
            }
        }

        my $err = "";
        if ($action eq 'rename') {
            $res = rename $old, $new;
            $err = $! unless $res;
        } elsif ($action eq 'copy') {
            $res = copy $old, $new;
            $err = $! unless $res;
            # XXX copy mtime, ctime, etc
        } elsif ($action eq 'symlink') {
            $res = symlink $old, $new;
            $err = $! unless $res;
        } elsif ($action eq 'link') {
            $res = link $old, $new;
            $err = $! unless $res;
        }
        warn "ERROR: $action failed `$old` -> `$new`: $err\n" unless $res;
    }
}

sub format_scriptlet_source {
    my ($self, $name) = @_;
    $self->load_scriptlets();
    die "FATAL: Scriptlet `$name` not found\n"
        unless $self->{scriptlets}{$name};
    "### Name: $name (from ", $self->{scriptlets}{$name}{from}, ")\n" .
    $self->{scriptlets}{$name}{code} .
    ($self->{scriptlets}{$name}{code} =~ /\n\z/ ? "" : "\n");
}

sub rename {
    my ($self, @items) = @_;

    $self->compile_code();
    $self->{_exists} = {};
    $self->process_items(@items);
}

sub __big_ugly_wrapper {
    # because some platforms don't support ln and ln -s. otherwise i
    # would just link the 'perlmv' command to 'perlcp', 'perlln',
    # perlln_s'.

    my %opts;
    getopts('ce:D:dfhlM:opRrSs:Vvw:', \%opts);

    # -m is reserved for file mode

    if ($opts{V}) { print "perlmv version $App::perlmv::VERSION\n"; exit 0 }
    if ($opts{h}) { print <<'USAGE'; exit 0 }
Rename files using Perl code.

Usage:

 perlmv -h

 perlmv [options] <scriptlet> <file...>
 perlmv [options] -e <code> <file...>

 perlmv -e <code> -w <name>
 perlmv -l
 perlmv -s <name>
 perlmv -D <name>

Options:

 -c  Only test compile code, do not run it on the arguments
 -e <CODE> Specify code to rename file (\$_), e.g. 's/\.old\$/\.bak/'
 -d  Dry-run (implies -v)
 -f  Only process files, do not process directories
 -h  Show this help
 -M <MODE> Specify mode, default is 'rename' (or 'r'). Use 'copy' or
     'c' to copy instead of rename, 'symlink' or 's' to create a
     symbolic link, and 'link' or 'l' to create a (hard) link.
 -o  Overwrite (by default, ".1", ".2", and so on will be appended to
     avoid overwriting existing files)
 -p  Create intermediate directories
 -R  Recursive
 -r  reverse order of processing (by default order is asciibetically)
 -S  Do not process symlinks
 -V  Print version and exit
 -v  Verbose

 -l  list all scriptlets
 -s <NAME> Show source code for scriptlet
 -w <NAME> Write code specified in -e as scriptlet
 -D <NAME> Delete scriptlet
USAGE

    my $default_mode =
        $0 =~ /cp/ ? "copy" :
        $0 =~ /ln_s/ ? "symlink" :
        $0 =~ /ln/ ? "link" :
        "rename";
    my $pmv = __PACKAGE__->new;
    $pmv->{dry_run} = $opts{d};
    $pmv->{verbose} = $opts{v} || $opts{d};
    $pmv->{reverse_order} = $opts{r};
    $pmv->{recursive} = $opts{R};
    $pmv->{process_symlink} = !$opts{S};
    $pmv->{process_dir} = !$opts{f};
    $pmv->{overwrite} = $opts{o};
    $pmv->{mode} = $opts{M} || $default_mode;
    $pmv->{create_intermediate_dirs} = $opts{p};

    if ($opts{l}) {
        $pmv->load_scriptlets();
        for (sort keys %{$pmv->{scriptlets}}) {
            if ($opts{v}) {
                print $pmv->format_scriptlet_source($_), "\n";
            } else {
                print $_, "\n";
            }
        }
        exit 0;
    }

    if ($opts{s}) {
        print $pmv->format_scriptlet_source($opts{s});
        exit 0;
    }

    if ($opts{w}) {
        $pmv->store_scriptlet($opts{w}, $opts{e});
        exit 0;
    }

    if ($opts{D}) {
        $pmv->delete_user_scriptlet($opts{D});
        exit 0;
    }

    if ($opts{e}) {
        $pmv->{code} = $opts{e};
    } else {
        die "FATAL: Must specify code (-e) or scriptlet name (first argument)"
            unless @ARGV;
        $pmv->{code} = $pmv->load_scriptlet(scalar shift @ARGV);
    }

    exit 0 if $opts{c};

    die "FATAL: Please specify some files in arguments\n" unless @ARGV;

    my @items = ();

    # do our own globbing in windows, this is convenient
    if ($^O =~ /win32/i) {
        for (@ARGV) {
            if (/[*?{}\[\]]/) { push @items, glob $_ } else { push @items, $_ }
        }
    } else {
        push @items, @ARGV;
    }

    $pmv->rename(@items);
}

1;
