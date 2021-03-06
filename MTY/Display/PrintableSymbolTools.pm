# -*- cperl -*-
#
# MTY::Display::PrintableSymbolTools
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#
# Tools for working with printable symbols in Unicode / UTF-8
# works with most modern consoles and terminal emulators
# when using fonts which include these Unicode characters
#

package MTY::Display::PrintableSymbolTools;

use integer; use warnings; use Exporter qw(import);
# (Automatically generated by perl-mod-exports):

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(enclosed_digit full_width_char utf8_encode_int utf8_encode_str
     line_feed_symbol subscript_digits utf8_decode_to_int utf8_decode_to_str
     expand_with_spacers full_width_char_code get_printable_symbol
     subst_printable_symbol $printable_symbol_spec_re
     special_char_to_printable_symbol special_chars_to_printable_symbols
     full_width_unicode_chars_for_string
     replace_printable_symbol_names_with_characters);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
use MTY::Display::ANSIColorREs;
use MTY::Filesystem::Files;
use MTY::RegExp::Strings;
use MTY::RegExp::FilesAndPaths;
use MTY::RegExp::PrefixStrings;
#pragma end_of_includes

INIT {
  binmode STDOUT,':utf8';
  binmode STDERR,':utf8';
};

sub utf8_encode_str($) {
  my ($s) = @_;

  if (!defined($s)) { return undef; }
  $s = "$s";
  utf8::encode($s);
  return $s;
}

sub utf8_encode_int($) {
  my ($s) = @_;

  if (!defined($s)) { return undef; }
  return utf8_encode_str(chr($s));
}

sub utf8_decode_to_str($) {
  my ($s) = @_;

  if (!defined($s)) { return undef; }
  $s = "$s";
  utf8::decode($s);
  return $s;
}

sub utf8_decode_to_int($) {
  my ($s) = @_;

  if (!defined($s)) { return undef; }
  return ord(utf8_decode_to_str($s));
}

INIT { $undef_placeholder = (R.double_left_angle_bracket.x_symbol.double_right_angle_bracket.X); };

use constant line_feed_symbol => chr(0x240a);

#use constant large_tab_symbol => heavy_horiz_bar.arrow_tri.chr(0x258d);

my $control_chars_to_printable_symbols = {
  ' '  => B.U.' '.UX,
  "\0" => B.dot_small,
  "\x07" => R.' '.warning_sign.' ', # bell (\a)
  "\x08" => R.' '.left_arrow_open_tri.' ', # backspace (\b)
  "\n" => R.' '.return_enter_key_symbol.' ', # line feed (newline)
  "\r" => R.' '.counterclockwise_curved_arrow.' ', # carriage return (CR)
  "\t" => B.under_space, # tab
  "\l" => R.U.'LF',
  "\f" => R.U.'FF',
  "\e" => R.' '.euler_e.' ',
  "\\" => M.'\\'
};

my $control_chars_to_printable_symbols_nocolor = {
  ' '  => '_',
  "\0" => dot_small,
  "\x07" => ' '.warning_sign.' ', # bell (\a)
  "\x08" => left_arrow_open_tri, # backspace (\b)
  "\n" => ' '.return_enter_key_symbol.' ', # line feed (newline) 0x0A
  "\r" => ' '.counterclockwise_curved_arrow.' ', # carriage return (CR) 0x0D
  "\t" => under_space, # tab 0x09
  "\l" => 'LF',
  "\f" => 'FF',
  "\e" => ' '.euler_e.' ',
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

  #prints(STDERR 'fsc = '.$force_sym_color.', other code ['.sprintf('0x%02x', ord($special_char)).'] => type '.$type.' => output ['.$out.$X.']'.NL);

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
  foreach my $digit (split('', $string)) { $out .= $digits_to_subscripts{$digit} // $digit; }
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

  $spacer //= ' ';

  return join($spacer, split(//, $text));
}

1;

