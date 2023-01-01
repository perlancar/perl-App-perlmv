package App::perlmv::scriptlet::remove_common_suffix;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

our $SCRIPTLET = {
    summary => q[Remove suffix that are common to all args, while preserving extension, e.g. (1-radiolab.mp3, 2-radiolab.mp3) -> (1.mp3, 2.mp3)],
    code => sub {
        package
            App::perlmv::code;
        our ($COMMON_SUFFIX, $TESTING, $FILES, $EXT);

        if (!defined($COMMON_SUFFIX) && !$TESTING) {
            for (@$FILES) { $_ = reverse };
            my $i;
            for ($i=0; $i<length($FILES->[0]); $i++) {
                last if grep { substr($_, $i, 1) ne substr($FILES->[0], $i, 1) } @{$FILES}[1..@$FILES-1];
            }
            $COMMON_SUFFIX = reverse substr($FILES->[0], 0, $i);
            for (@$FILES) { $_ = reverse };
            # don't wipe extension, if exists
            $EXT = $COMMON_SUFFIX =~ /.(\.\w+)$/ ? $1 : "";
        }
        s/\Q$COMMON_SUFFIX\E$/$EXT/;
        $_;
    },
};

1;

# ABSTRACT:
