#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Display::ANSIColorREs
#
# Regular expressions for ANSI color terminal escape codes
#
# Copyright 2002 - 2015 Matt T. Yourst <yourst@yourst.com>
#

#
# NOTE: MTY::Display::Colorize is the primary user of these regexps,
# but they are in an independent module since we sometimes need to
# simply filter out any ANSI color escape codes when writing to a
# file or terminal that doesn't support color - in this case we may
# not even want to load the Colorize module in the first place.
#

package MTY::Display::ANSIColorREs;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($ansi_console_escape_codes_re
     $ansi_console_escapes_and_nonprinted_characters_re
     $ansi_console_escapes_and_nonprinted_control_chars_and_unicode_re
     $ansi_indexed_bg_color_re $ansi_indexed_color_re
     $ansi_indexed_fg_color_re $ansi_reset_colors_re $ansi_rgb_bg_color_re
     $ansi_rgb_color_re $ansi_rgb_fg_color_re $ansi_rgb_or_indexed_bg_color_re
     $ansi_rgb_or_indexed_color_re $ansi_rgb_or_indexed_fg_color_re
     $color_markup_re $colorize_markup_chars_re
     separate_leading_ansi_console_escape_codes
     strip_ansi_console_escape_codes);

use MTY::RegExp::Define;
#pragma end_of_includes

our $ansi_console_escape_codes_re = compile_regexp(
  qr{(?> \e 
       (?> 
         [cDEFHMZ78NOPXlmno\|\}\~\^\>\=\*\+\\] | 
         (?> % [G8@]) | (?> [\(\)] [B0UK])
       )
     ) |
     (?>
       (?: \x9B | \e \[ ) \?? 
       \d++ (?> ; \d++)*+ [A-Za-z\@\`]
     ) |
     (?> \] \d*+ ; 
       [^\e\007]++ 
       (?: \e \\ | \007)
     )}oamsx, 'ansi_console_escape_codes');

our $ansi_reset_colors_re = compile_regexp(
  qr{\e \[ 0 m}oax,
  'ansi_reset_colors_re');

our $ansi_indexed_fg_color_re = compile_regexp(
  qr{\e \[ (?> 1 ;)?+ 3[012345679] m}oax,
  'ansi_indexed_fg_color');

our $ansi_indexed_bg_color_re = compile_regexp(
  qr{\e \[ (?> 1 ;)?+ 4[012345679] m}oax,
  'ansi_indexed_bg_color');

our $ansi_indexed_color_re = compile_regexp(
  qr{\e \[ (?> 1 ;)?+ [34][012345679] m}oax,
  'ansi_indexed_color');

our $ansi_rgb_fg_color_re = compile_regexp(
  qr{\e \[ 38 ; 2 ; (\d++) ; (\d++) ; (\d++) m}oax,
  'ansi_rgb_fg_color');

our $ansi_rgb_bg_color_re = compile_regexp(
  qr{\e \[ 48 ; 2 ; (\d++) ; (\d++) ; (\d++) m}oax,
  'ansi_rgb_bg_color');

our $ansi_rgb_color_re = compile_regexp(
  qr{\e \[ [34]8 ; 2 ; (\d++) ; (\d++) ; (\d++) m}oax,
  'ansi_rgb_color');

our $ansi_rgb_or_indexed_fg_color_re = compile_regexp(
  qr{\e \[ (?> 1 ;)?+ 3 (?>
       (?> 8 ; 2 ; (\d++) ; (\d++) ; (\d++)) |
       (?> ([012345679]) )) m}oax,
  'ansi_rgb_or_indexed_fg_color');

our $ansi_rgb_or_indexed_bg_color_re = compile_regexp(
  qr{\e \[ (?> 1 ;)?+ 4 (?> 
       (?> 8 ; 2 ; (\d++) ; (\d++) ; (\d++)) |
       (?> ([012345679]) )) m}oax,
  'ansi_rgb_or_indexed_bg_color');

our $ansi_rgb_or_indexed_color_re = compile_regexp(
  qr{\e \[ (?> 1 ;)?+ [34] (?>
       (?> 8 ; 2 ; (\d++) ; (\d++) ; (\d++)) |
       (?> ([012345679]) )) m}oax,
  'ansi_rgb_or_indexed_color');

sub strip_ansi_console_escape_codes($) {
  my ($s) = @_;

  $s =~ s/$ansi_console_escape_codes_re//oamsxg;
  return $s;
}

my $leading_ansi_codes_plus_text_re = 
  qr{\A ( (?> $ansi_console_escape_codes_re)*+ ) (.*+) \Z}oamsx;

sub separate_leading_ansi_console_escape_codes($) {
  my ($s) = @_;

  return (($s =~ /$leading_ansi_codes_plus_text_re/oamsxg) 
            ? ($1, $2) : ('', $s));
}

our $ansi_console_escapes_and_nonprinted_characters_re = compile_regexp(
  qr{(?> $ansi_console_escape_codes_re) | 
     [\x00-\x08\x0B\x0C\x0E-\x1A\x1C-\x1F]
    }oamsx, 'ansi_console_escapes_and_nonprinted_characters');

our $ansi_console_escapes_and_nonprinted_control_chars_and_unicode_re = compile_regexp(
  qr{(?> $ansi_console_escape_codes_re) |
     (?> [^[:ascii:]]) | 
     [\x00-\x08\x0B\x0C\x0E-\x1A\x1C-\x1F]}oamsx, 
  'ansi_console_escapes_and_nonprinted_control_chars_and_unicode');

our $colorize_markup_chars_re = 
  qr{[RGBCMYKWQrgbcmykwq%] | \!? [UNVX]}oax;

our $color_markup_re = compile_regexp(
  qr{(?<! \\) \% 
      (?|
        (?> ($colorize_markup_chars_re)) |
        (?> \{ ($colorize_markup_chars_re) \})
      )}oamsx, 'color_markup');
