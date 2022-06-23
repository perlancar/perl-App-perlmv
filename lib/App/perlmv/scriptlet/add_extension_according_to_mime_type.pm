package App::perlmv::scriptlet::add_extension_according_to_mime_type;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

our $SCRIPTLET = {
    summary => q[Guess the file content's MIME type using LWP::MediaTypes then add an extension if type can be determined, or leave the filename alone otherwise],
    code => sub {
        package
            App::perlmv::code;
        require LWP::MediaTypes;

        # we skip directories
        return if -d $_;

        my $type = LWP::MediaTypes::guess_media_type($_);
        return unless $type;
        my @suffixes = LWP::MediaTypes::media_suffix($type);
        my $suffix_of_choice = LWP::MediaTypes::media_suffix($type); # since @suffixes will be in random order
        die "Bug! media_suffix() does not return suffixes for type '$type'" unless @suffixes;
        my $has_suffix;
        for my $suffix (@suffixes) {
            if (/\.\Q$suffix\E\z/i) {
                $has_suffix++;
                last;
            }
        }
        $_ = "$_.$suffix_of_choice" unless $has_suffix;
        $_;
    },
};

1;

# ABSTRACT:
