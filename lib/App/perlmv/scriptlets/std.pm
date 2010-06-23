package App::perlmv::scriptlets::std;

our %scriptlets = (



    'to-number-ext' => "### Summary: Rename files into numbers. Preserve extensions. Ex: (file1.txt, foo.jpg, quux.mpg) -> (1.txt, 2.jpg, 3.mpg)\n".
q{$i||=0; $i++ unless $TESTING;
if (/.+\.(.+)/) {$ext=$1} else {$ext=undef}
$ndig = @ARGV >= 1000 ? 4 : @ARGV >= 100 ? 3 : @ARGV >= 10 ? 2 : 1;
sprintf "%0${ndig}d%s", $i, (defined($ext) ? ".$ext" : "")},



    'to-timestamp-ext' => "### Summary: Rename files into timestamp. Preserve extensions. Ex: file1.txt -> 2010-05-13-10_43_49.txt\n".
q{use POSIX; /.+\.(.+)/; $ext=$1;
@st = lstat $_;
POSIX::strftime("%Y-%m-%d-%H_%M_%S", localtime $st[9]).(defined($ext) ? ".$ext" : "")},



    'remove-common-prefix' => "### Summary: Remove prefix that are common to all args, e.g. (file1, file2b) -> (1, 2b)\n".
q{
if (!defined($COMMON_PREFIX)) {
    for ($i=0; $i<length($ARGV[0]); $i++) {
        last if grep { substr($_, $i, 1) ne substr($ARGV[0], $i, 1) } @ARGV[1..$#ARGV];
    }
    $COMMON_PREFIX = substr($ARGV[0], 0, $i);
}
s/^\Q$COMMON_PREFIX//;},



    'remove-common-suffix' => "### Summary: Remove suffix that are common to all args, e.g. (1.txt, a.txt) -> (1, a)\n".
q{if (!defined($COMMON_SUFFIX)) {
    for (@ARGV) { $_ = reverse };
    for ($i=0; $i<length($ARGV[0]); $i++) {
        last if grep { substr($_, $i, 1) ne substr($ARGV[0], $i, 1) } @ARGV[1..$#ARGV];
    }
    $COMMON_SUFFIX = reverse substr($ARGV[0], 0, $i);
    for (@ARGV) { $_ = reverse };
    # don't wipe extension, if exists
    $EXT = $COMMON_SUFFIX =~ /.(\.\w+)$/ ? $1 : "";
}
s/\Q$COMMON_SUFFIX\E$/$EXT/;},



    'pinyin' => "### Summary: Rename Chinese characters in filename into their pinyin\n".
                "### Requires: Lingua::Han::Pinyin\n".
q{use Lingua::Han::PinYin; $h||=Lingua::Han::PinYin->new; $h->han2pinyin($_)},



    'unaccent' => "### Summary: Remove accents in filename, e.g. accéder.txt -> acceder.txt\n".
                "### Requires: Text::Unaccent::PurePerl\n".
q{use Text::Unaccent::PurePerl; unac_string("UTF8", $_)},



);

1;
