package App::perlmv;
# ABSTRACT: Rename files using Perl code.

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use Getopt::Long qw(:config no_ignore_case bundling);

=for Pod::Coverage .+

=cut

sub new {
    my ($class) = @_;

    # determine home
    my $homedir;

    if ( $ENV{'TESTING_HOME'} ) {
        $homedir = $ENV{'TESTING_HOME'};
    } else {
        eval {
            require File::HomeDir;
            $homedir = File::HomeDir->my_home;
        };

        $homedir ||= $ENV{'HOME'};

        die "FATAL: Can't determine home directory\n" unless $homedir;
    }

    my $self = {
        dry_run         => 0,
        homedir         => $homedir,
        overwrite       => 0,
        process_dir     => 1,
        process_symlink => 1,
        recursive       => 0,
        verbose         => 0,
    };

    bless $self, $class;

    return $self;
}


sub parse_opts {
    my $self = shift;

    GetOptions(
        'c|check'         => \$self->{ 'check'         },
        'e|execute=s'     => \$self->{ 'code'          },
        'D|delete=s'      => \$self->{ 'delete'        },
        'd|dry-run'       => \$self->{ 'dry_run'       },
        'l|list'          => \$self->{ 'list'          },
        'M|mode=s'        => \$self->{ 'mode'          },
        'o|overwrite'     => \$self->{ 'overwrite'     },
        'p|parents'       => \$self->{ 'parents'       },
        'R|recursive'     => \$self->{ 'recursive'     },
        'r|reverse'       => \$self->{ 'reverse_order' },
        's|show=s'        => \$self->{ 'show'          },
        'v|verbose'       => \$self->{ 'verbose'       },
        'w|write=s'       => \$self->{ 'write'         },
        'f|files'         => sub { $self->{ 'process_dir'    } = 0 },
        'S|no-symlinks'   => sub { $self->{ 'process_symlink'} = 0 },
        'h|help'          => sub { $self->print_help()             },
        'V|version'       => sub { $self->print_version()          },
        '<>'              => sub { $self->parse_extra_opts(@_)     },
    ) or $self->print_help();
}

sub parse_extra_opts {
    my ( $self, $arg ) = @_;

    # do our own globbing in windows, this is convenient
    if ( $^O =~ /win32/i ) {
        if ( $arg =~ /[*?{}\[\]]/ ) { push @{ $self->{'items'} }, glob "$arg" }
        else { push @{ $self->{'items'} }, "$arg" }
    } else {
        push @{ $self->{'items'} }, "$arg";
    }
}

sub run {
    my $self = shift;

    $self->parse_opts();

    # -m is reserved for file mode
    my $default_mode =
        $0 =~ /perlcp/   ? 'copy'    :
        $0 =~ /perlln_s/ ? 'symlink' :
        $0 =~ /perlln/   ? 'link'    :
        'rename';

    $self->{'dry_run'} and $self->{'verbose'}++;
    $self->{'mode'} ||= $default_mode;

    if ( $self->{'list'} ) {
        $self->load_scriptlets();
        foreach my $key ( sort keys %{ $self->{'scriptlets'} } ) {
            print $self->{'verbose'}                        ?
                $self->format_scriptlet_source($key) . "\n" :
                "$key\n";
        }

        exit 0;
    }

    if ( $self->{'show'} ) {
        print $self->format_scriptlet_source( $self->{'show'} );
        exit 0;
    }

    if ( $self->{'write'} ) {
        $self->store_scriptlet( $self->{'write'}, $self->{'code'} );
        exit 0;
    }

    if ( $self->{'delete'} ) {
        $self->delete_user_scriptlet( $self->{'delete'} );
        exit 0;
    }

    unless ($self->{'code'}) {
        die 'FATAL: Must specify code (-e) or scriptlet name (first argument)'
            unless $self->{'items'};
        $self->{'code'} =
            $self->load_scriptlet( scalar shift @{ $self->{'items'} } );
    }
    exit 0 if $self->{'check'};

    die "FATAL: Please specify some files in arguments\n"
        unless $self->{'items'};

    $self->rename();
}

sub print_version {
    print "perlmv version $App::perlmv::VERSION\n";
    exit 0;
}

sub print_help {
    my $self = shift;
    print <<'USAGE';
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

 -c  (--compile) Only test compile code, do not run it on the arguments
 -e <CODE> (--execute) Specify code to rename file (\$_), e.g.
     's/\.old\$/\.bak/'
 -D <NAME> (--delete) Delete scriptlet
 -d  (--dry-run) Dry-run (implies -v)
 -f  (--files) Only process files, do not process directories
 -h  (--help) Show this help
 -l  (--list) list all scriptlets
 -M <MODE> (--mode) Specify mode, default is 'rename' (or 'r'). Use
     'copy' or 'c' to copy instead of rename, 'symlink' or 's' to create
     a symbolic link, and 'link' or 'l' to create a (hard) link.
 -o  (--overwrite) Overwrite (by default, ".1", ".2", and so on will be
     appended to avoid overwriting existing files)
 -p  (--parents) Create intermediate directories
 -R  (--recursive) Recursive
 -r  (--reverse) reverse order of processing (by default order is
     asciibetically)
 -S  (--no-symlinks) Do not process symlinks
 -s <NAME> (--show) Show source code for scriptlet
 -V  (--version) Print version and exit
 -v  (--verbose) Verbose
 -w <NAME> (--write) Write code specified in -e as scriptlet

USAGE

    exit 0;
}

sub load_scriptlet {
    my ( $self, $name ) = @_;
    $self->load_scriptlets();
    die "FATAL: Can't find scriptlet `$name`"
        unless $self->{'scriptlets'}{$name};
    return $self->{'scriptlets'}{$name}{'code'};
}

