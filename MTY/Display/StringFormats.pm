# -*- cperl -*-
#
# MTY::Display::PrintableSymbolTools
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#
# Utility functions for formatting strings representing
# various types of data, either as pure text or with
# enhanced colors and Unicode symbols.
#

package MTY::Display::StringFormats;

use integer; use warnings; use Exporter qw(import);
# (Automatically generated by perl-mod-exports):

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::ANSIColorREs;
use MTY::Filesystem::Files;
use MTY::RegExp::Strings;
use MTY::RegExp::FilesAndPaths;
use MTY::RegExp::PrefixStrings;
#pragma end_of_includes

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(AUTO_QUOTES ANGLE_QUOTES format_chunk DOUBLE_QUOTES SINGLE_QUOTES
     format_quoted format_auto_quoted format_double_quoted
     format_single_quoted format_all_auto_quoted format_filesystem_path
     format_string_or_undef line_and_column_header
     shaded_background_line_prefix);

sub format_string_or_undef($) {
  if (!defined($_[0])) { return $R.'<'.$Y.' '.x_symbol.' '.$R.'undef>'.$X; }
  if (!length($_[0])) { return $B.'(empty)'.$X; }
  return $K.left_quote.$C.$_[0].$K.right_quote.$X;
}

use constant enum qw(AUTO_QUOTES SINGLE_QUOTES DOUBLE_QUOTES ANGLE_QUOTES);

my @left_quote_chars = (undef, left_single_quote, left_quote, left_angle_quote);
my @right_quote_chars = (undef, right_single_quote, right_quote, right_angle_quote);

my $includes_quotes_re = qr{\A \s*+ $quote_type_and_text_re}oamsx;

my $dir_component_color = fg_color_rgb(128, 192, 240);
my $dir_sep_color = fg_color_rgb(75, 120, 160);
my $dir_sep = $dir_sep_color.large_right_slash.$dir_component_color;
my $uniform_color_dot_sep = $dir_sep_color.'.'.$dir_component_color;
my $dot_sep = G_2_3.'.'.G;
my $final_dot_sep = Y_2_3.'.'.Y;

my %prefixes_to_substs_cache = ( );

sub format_filesystem_path($;+$$) {
  my ($path, $prefixes_to_substs, $prefixes_re, $uniform_color) = @_;
  $uniform_color //= 0;
  $path =~ tr{/}{/}s; # remove redundant slashes
  my ($dirname, $filename) = split_dir_and_filename($path);
  my $dirprefix = '';
  if (defined $prefixes_to_substs) {
    if (!defined $prefixes_re) {
      $prefixes_re = $prefixes_to_substs_cache{refaddr($prefixes_to_substs)};
      if (!defined $prefixes_re) {
        $prefixes_re = prepare_prefix_string_subst_regexp(sort keys %$prefixes_to_substs);
        $prefixes_to_substs_cache{refaddr($prefixes_to_substs)} = $prefixes_re;
      }
    }

    ($dirprefix, $dirname) = 
      subst_prefix_strings_and_return_parts($dirname, $prefixes_to_substs, $prefixes_re);
    $dirprefix //= ''; $dirname //= '';
  }
  $dirname =~ s{/}{$dir_sep}oamsxg;

  my ($basename, $suffixes, $final_suffix) = 
    ($filename =~ /$split_basename_suffixes_and_final_suffix_re/oamsx);  

  $basename //= ''; $suffixes //= ''; $final_suffix //= '';
  if ($uniform_color) {
    $suffixes =~ s{\.}{$uniform_color_dot_sep}oamsxg;
    $final_suffix =~ s{\.}{$uniform_color_dot_sep}oamsxg;
    return $dirprefix.$dir_component_color.$dirname.$basename.$suffixes.$final_suffix;
  } else {
    $suffixes =~ s{\.}{$dot_sep}oamsxg;
    $final_suffix =~ s{\.}{$final_dot_sep}oamsxg;
    return $dirprefix.$dir_component_color.$dirname.G.$basename.G.$suffixes.Y.$final_suffix;
  }
}

sub format_quoted($;$$$$$$) {
  my ($v, $maxlength, $include_char_count, $quote_type, $quote_color, 
      $subst_control_chars, $sym_color) = @_;

  $include_char_count //= 0;

  if (!defined($v)) { return R.'<'.x_symbol.' '.Y.'undef'.R.' '.x_symbol.'>'.X; }

  if (!length($v)) { return B.'(empty)'.X; }

  my ($color, $colorless_string) = separate_leading_ansi_console_escape_codes($v);
  $quote_color //= ((is_there $color) ? scale_rgb_fg($color, RATIO_2_3) : K);
  $color = X if (!is_there $color);
  $sym_color //= R;

  my ($included_lq, $text, $included_rq) = ($v =~ /$includes_quotes_re/oamsx);
  my $implied_quote_type = 
    (!defined $included_lq) ? undef :
    ($included_lq eq q(")) ? DOUBLE_QUOTES :
    ($included_lq eq q(')) ? SINGLE_QUOTES :
    undef;

  $quote_type = $quote_type // DOUBLE_QUOTES;
  if ($quote_type == AUTO_QUOTES) {
    $quote_type = $implied_quote_type // DOUBLE_QUOTES; 
    $v = $text // $v;
  }

  if ($v =~ /$filesystem_path_including_directory_re/oamsx) {
    $v = format_filesystem_path($v);
  } else {
    $v = Y.$v;
  }

  my $lq = $left_quote_chars[$quote_type];
  my $rq = $right_quote_chars[$quote_type];

  my $n = printed_length($v) // 0;

  my $show_how_many_more = 
    (($maxlength // ~0) >= 4*10) && $include_char_count;
  my $overhead = ($show_how_many_more) ? (10+1) : 1;

  my $overflow = (defined $maxlength) 
    ? ($n - ($maxlength - $overhead)) : 0;

  if ($overflow > 0) {
    $v = truncate_printed_string($v, $maxlength - $overhead).
      R.elipsis_three_dots;
  }

  if ($subst_control_chars)
    { $v = special_chars_to_printable_symbols($v, $color, $sym_color); }

  my $out = $quote_color.$lq.X.$v.X.$quote_color.$rq;
  if (($overflow > 0) && $show_how_many_more)
    { $out .= R.' ('.ORANGE.($n - ($maxlength-1)).R.' more)'; }

  if ($include_char_count) 
    { $out .= $quote_color.' ('.sharp_sign.B.$n.$quote_color.')'; }

  $out .= X;
  return $out;
}

sub format_single_quoted($;$$) {
  my ($v, $maxlength, $include_char_count) = @_;
  return format_quoted($v, $maxlength, $include_char_count, SINGLE_QUOTES);
}

sub format_double_quoted($;$$) {
  my ($v, $maxlength, $include_char_count) = @_;
  return format_quoted($v, $maxlength, $include_char_count, DOUBLE_QUOTES);
}

sub format_auto_quoted($;$$) {
  my ($v, $maxlength, $include_char_count) = @_;
  return format_quoted($v, $maxlength, $include_char_count, AUTO_QUOTES);
}

sub format_all_auto_quoted($;$) {
  my ($text, $color_after) = @_;
  $color_after //= X;
  return ($text =~ s{($quoted_string_nocap_re)}{format_quoted($1, undef, undef, AUTO_QUOTES).$color_after}roamsxge);
}

sub format_chunk($;$$$$) {
  my ($chunk, $maxlength, $subst_newlines, $color, $sym_color) = @_;

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

1;