# -*- cperl -*-
#
# MTY::Display::PrintableSymbolTools
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#
# Tools for working with printable symbols in Unicode / UTF-8
# works with most modern consoles and terminal emulators
# when using fonts which include these Unicode characters
#

package MTY::Display::PrintableSymbolTools;

use integer; use warnings; use Exporter::Lite;
# (Automatically generated by perl-mod-exports):

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($printable_symbol_spec_re $undef_placeholder enclosed_digit
     expand_with_spacers format_chunk format_quoted format_string_or_undef
     full_width_char full_width_char_code full_width_unicode_chars_for_string
     get_printable_symbol line_and_column_header line_feed_symbol
     replace_printable_symbol_names_with_characters
     shaded_background_line_prefix special_char_to_printable_symbol
     special_chars_to_printable_symbols subscript_digits
     subst_printable_symbol utf8_decode_to_int utf8_decode_to_str
     utf8_encode_int utf8_encode_str);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
use MTY::Display::ANSIColorREs;

INIT {
  binmode STDOUT,':utf8';
  binmode STDERR,':utf8';
};

sub utf8_encode_str($) {
  my ($s) = @_;
  # local (*s) = \ (@_);

  if (!defined($s)) { return undef; }
  $s = "$s";
  utf8::encode($s);
  return $s;
}

sub utf8_encode_int($) {
  my ($s) = @_;
  # local (*s) = \ (@_);

  if (!defined($s)) { return undef; }
  return utf8_encode_str(chr($s));
}

sub utf8_decode_to_str($) {
  my ($s) = @_;
  # local (*s) = \ (@_);

  if (!defined($s)) { return undef; }
  $s = "$s";
  utf8::decode($s);
  return $s;
}

sub utf8_decode_to_int($) {
  my ($s) = @_;
  # local (*s) = \ (@_);

  if (!defined($s)) { return undef; }
  return ord(utf8_decode_to_str($s));
}

our $undef_placeholder = (R.' '.big_x.' '.X);

use constant line_feed_symbol => chr(0x240a);

#use constant large_tab_symbol => heavy_horiz_bar.arrow_tri.chr(0x258d);

my $control_chars_to_printable_symbols = {
  ' '  => B.U.'_'.UX,
  "\n" => R.return_enter_key_symbol.' ',
  "\r" => R.line_feed_symbol.' ',
  "\t" => R.' '.' ',
  "\l" => R.U.'LF',
  "\f" => R.U.'FF',
  "\e" => G.' '.chr(0x241b).' ',
  "\\" => M.'\\'
};

my $control_chars_to_printable_symbols_nocolor = {
  ' ' => U.' '.UX,
  "\n" => return_enter_key_symbol.' ',
  "\r" => line_feed_symbol.' ',
  "\t" => ' '.large_tab_symbol.' ',
  "\l" => U.'LF'.UX,
  "\f" => U.'FF'.UX,
  "\e" => G.' '.chr(0x241b).' ',
  "\\" => '\\'
};

my $control_chars_with_printable_symbols_re =
  qr{(
       $ansi_console_escape_codes_re (*:ANSI) |
       (?: \s | \e) (*:PRINTABLE) |
       [\x00-\x1f] (*:CONTROL)
     )
  }oamsx;

sub special_char_to_printable_symbol($$$$$) {
  my ($special_char, $type, $table, $endcap, $force_sym_color) = @_;
  $force_sym_color //= '';
  my $escsym = warning_sign;
  my $out = $force_sym_color;

  if ($type eq 'ANSI') {
    $out .= ($special_char =~ s{\e}{$U$Y$escsym$R}roamsxg);
  } elsif ($type eq 'PRINTABLE') {
    $out .= $table->{$special_char};
  } elsif ($type eq 'CONTROL') {
    $out .= ' '.chr(0x2400 + ord($special_char)).' ';
  }

  #print(STDERR 'fsc = '.$force_sym_color.', other code ['.sprintf('0x%02x', ord($special_char)).'] => type '.$type.' => output ['.$out.$X.']'.NL);

  $out .= $endcap;
  return $out;
}

sub special_chars_to_printable_symbols($;$$) {
  if (!defined($_[0])) { return $undef_placeholder; }
  my $endcap = $_[1] // $X;
  my $force_sym_color = $_[2];
  my $table = (defined($force_sym_color)) ? 
    $control_chars_to_printable_symbols_nocolor : 
    $control_chars_to_printable_symbols;
  $force_sym_color //= '';
  #my $REGMARK = undef;
  return ($_[0] =~ s{$control_chars_with_printable_symbols_re}
                    {special_char_to_printable_symbol($1, $REGMARK, $table, $endcap, $force_sym_color)}rge);
}

sub enclosed_digit($;$) {
  my ($n, $base) = @_;
  $base //= solid_circled_large_digits;

  if (inrange($n, 1, 10)) {
    return chr($base + $n);
  } else {
    return round_bold_left_paren . $n . round_bold_right_paren;
  }
}

my %digits_to_subscripts = (
  '0' => subscript_0,
  '1' => subscript_1,
  '2' => subscript_2,
  '3' => subscript_3,
  '4' => subscript_4,
  '5' => subscript_5,
  '6' => subscript_6,
  '7' => subscript_7,
  '8' => subscript_8,
  '9' => subscript_9,
  '+' => subscript_plus,
  '-' => subscript_minus,
  '=' => subscript_equals,
  '(' => subscript_left_paren,
  ')' => subscript_right_paren
);