sub load_scriptlets {
    my ($self) = @_;
    $self->{'scriptlets'} ||= $self->find_scriptlets();
}

sub find_scriptlets {
    my ($self) = @_;
    my $res    = {};

    eval { require App::perlmv::scriptlets::std };
    if (%App::perlmv::scriptlets::std::scriptlets) {
        $res->{$_} = { code => $App::perlmv::scriptlets::std::scriptlets{$_},
                       from => "App::perlmv::scriptlets::std" }
            for keys %App::perlmv::scriptlets::std::scriptlets;
    }

    eval { require App::perlmv::scriptlets };
    if (%App::perlmv::scriptlets::scriptlets) {
        $res->{$_} = { code => $App::perlmv::scriptlets::scriptlets{$_},
                       from => "App::perlmv::scriptlets" }
            for keys %App::perlmv::scriptlets::scriptlets;
    }

    if (-d "/usr/share/perlmv/scriptlets") {
        local $/;
        for (glob "/usr/share/perlmv/scriptlets/*") {
            my $name = $_; $name =~ s!.+/!!;
            open my($fh), $_;
            my $code = <$fh>;
            $res->{$name} = { code => $code, from => $_ }
                if $code;
        }
    }

    if (-d "$self->{homedir}/.perlmv/scriptlets") {
        local $/;
        for (glob "$self->{homedir}/.perlmv/scriptlets/*") {
            my $name = $_; $name =~ s!.+/!!;
            open my($fh), $_;
            my $code = <$fh>;
            ($code) = $code =~ /(.*)/s; # untaint
            $res->{$name} = { code => $code, from => $_ }
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
    my $path = "$self->{homedir}/.perlmv";
    unless (-d $path) {
        mkdir $path or die "FATAL: Can't mkdir `$path`: $!\n";
    }
    $path .= "/scriptlets";
    unless (-d $path) {
        mkdir $path or die "FATAL: Can't mkdir `$path: $!\n";
    }
    $path .= "/$name";
    if ((-e $path) && !$self->{'overwrite'}) {
        die "FATAL: Can't overwrite `$path (use -o)\n";
    } else {
        open my($fh), ">", $path;
        print $fh $code;
        close $fh or die "FATAL: Can't write to $path: $!\n";
    }
}

sub delete_user_scriptlet {
    my ($self, $name) = @_;
    unlink "$self->{homedir}/.perlmv/scriptlets/$name";
}

sub compile_code {
    my ($self) = @_;
    my $code = $self->{'code'};
    no strict;
    no warnings;
    local $_ = "-TEST";
    local $App::perlmv::code::TESTING = 1;
    local $App::perlmv::code::COMPILING = 1;
    eval "package App::perlmv::code; $code";
    die "FATAL: Code doesn't compile: code=$code, errmsg=$@\n" if $@;
}

sub run_code_for_cleaning {
    my ($self) = @_;
    my $code = $self->{'code'};
    no strict;
    no warnings;
    local $_ = "-CLEAN";
    local $App::perlmv::code::CLEANING = 1;
    eval "package App::perlmv::code; $code";
    die "FATAL: Code doesn't run (cleaning): code=$code, errmsg=$@\n" if $@;
}

sub run_code {
    my ($self) = @_;
    my $code = $self->{'code'};
    no strict;
    no warnings;
    local $App::perlmv::code::TESTING = 0;
    local $App::perlmv::code::COMPILING = 0;
    my $orig_ = $_;
    # It does need a package declaration to run it in App::perlmv::code
    my $res = eval "package App::perlmv::code; $code";
    die "FATAL: Code doesn't compile: code=$code, errmsg=$@\n" if $@;
    if (defined($res) && length($res) && $_ eq $orig_) { $_ = $res }
}

sub process_items {
    my ($self, @items) = @_;
    @items = $self->{'reverse_order'} ? (reverse sort @items) : (sort @items);
    for my $item (@items) {
        next if !$self->{'process_symlink'} && (-l $item);
        if (-d _) {
            next unless $self->{'process_dir'};
            if ($self->{'recursive'}) {
                my $cwd = getcwd();
                if (chdir $item) {
                    print "INFO: chdir `$cwd/$item` ...\n" if $self->{'verbose'};
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
        $self->process_item($item, \@items);
    }
}

sub process_item {
    my ($self, $filename, $items) = @_;

    local $_ = $filename;
    $App::perlmv::code::FILES = $items;
    my $old = $filename;
    $self->run_code();
    my $new = $_;

    my $aold = abs_path($old);
    my $anew = abs_path($new);
    $self->{_exists}{$aold}++ if (-e $aold);
    return if $aold eq $anew;

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

    my $orig_new = $new;
    unless ($self->{'overwrite'}) {
        my $i = 1;
        while (1) {
            if ((-e $new) || exists $self->{_exists}{$anew}) {
                $new = "$orig_new.$i";
                $anew = abs_path($new);
                $i++;
            } else {
                last;
            }
        }
    }
    $self->{_exists}{$anew}++;
    delete $self->{_exists}{$aold} if $action eq 'rename';
    print "DRYRUN: " if $self->{dry_run};
    print "$action `$old` -> `$new`\n" if $self->{verbose};
    unless ($self->{dry_run}) {
        my $res;

        if ($self->{'parents'}) {
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
    my ($self, @args) = @_;
    my @items;
    if (@args) {
        @items = @args;
    } else {
        @items  = @{ $self->{'items'} // [] };
    }

    # for cleaning between run
    if ($self->{_compiled}) {
        $self->run_code_for_cleaning();
    } else {
        $self->compile_code();
        $self->{_compiled} = 1;
    }
    $self->{_exists} = {};
    $self->process_items(@items);
}

1;
