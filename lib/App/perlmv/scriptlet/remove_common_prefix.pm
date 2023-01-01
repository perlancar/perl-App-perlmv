package App::perlmv::scriptlet::remove_common_prefix;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

our $SCRIPTLET = {
    summary => 'Remove prefix that are common to all args, e.g. (file1, file2b) -> (1, 2b)',
    code => sub {
        package
            App::perlmv::code;
        our ($COMMON_PREFIX, $TESTING, $FILES);

        if (!defined($COMMON_PREFIX) && !$TESTING) {
            my $i;
            for ($i=0; $i<length($FILES->[0]); $i++) {
                last if grep { substr($_, $i, 1) ne substr($FILES->[0], $i, 1) } @{$FILES}[1..@$FILES-1];
            }
            $COMMON_PREFIX = substr($FILES->[0], 0, $i);
        }

        s/^\Q$COMMON_PREFIX//;
        $_;
    },
};

1;

# ABSTRACT:

=head1 DESCRIPTION