sub subscript_digits($) {
  my ($string) = @_;
  my $out = '';
  foreach $digit (split('', $string)) { $out .= $digits_to_subscripts{$digit} // $digit; }
  return $out;
}

our $printable_symbol_spec_re = 
  qr{(?> (0[xX] [0-9A-Fa-f]{1,4}) | (\w++))}oamsx;

my $printable_symbol_markup_re = 
  qr{(?<! \\) \% 
     (?|
       (?> \{ sym \= $printable_symbol_spec_re \}) |
       (?> \[ $printable_symbol_spec_re \])
     )
    }oamsx;

sub subst_printable_symbol($) {
  return $symbols{$_[0]} // '?';
}

my $starts_with_digit_re = qr{^\d}oax;

sub get_printable_symbol($) {
  my ($name_or_code) = @_;

  if (!defined $name_or_code) { return '?'; }

  if (length($name_or_code) == 1) { return $name_or_code; }

  if (($name_or_code =~ /$starts_with_digit_re/oax) &&
        (length($name_or_code) >= 2))
    { return chr(oct($name_or_code)); }

  return $symbols{$name_or_code} // '?';
}

sub replace_printable_symbol_names_with_characters($) {
  return ($_[0] =~ s/$printable_symbol_markup_re/defined($1) ? chr(hex($1)) : subst_printable_symbol($2)/roamsxge);
}

sub format_string_or_undef($) {
  if (!defined($_[0])) { return $R.'<'.$Y.' '.x_symbol.' '.$R.'undef>'.$X; }
  if (!length($_[0])) { return $B.'(empty)'.$X; }
  return $K.left_quote.$C.$_[0].$K.right_quote.$X;
}

sub format_quoted($;$$) {
  my ($v, $maxlength, $include_char_count) = @_;
  # local (*v, *maxlength, *include_char_count) = \ (@_);

  my $n = printed_length($v) // 0;

  if ((defined $maxlength) && ($n > $maxlength))
    { $v = substr($v, 0, $maxlength-1).$R.elipsis_three_dots; }

  if (!defined($v)) { return $R.'<'.x_symbol.' '.$Y.'undef'.$R.' '.x_symbol.'>'.$X; }

  if (!length($v)) { return $B.'(empty)'.$X; }

  my $out = $K.left_quote.$C.$v.$K.right_quote;
  $out .= $K.' (#'.$B.$n.$K.')' if ($include_char_count // 0);
  $out .= $X;
  return $out;
}

sub format_chunk($;$$$$) {
  my ($chunk, $maxlength, $subst_newlines, $color, $sym_color) = @_;
  # local (*chunk, *maxlength, *subst_newlines, *color, *sym_color) = \ (@_);

  $maxlength //= 120;
  $subst_newlines //= 1;
  $color //= $G;
  $sym_color //= $R;
  my $from_end = ($maxlength < 0);
  $maxlength = abs($maxlength);

  my $origlength = length($chunk);
  if (defined($maxlength) && ($origlength > $maxlength)) {
    $chunk = substr($chunk, ($from_end) ?
               max(($origlength - $maxlength), 0) : 0,
               min($maxlength, $origlength));
  }
  if ($subst_newlines)
    { $chunk = special_chars_to_printable_symbols($chunk, $color, $sym_color); }
  return $K.left_quote.$color.$chunk.$K.
    (($origlength > $maxlength) ? elipsis_three_dots : '').right_quote.$X;
}

sub shaded_background_line_prefix($;$) {
  my ($text, $alt_bg) = @_;

  $alt_bg //= 0;
  $alt_bg = ($alt_bg < 0) ? -1 : ($alt_bg % 2);

  my $bgcolor = 
    ($alt_bg < 0) ? bg_color_rgb(64, 32, 48) :
      ($alt_bg == 0) ? bg_color_rgb(32, 32, 32) : bg_color_rgb(20, 20, 20);

  return $bgcolor.' '.$W.$text.' '.$X;
}

sub line_and_column_header($$;$) {
  my ($line, $column, $alt_bg) = @_;

  my $line_str =
    fg_color_rgb(56, 96, 72).down_arrow_tri.fg_color_rgb(96, 168, 128).padstring($line, -5);
  my $col_str =
    fg_color_rgb(56, 72, 96).arrow_tri.fg_color_rgb(96, 128, 168).padstring($column, -3);

  return shaded_background_line_prefix($line_str.' '.$col_str, $alt_bg);
}

sub full_width_char_code($) {
  my $c = $_[0];
  return (($c >= 32) && ($c <= 126)) ? (($c - 0x20) + 0xff00) : $c;
}

sub full_width_char($) {
  my $c = ord($_[0]);
  return chr((($c >= 32) && ($c <= 126)) ? (($c - 0x20) + 0xff00) : $c);
}

sub full_width_unicode_chars_for_string($) {
  my @str = unpack('C*', $_[0]);
  my $out = '';
  foreach my $c (@str) {
    $out .= chr(full_width_char_code($c));
  }
  return $out;
}

sub expand_with_spacers($;$) {
  my ($text, $spacer) = @_;
  # local (*text, *spacer) = \ (@_);

  $spacer //= ' ';

  return join($spacer, split(//, $text));
}

1;
