package App::perlmv;
# ABSTRACT: Rename files using Perl code.

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Find;
use File::Spec;

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
    print "DRYRUN: " if $self->{dry_run};
    print "`$old` -> `$new`\n" if $self->{verbose};
    unless ($self->{dry_run}) {
        my $res = rename $old, $new;
        warn "ERROR: failed renaming $old -> $new\n" unless $res;
    }
}

sub format_scriptlet_source {
    my ($self, $name) = @_;
    load_scriptlets();
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

1;
