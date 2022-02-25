package App::perlmv::scriptlets::std;

use 5.010;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

# ABSTRACT: A collection of perlmv scriptlets

=head1 SCRIPTLETS

=cut

our %scriptlets;

=head2 dedup-space

Replace multiple spaces into a single space, example (<space>
signifies actual space): "1<space><space>2.txt " -> "1<space>2.txt"

=cut

$scriptlets{'dedup-space'} = <<'EOT';
### Summary: Replace multiple spaces into a single space, example: "1  2.txt " -> "1 2.txt"
s/\s{2,}/ /g; $_
EOT

=head2 keep-one-ext

Remove all but the last file extension if there are more than one, e.g. (1.tar,
2.mp3.mp3) -> (1.tar, 2.mp3). TODO: treat tar.gz/tar.bz2/etc as one
extension.

=cut

$scriptlets{'keep-one-ext'} = <<'EOT';
### Summary: Remove all but the last file extension if there are more than one, e.g. (1.tar, 2.mp3.mp3) -> (1.tar, 2.mp3)
s/(.+?)(?:\.\w{1,5})+(\.\w{1,5})$/$1$2/
EOT

=head2 pinyin

Rename Chinese characters in filename into their pinyin. Requires
L<Lingua::Han::Pinyin>.

=cut

$scriptlets{'pinyin'} = <<'EOT';
### Summary: Rename Chinese characters in filename into their pinyin
### Requires: Lingua::Han::Pinyin
use Lingua::Han::PinYin;
$h||=Lingua::Han::PinYin->new; $h->han2pinyin($_)
EOT

=head2 remove-ext

Remove the last file extension, e.g. (1, 2.mp3, 3.tar.gz) -> (1, 2, 3.tar)

=cut

$scriptlets{'remove-ext'} = <<'EOT';
### Summary: Remove the last file extension, e.g. (1, 2.mp3, 3.tar.gz) -> (1, 2, 3.tar)
s/(.+)\.\w{1,5}$/$1/
EOT

=head2 remove-all-ext

Remove all file extensions, e.g. (file.html.gz) -> (file)

=cut

$scriptlets{'remove-all-ext'} = <<'EOT';
### Summary: Remove all file extensions, e.g. (file.html.gz) -> (file)
s/(.+?)(?:\.\w{1,5})+$/$1/
EOT

=head2 to-number

Rename files into numbers. Ex: (file1.txt, foo.jpg, quux.mpg) -> (1.txt, 2.jpg,
3.mpg). See also: to-number-ext.

=cut

$scriptlets{'to-number'} = <<'EOT';
### Summary: Rename files into numbers. Ex: (file1.txt, foo.jpg, quux.mpg) -> (1, 2, 3)
if ($COMPILING || $CLEANING) { $i=0 } else { $i++ }
$ndig = @$FILES >= 1000 ? 4 : @$FILES >= 100 ? 3 : @$FILES >= 10 ? 2 : 1;
sprintf "%0${ndig}d", $i
EOT

=head2 to-number-ext

Rename files into numbers. Preserve extensions. Ex: (file1.txt,
foo.jpg, quux.mpg) -> (1.txt, 2.jpg, 3.mpg)

=cut

$scriptlets{'to-number-ext'} = <<'EOT';
### Summary: Rename files into numbers. Preserve extensions. Ex: (file1.txt, foo.jpg, quux.mpg) -> (1.txt, 2.jpg, 3.mpg)
if ($COMPILING || $CLEANING) { $i=0 } else { $i++ }
if (/.+\.(.+)/) {$ext=$1} else {$ext=undef}
$ndig = @$FILES >= 1000 ? 4 : @$FILES >= 100 ? 3 : @$FILES >= 10 ? 2 : 1;
sprintf "%0${ndig}d%s", $i, (defined($ext) ? ".$ext" : "")
EOT

=head2 to-timestamp

Rename files into timestamp. Ex: file1.txt -> 2010-05-13-10_43_49. See also:
to-timestamp-ext.

=cut

$scriptlets{'to-timestamp'} = <<'EOT';
### Summary: Rename files into timestamp. Ex: file1.txt -> 2010-05-13-10_43_49
use POSIX;
@st = lstat $_;
POSIX::strftime("%Y-%m-%d-%H_%M_%S", localtime $st[9])
EOT

=head2 to-timestamp-ext

Rename files into timestamp. Preserve extensions. Ex: file1.txt ->
2010-05-13-10_43_49.txt

=cut

$scriptlets{'to-timestamp-ext'} = <<'EOT';
### Summary: Rename files into timestamp. Preserve extensions. Ex: file1.txt -> 2010-05-13-10_43_49.txt
use POSIX; /.+\.(.+)/; $ext=$1;
@st = lstat $_;
POSIX::strftime("%Y-%m-%d-%H_%M_%S", localtime $st[9]).(defined($ext) ? ".$ext" : "")
EOT

=head2 trim

Remove leading and trailing blanks, example: " abc def .txt " -> "abc
def.txt"

=cut

$scriptlets{'trim'} = <<'EOT';
### Summary: Remove leading and trailing blanks, example: " abc def .txt " -> "abc def.txt"
s/^\s+//; s/\s+(\.\w{1,8})?$/$1/; $_
EOT

=head2 unaccent

Remove accents in filename, e.g. accéder.txt -> acceder.txt. Requires
L<Text::Unaccent::PurePerl>.

=cut

$scriptlets{'unaccent'} = <<'EOT';
### Summary: Remove accents in filename, e.g. accéder.txt -> acceder.txt
### Requires: Text::Unaccent::PurePerl
use Text::Unaccent::PurePerl;
unac_string("UTF8", $_)
EOT

=head2 HAVE MORE?

If you have cool scriptlets to share, feel free to contact me so I can
include them here.

=cut

1;
