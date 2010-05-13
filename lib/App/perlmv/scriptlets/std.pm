package App::perlmv::scriptlets::std;

our %scriptlets = (


    'lc' => "# Convert filenames to lowercase\n" . q[$_ = lc],


    'uc' => "# Convert filenames to uppercase\n" . q[$_ = uc],


    'with-numbers' => "# Rename files into numbers, e.g. (file1, foo, quux, qux) -> (1, 2, 3, 4)\n".
q{$i||=0; $i++ unless $TESTING;
/.+\.(.+)/; $ext=$1;
$ndig = @ARGV >= 1000 ? 4 : @ARGV >= 100 ? 3 : @ARGV >= 10 ? 2 : 1;
$_ = sprintf "%0${ndig}d%s", $i, (defined($ext) ? ".$ext" : "");'},


    'remove-common-prefix' => "# Remove prefix that are common to all args, e.g. (file1, file2b) -> (1, 2b)\n".
q{
if (!defined($COMMON_PREFIX)) {
    for ($i=0; $i<length($ARGV[0]); $i++) {
        last if grep { substr($_, $i, 1) ne substr($ARGV[0], $i, 1) } @ARGV[1..$#ARGV];
    }
    $COMMON_PREFIX = substr($ARGV[0], 0, $i);
}
s/^\Q$COMMON_PREFIX//;},


    'remove-common-suffix' => "# Remove suffix that are common to all args, e.g. (1.txt, a.txt) -> (1, a)\n".
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


    'pinyin' => "# Rename Chinese characters in filename into their pinyin\n".
q{use Lingua::Han::PinYin; $h||=Lingua::Han::PinYin->new; $_=$h->han2pinyin($_)},


);

1;
