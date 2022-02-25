package Complete::App::perlmv;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

use Exporter 'import';
our @EXPORT_OK = qw(
                       complete_perlmv_scriptlet
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Completion routines related to App::perlmv',
};

$SPEC{complete_perlmv_scriptlet} = {
    v => 1.1,
    summary => 'Complete from available scriptlet names',
    args => {
        word => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
};
sub complete_perlmv_scriptlet {
    require App::perlmv;
    require Complete::Util;

    my %args = @_;

    my $scriptlets = App::perlmv->new->find_scriptlets;

    Complete::Util::complete_hash_key(
        word  => $args{word},
        hash  => $scriptlets,
    );
}

1;
# ABSTRACT: Completion routines related to App::perlmv
