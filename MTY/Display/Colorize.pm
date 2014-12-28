#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Display::Colorize
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#
# Colorize: ANSI console colors and attributes for any terminal
# (works with Linux console, XTerm, Mac OS X, BSD, Solaris, etc)
#

package MTY::Display::Colorize;

use integer; use warnings; use Exporter::Lite;

#
# Note that we add additional dynamically generated exports 
# for all the color constants below:
#

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($B $BLINK $BLINKX $C $CLEAR_SCREEN $CLEAR_TAB_STOPS
     $ERASE_FROM_START_OF_LINE_TO_CURSOR $ERASE_LINE $ERASE_TO_END_OF_LINE $G
     $K $M $Q $R $RESTORE_CURSOR_POS $SAVE_CURSOR_POS
     $SET_TAB_IN_CURRENT_COLUMN $U $UX $V $VX $W $X $Y $bgB $bgC $bgG $bgK
     $bgM $bgQ $bgR $bgW $bgY $color_enabled %basic_color_markup_to_code_map
     %color_markup_to_code_map %color_style_codes %custom_color_values
     %custom_colors %enhanced_color_markup_to_code_map %fixed_colors
     %rgb_color_values %rgb_colors %scaled_custom_colors %scaled_rgb_colors
     @all_color_symbols @custom_color_symbols @fixed_color_symbols
     ANSI_CONSOLE_ESC ANSI_CONSOLE_OSC ANSI_CONSOLE_SET_BG ANSI_CONSOLE_SET_FG
     COLOR_B COLOR_C COLOR_G COLOR_K COLOR_M COLOR_Q COLOR_R COLOR_W COLOR_Y
     END_OSC_ST EOE SET_ANSI_COLOR_TO_RGB SET_XTERM_FONT
     SET_XTERM_SESSION_TITLE SET_XTERM_WINDOW_TITLE
     __scale_rgb_fg_in_array_recursively adjust_luminance bg_color_rgb bg_gray
     blend_and_scale_rgb_bg blend_and_scale_rgb_bg_in_string
     blend_and_scale_rgb_fg blend_and_scale_rgb_fg_in_string blend_rgb
     blend_rgb_bg blend_rgb_bg_in_string blend_rgb_fg blend_rgb_fg_in_string
     clear_screen clear_tab_stops color_and_style_sample_text
     color_sample_text colorize disable_color enable_color
     enable_color_based_on_console enable_color_based_on_filehandle
     enable_color_based_on_stderr enable_color_based_on_stdout fg_color_rgb
     fg_gray generate_scaled_rgb_constants get_tab_stop_codes
     get_terminal_height_in_lines get_terminal_width_in_columns luminance
     move_cursor_to_column move_cursor_to_row move_cursor_to_row_and_column
     replace_color_code reveal_ansi_console_escape_code
     reveal_ansi_console_escape_codes rgb_of_color_code
     rgb_of_color_code_components scale_rgb scale_rgb_bg
     scale_rgb_bg_in_string scale_rgb_fg scale_rgb_fg_in_array
     scale_rgb_fg_in_array_recursively scale_rgb_fg_in_string scale_rgb_values
     set_console_attribute set_console_subtitle set_console_title
     set_rgb_bg_in_string set_tab_stops update_terminal_dimensions);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::System::POSIX;
use MTY::System::Misc;
use MTY::Filesystem::Ioctl;
use MTY::Display::ANSIColorREs;
use MTY::Display::ColorCapabilityCheck;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::RegExp::Define;
use MTY::Display::PrintableSymbols;
#pragma end_of_includes

use constant ANSI_CONSOLE_ESC => ESC.'['; # ANSI SGR escape
use constant ANSI_CONSOLE_OSC => ESC.']'; # extended operating system command (OSC)

use constant {
  ANSI_CONSOLE_SET_FG => ANSI_CONSOLE_ESC.'1;3',
  ANSI_CONSOLE_SET_BG => ANSI_CONSOLE_ESC.'1;4',
  EOE => 'm',
  END_OSC_ST => chr(007),
};

our ($R, $G, $B, $C, $M, $Y, $K, $W, $Q);
our ($bgR, $bgG, $bgB, $bgC, $bgM, $bgY, $bgK, $bgW, $bgQ);
our ($U, $UX, $V, $VX, $BLINK, $BLINKX, $X);
our ($CLEAR_SCREEN, $SAVE_CURSOR_POS, $RESTORE_CURSOR_POS,
     $CLEAR_TAB_STOPS, $SET_TAB_IN_CURRENT_COLUMN);
our ($ERASE_TO_END_OF_LINE, $ERASE_FROM_START_OF_LINE_TO_CURSOR, $ERASE_LINE);

our %color_style_codes;

BEGIN {
  %color_style_codes = (
    X => ANSI_CONSOLE_ESC.'0'.EOE,
    U => ANSI_CONSOLE_ESC.'4'.EOE,
    V => ANSI_CONSOLE_ESC.'7'.EOE,
    BLINK => ANSI_CONSOLE_ESC.'5'.EOE,
    UX => ANSI_CONSOLE_ESC.'24'.EOE,
    VX => ANSI_CONSOLE_ESC.'27'.EOE,
    BLINKX => ANSI_CONSOLE_ESC.'25'.EOE,
  )
};

use constant \%color_style_codes;

# These won't be auto-generated by perl-mod-deps:
push @EXPORT, qw(X U V BLINK UX VX BLINKX);

BEGIN {
  ($X, $U, $UX, $V, $VX, $BLINK, $BLINKX) = (X, U, UX, V, VX, BLINK, BLINKX);
};

our $color_enabled = 0;

sub fg_color_rgb {
  if (!defined $_[0]) { return X; }
  my $rgb = ((ref $_[0]) ? $_[0] : \@_);
  return ESC.'[38;2;'.$rgb->[0].';'.$rgb->[1].';'.$rgb->[2].'m';
}

sub bg_color_rgb {
  my $rgb = ((ref $_[0]) ? $_[0] : \@_);
  return ESC.'[48;2;'.$rgb->[0].';'.$rgb->[1].';'.$rgb->[2].'m';
}

sub fg_gray($) { return fg_color_rgb($_[0], $_[0], $_[0]); }
sub bg_gray($) { return bg_color_rgb($_[0], $_[0], $_[0]); }

use constant {
  COLOR_R => 1,
  COLOR_G => 2,
  COLOR_B => 4,
  COLOR_C => 6,
  COLOR_M => 5,
  COLOR_Y => 3,
  COLOR_K => 9,
  COLOR_W => 7,
  COLOR_Q => 0,
};

our %fixed_colors;
our %rgb_colors;
our %rgb_color_values;
our %custom_color_values;
our %custom_colors;
our @fixed_color_symbols;
our @custom_color_symbols;
our @all_color_symbols;

BEGIN {
  @fixed_color_symbols = qw(R G B C M Y K W Q);

  %fixed_colors = (
    R => ANSI_CONSOLE_SET_FG.'1'.EOE,
    G => ANSI_CONSOLE_SET_FG.'2'.EOE,
    B => ANSI_CONSOLE_SET_FG.'4'.EOE,
    C => ANSI_CONSOLE_SET_FG.'6'.EOE,
    M => ANSI_CONSOLE_SET_FG.'5'.EOE,
    Y => ANSI_CONSOLE_SET_FG.'3'.EOE,
    K => ANSI_CONSOLE_SET_FG.'9'.EOE,
    W => ANSI_CONSOLE_SET_FG.'7'.EOE,
    Q => ANSI_CONSOLE_SET_FG.'0'.EOE,

    bgR => ANSI_CONSOLE_SET_BG.'1'.EOE,
    bgG => ANSI_CONSOLE_SET_BG.'2'.EOE,
    bgB => ANSI_CONSOLE_SET_BG.'4'.EOE,
    bgC => ANSI_CONSOLE_SET_BG.'6'.EOE,
    bgM => ANSI_CONSOLE_SET_BG.'5'.EOE,
    bgY => ANSI_CONSOLE_SET_BG.'3'.EOE,
    bgK => ANSI_CONSOLE_SET_BG.'9'.EOE,
    bgW => ANSI_CONSOLE_SET_BG.'7'.EOE,
    bgQ => ANSI_CONSOLE_SET_BG.'0'.EOE,
  );

  %rgb_color_values = (
    R => [248, 112, 112],
    G => [96,  255, 128],
    B => [128, 116, 255],
    C => [80,  224, 240],
    M => [255, 140, 255],
    Y => [255, 255, 64],
    K => [140, 140, 140],
    W => [240, 240, 240],
    Q => [0,   0,   0],
  );

  %custom_color_values = (
    ORANGE => [255, 128, 0],
    SKYBLUE => [64, 192, 240]
  );

  @custom_color_symbols = keys %custom_color_values;
  @all_color_symbols = (@fixed_color_symbols, @custom_color_symbols);

  %rgb_colors = (
    (map { ($_, fg_color_rgb($rgb_color_values{$_})) } @fixed_color_symbols),
    (map { ('bg'.$_, bg_color_rgb($rgb_color_values{$_})) } @fixed_color_symbols)
  );

  %custom_colors = (
    (map { ($_, fg_color_rgb($custom_color_values{$_})) } @custom_color_symbols),
    (map { ('bg'.$_, bg_color_rgb($custom_color_values{$_})) } @custom_color_symbols)
  );
};

use constant \%rgb_colors;
use constant { (map { 'rgb'.$_, $rgb_color_values{$_} } @fixed_color_symbols) };
use constant { (map { 'rgbfg'.$_, $rgb_colors{$_} } @fixed_color_symbols) };
use constant { (map { 'rgbbg'.$_, $rgb_colors{'bg'.$_} } @fixed_color_symbols) };

use constant \%custom_colors;

# These won't be auto-generated by perl-mod-deps:
push @EXPORT, (map { ($_, 'bg'.$_, 'rgb'.$_, 'rgbfg'.$_, 'rgbbg'.$_) } @fixed_color_symbols);
push @EXPORT, (map { ($_, 'bg'.$_) } @custom_color_symbols);

my @console_color_index_to_rgb;

BEGIN {
  @console_color_index_to_rgb = 
    (rgbQ, rgbR, rgbG, rgbY, rgbB, rgbM, rgbC, rgbW, undef, rgbK);
};

sub rgb_of_color_code_components {
  my ($r, $g, $b, $index) = @_;

  if (defined $index) { ($r, $g, $b) = @{$console_color_index_to_rgb[$index]}; }
  return (wantarray ? ($r, $g, $b) : [ $r, $g, $b ]);
}

sub rgb_of_color_code($) {
  my ($cc) = @_;

  if ($cc =~ /$ansi_rgb_or_indexed_color_re/oax) 
    { return rgb_of_color_code_components($1, $2, $3, $4); }
  else { return (0, 0, 0); }
}

#
# Scaling RGB color with multiplier and optional offset
#

sub scale_rgb_values($$$$;$) {
  my ($r, $g, $b, $scale, $offset) = @_;

  if (any_empty($r, $g, $b, $scale)) {
    warn(NL.'WARNING: scale_rgb_values: undefined arguments: '.
         'r = '.($r // '<undef>').', '.
         'g = '.($g // '<undef>').', '.
         'b = '.($b // '<undef>').', '.
         'scale = '.($scale // '<undef>').')');

    return (wantarray ? (0, 0, 0) : [0, 0, 0]); 
  }

  no integer;
  $offset //= 0.0;
  
  $r = min(int(round(($r * $scale) + $offset)), 255);
  $g = min(int(round(($g * $scale) + $offset)), 255);
  $b = min(int(round(($b * $scale) + $offset)), 255);

  return (wantarray ? ($r, $g, $b) : [$r, $g, $b]);
  use integer;
}

sub scale_rgb(+$;$) {
  my ($rgb, $scale, $offset) = @_;
  if ($rgb eq X) { return undef; }
  my ($r, $g, $b) = (is_array_ref($rgb)) ? @$rgb : rgb_of_color_code($rgb);
  return scale_rgb_values($r, $g, $b, $scale, $offset);
}

sub scale_rgb_fg(+$;$) {
  my ($rgb, $scale, $offset) = @_; 
  return fg_color_rgb(scale_rgb($rgb, $scale, $offset)); 
}

sub scale_rgb_bg(+$;$) {
  my ($rgb, $scale, $offset) = @_; 
  return bg_color_rgb(scale_rgb($rgb, $scale, $offset)); 
}

sub scale_rgb_fg_in_string($$;$) {
  my ($s, $scale, $offset) = @_; 
  return ($s =~ s{$ansi_rgb_or_indexed_color_re}
                 {scale_rgb_fg(rgb_of_color_code_components($1, $2, $3, $4), $scale, $offset)}roaxge); 
}

sub scale_rgb_bg_in_string($$;$) {
  my ($s, $scale, $offset) = @_; 
  return ($s =~ s{$ansi_rgb_or_indexed_color_re}
                 {scale_rgb_bg(rgb_of_color_code_components($1, $2, $3, $4), $scale, $offset)}roaxge); 
}

sub scale_rgb_fg_in_array(+$;$) {
  my ($array, $scale, $offset) = @_;
  $recursive //= 1;

  foreach my $v (@$array) {
    if (is_string($v)) { $v = scale_rgb_fg_in_string($v, $scale, $offset); }
  }
  
  return $array;
}

noexport:; sub __scale_rgb_fg_in_array_recursively { # (+$;$)
  my ($array, $scale, $offset) = @_;

  foreach my $v (@$array) {
    if (is_string($v)) {
      $v = scale_rgb_fg_in_string($v, $scale, $offset); 
    } elsif (is_array_ref($v)) {
      __scale_rgb_fg_in_array_recursively($v, $scale, $offset);
    }
  }
  
  return $array;
}

sub scale_rgb_fg_in_array_recursively(+$;$) {
  my ($array, $scale, $offset) = @_;
  return __scale_rgb_fg_in_array_recursively($array, $scale, $offset);
}

#
# Blending two RGB colors, with optional bias coefficient towards first or second color
#
sub blend_rgb(++;$) {
no integer;
  my ($rgb, $blend_with, $second_color_coeff) = @_;
  $second_color_coeff //= 0.5;
  my $first_color_coeff = 1.0 - $second_color_coeff;

  my ($r, $g, $b) = (is_array_ref($rgb)) ? @$rgb : rgb_of_color_code($rgb);
  my ($rr, $gg, $bb) = @$blend_with;

  return (int(($r * $first_color_coeff) + ($rr * $second_color_coeff)),
          int(($g * $first_color_coeff) + ($gg * $second_color_coeff)),
          int(($b * $first_color_coeff) + ($bb * $second_color_coeff)));
use integer;
}

sub blend_rgb_fg(++;$) {
  my ($rgb, $blend_with, $second_color_coeff) = @_; 
  return fg_color_rgb(blend_rgb($rgb, $blend_with, $second_color_coeff));
}

sub blend_rgb_bg(++;$) {
  my ($rgb, $blend_with, $second_color_coeff) = @_; 
  return bg_color_rgb(blend_rgb($rgb, $blend_with, $second_color_coeff)); 
}

sub blend_rgb_fg_in_string($+;$) {
  my ($s, $blend_with, $second_color_coeff) = @_; 
  my $white = rgbfgW;
  return ((X.$s) 
            =~ s{$ansi_reset_colors_re}{$X$white}roaxg
            =~ s{$ansi_rgb_or_indexed_fg_color_re}
                {blend_rgb_fg([rgb_of_color_code_components($1, $2, $3, $4)], $blend_with, $second_color_coeff)}roaxge); 
}

sub blend_rgb_bg_in_string($+;$) {
  my ($s, $blend_with, $second_color_coeff) = @_; 
  my $white = rgbbgW;
  return ((X.$s) 
            =~ s{$ansi_reset_colors_re}{$X$white}roaxg
            =~ s{$ansi_rgb_or_indexed_bg_color_re}
                {blend_rgb_bg(rgb_of_color_code_components($1, $2, $3, $4), $blend_with, $second_color_coeff)}roaxge); 
}

sub blend_and_scale_rgb_fg(++;$$$) {
  my ($rgb, $blend_with, $scale, $second_color_coeff, $offset) = @_; 
  my ($r, $g, $b) = blend_rgb($rgb, $blend_with, $second_color_coeff);
  return fg_color_rgb(scale_rgb_values($r, $g, $b, $scale, $offset));
}

sub blend_and_scale_rgb_bg(++;$$$) {
  my ($rgb, $blend_with, $scale, $second_color_coeff, $offset) = @_; 
  my ($r, $g, $b) = blend_rgb($rgb, $blend_with, $second_color_coeff);
  return bg_color_rgb(scale_rgb_values($r, $g, $b, $scale, $offset));
}

sub blend_and_scale_rgb_fg_in_string($+;$$$) {
  my ($s, $blend_with, $scale, $second_color_coeff, $offset) = @_; 
  my $white = rgbfgW;
  return ((X.$s) 
            =~ s{$ansi_reset_colors_re}{$X$white}roaxg
            =~ s{$ansi_rgb_or_indexed_fg_color_re}
                {blend_and_scale_rgb_fg([rgb_of_color_code_components($1, $2, $3, $4)], $blend_with, $scale, $second_color_coeff, $offset)}roaxge); 
}

sub blend_and_scale_rgb_bg_in_string($+;$$$) {
  my ($s, $blend_with, $scale, $second_color_coeff, $offset) = @_; 
  my $black = rgbbgK;
  return ((X.$s) 
            =~ s{$ansi_reset_colors_re}{$X$black}roaxg
            =~ s{$ansi_rgb_or_indexed_bg_color_re}
                {blend_and_scale_rgb_bg([rgb_of_color_code_components($1, $2, $3, $4)], $blend_with, $scale, $second_color_coeff, $offset)}roaxge); 
}

sub set_rgb_bg_in_string($+;$$$) {
  my ($s, $rgb) = @_; 
  my $bg = X.(is_array_ref($rgb) ? bg_color_rgb($rgb) : $rgb);

  return $bg.($s =~ s{$ansi_reset_colors_re}{$bg}roaxg);
}

my @exported_color_names;

my @scale_coeffs;

BEGIN {
  no integer;
  @scale_coeffs = ([7,8], [3,4], [2,3], [1,2], [1,3], [1,4]);
  use integer;
}

noexport:; sub generate_scaled_rgb_constants(+) {
  my ($color_values) = @_;
no integer;
  my @out = ( );
  foreach my $frac (@scale_coeffs) {
    my ($n, $d) = @$frac;
    my $scale = $n / $d;

    push @out, (map { 
      my ($r, $g, $b) = @{$color_values->{$_}}; 
    (
      $_.'_'.$n.'_'.$d =>
      fg_color_rgb(scale_rgb_values($r, $g, $b, $scale))
    ) } (keys %$color_values));

    push @exported_color_names, 
      (map { $_.'_'.$n.'_'.$d } keys %$color_values);
  }
  return @out;
use integer;
}

our %scaled_rgb_colors;
our %scaled_custom_colors;

BEGIN {
  %scaled_rgb_colors = generate_scaled_rgb_constants(%rgb_color_values);
  %scaled_custom_colors = generate_scaled_rgb_constants(%custom_color_values);
};

use constant \%scaled_rgb_colors;
use constant \%scaled_custom_colors;

push @EXPORT, @exported_color_names;

sub adjust_luminance($$$$) {
  no integer;
  my ($r, $g, $b, $f) = @_;
 
  $r = int(($r * $f) + 0.5);
  $g = int(($g * $f) + 0.5);
  $b = int(($b * $f) + 0.5);
  use integer; 
  return ($r, $g, $b);
}

sub luminance($;$$) {
  my ($r, $g, $b) = @_;

  if (substr($r, 0, 1) eq ESC) { ($r, $g, $b) = rgb_of_color_code($r); }

  no integer;
  my $luma = int(($r * 0.21) + ($g * 0.72) + ($b * 0.07));
  use integer;
  return $luma;
}

my @color_style_code_symbols = qw(U N V !U !N !V X);

my @color_style_code_markup_to_code_map = (
  'U' => U, 'N' => BLINK, 'V' => V, 
  '!U' => UX, '!N' => BLINKX, '!V' => VX,
  'X' => X, '!X' => X,
);

our %basic_color_markup_to_code_map = (
  @color_style_code_markup_to_code_map,
  (%fixed_colors),
  'r' => bgR, 'g' => bgG, 'b' => bgB, 
  'c' => bgC, 'm' => bgM, 'y' => bgY, 
  'k' => bgK, 'w' => bgW, 'q' => bgQ,
);

our %enhanced_color_markup_to_code_map = (
  @color_style_code_markup_to_code_map,
  (%rgb_colors),
  'r' => rgbbgR, 'g' => rgbbgG, 'b' => rgbbgB, 
  'c' => rgbbgC, 'm' => rgbbgM, 'y' => rgbbgY, 
  'k' => rgbbgK, 'w' => rgbbgW, 'q' => rgbbgQ
);

# This is the default until we can determine the console capabilities:
our %color_markup_to_code_map = %enhanced_color_markup_to_code_map;

sub disable_color {
  $R = ''; $G = ''; $B = ''; $C = ''; $M = ''; $Y = ''; $K = ''; $W = ''; $Q = '';
  $bgR = ''; $bgG = ''; $bgB = ''; $bgC = ''; $bgM = ''; $bgY = ''; $bgK = ''; $bgW = ''; $bgQ = '';
  $U = ''; $UX = ''; $V = ''; $VX = ''; $BLINK = ''; $BLINKX = ''; $X = '';
  $CLEAR_SCREEN = '';
  $color_enabled = 0;
}

sub enable_color {
  my $force = (($_[0] // 0) == 1);

  if ($color_enabled) { return; }

  # Assume this for the time being (see notes for BEGIN {...} block)
  my $caps = ENHANCED_RGB_COLOR_CAPABLE;
  if (!$force) {
    my $stdout_caps = is_stdout_color_capable();
    my $stderr_caps = is_stderr_color_capable();
    $caps = max($stdout_caps, $stderr_caps);
  }

  # Clear the entire screen and move cursor to upper left:
  # TERM=xterm uses \e[H\e[2J
  # TERM=linux uses \e[H\e[J
  $CLEAR_SCREEN = ANSI_CONSOLE_ESC.'H'.ANSI_CONSOLE_ESC.'2J';

  $ERASE_TO_END_OF_LINE = ANSI_CONSOLE_ESC.'K';
  $ERASE_FROM_START_OF_LINE_TO_CURSOR = ANSI_CONSOLE_ESC.'1K';
  $ERASE_LINE = ANSI_CONSOLE_ESC.'2K';

  $SAVE_CURSOR_POS = ESC.'7';
  $RESTORE_CURSOR_POS = ESC.'8';
  $CLEAR_TAB_STOPS = ANSI_CONSOLE_ESC.'3g';
  $SET_TAB_IN_CURRENT_COLUMN = ESC.'H';

  my $colorset = ($caps >= ENHANCED_RGB_COLOR_CAPABLE) ? \%rgb_colors : \%fixed_colors;

  ($R, $G, $B, $C, $M, $Y, $K, $W, $bgR, $bgG, $bgB, $bgC, $bgM, $bgY, $bgK, $bgW) =
    @{$colorset}{qw(R G B C M Y K W bgR bgG bgB bgC bgM bgY bgK bgW)};

  %color_markup_to_code_map = ($caps >= ENHANCED_RGB_COLOR_CAPABLE) ?
    %enhanced_color_markup_to_code_map : %basic_color_markup_to_code_map;

  $color_enabled = 1;
}

sub enable_color_based_on_filehandle($) {
  return if (!defined $_[0]);
  if (is_filehandle_color_capable($_[0])) {
    enable_color();
  } else {
    disable_color();
  }
}

sub enable_color_based_on_stderr {
  enable_color_based_on_filehandle(STDERR);
}

sub enable_color_based_on_stdout {
  enable_color_based_on_filehandle(STDOUT);
}

sub enable_color_based_on_console {
  enable_color_based_on_filehandle(get_console_control_fd());
}

#
# Always allow explicit colorize() even if
# terminal doesn't appear to support color,
# since this function returns a string that
# might not even get output to the same 
# terminal right away (it could be saved
# for later in a file, for instance).
#
sub replace_color_code($) {
  my $cc = $color_markup_to_code_map{$_[0]};
  if (!defined $cc) { die('Unknown color code "'.$_[0].'"'); }
  return $cc;
}

sub colorize($) {
  my $s = $_[0];
  $s =~ s/$color_markup_re/replace_color_code($1)/oamsxge;
  # If color is disabled, just strip out the color markups:
  # $s =~ s/$color_markup_re//oamsxg;
  return qq/$s/;
}

sub clear_screen {
  return if (!is_stderr_color_capable());
  print(STDERR $CLEAR_SCREEN);
}

sub clear_tab_stops {
  return if (!is_stderr_color_capable());
  print(STDERR $CLEAR_TAB_STOPS);
}

my $cached_terminal_rows = undef;
my $cached_terminal_columns = undef;

sub update_terminal_dimensions() {
  if ((!defined $cached_terminal_rows) || (!defined $cached_terminal_columns)) {
    my ($r, $c) = get_terminal_window_size();
    $cached_terminal_rows = $r // $ENV{'LINES'} // 50;
    $cached_terminal_columns = $c // $ENV{'COLUMNS'} // 120;
  }

  return ($cached_terminal_rows, $cached_terminal_columns);
}

sub get_terminal_width_in_columns() {
  update_terminal_dimensions();
  return $cached_terminal_columns;
}

sub get_terminal_height_in_lines() {
  update_terminal_dimensions();
  return $cached_terminal_rows;
}

sub move_cursor_to_row($) {
  my ($row) = @_;

  return ESC.'['.$row.'d';
}

sub move_cursor_to_column($) {
  my ($col) = @_;

  return ESC.'['.$col.'G';
}

sub move_cursor_to_row_and_column($$) {
  my ($row, $col) = @_;

  return ESC.'['.$row.';'.$col.'H';
}

sub get_tab_stop_codes(@) {
  my $s = $SAVE_CURSOR_POS.$CLEAR_TAB_STOPS;
  my $COLUMNS = get_terminal_width_in_columns();

  if (!scalar(@_)) {
    foreach ($i = 0; $i < ($COLUMNS / 8); $i++) {
      $s .= move_cursor_to_column(8 * $i).
        $SET_TAB_IN_CURRENT_COLUMN;
    }
  } else {
    my $col = 0;
    my $i = 0;
    my $iters = 0;
    while (($col < $COLUMNS) && ($iters++ <= $COLUMNS)) {
      my $tabstop = $_[$i];
      my ($addto, $newcol) = ($tabstop =~ /(\+?)(\d+)/oaxg);
      $col = $newcol + (($addto eq '+') ? $col : ($addto eq '-') ? (-$col) : 0);
      $s .= move_cursor_to_column($col).$SET_TAB_IN_CURRENT_COLUMN;
      $i += (($i < (scalar(@_)-1)) ? +1 : 0);
      # $i = ($i + 1) % scalar(@_);    # (to repeat tab list instead)x
    }
  }
  $s .= $RESTORE_CURSOR_POS;
}

sub set_tab_stops {
  return if (!is_stderr_color_capable());
  print(STDOUT get_tab_stop_codes(@_));
}

sub color_sample_text(;$$$) {
  my $sep = $_[0] // '';
  my $before = $_[1] // '';
  my $after = $_[2] // '';

  return join($sep, map { $rgb_colors{$_}.$before.$_.$after.X } @fixed_color_symbols).
    $sep.X.$before.'X'.$after.X;
}

sub color_and_style_sample_text(;$$$) {
  my $sep = $_[0] // '';
  my $before = $_[1] // '';
  my $after = $_[2] // '';
  if ($after =~ /^\s+$/) { $after = $X.$after; }

  return
    X.join($sep, map { X.$color_markup_to_code_map{$_}.$before.$_.$after.X } @fixed_color_symbols).X.$sep.
    join($sep, map { Q.$color_markup_to_code_map{$_}.$before.$_.$after.X } (map { lc($_) } @fixed_color_symbols)).X.$sep.
    join($sep, map { W.$color_markup_to_code_map{$_}.$before.$_.$after.X } @color_style_code_symbols).X;
}

noexport:; sub reveal_ansi_console_escape_code($$) {
  my ($e, $base_color) = @_;

  $base_color //= $X;
  $e =~ s/[\e\x9B]/$M<ESC>$Y/oamsxg;
  $e =~ s/\007/$M<ST>$Y/oamsxg;
  return bg_color_rgb(64, 0, 0).$Y.$e.$X.$base_color;
}

sub reveal_ansi_console_escape_codes($) {
  my ($s, $base_color) = @_;

  $base_color //= $X;
  $s =~ s{($ansi_console_escape_codes_re)}
         {reveal_ansi_console_escape_code($1, $base_color)}oamsxge;
  return $s;
}

use constant {
  SET_XTERM_WINDOW_TITLE  => '0',
  SET_XTERM_SESSION_TITLE => '30',
  SET_ANSI_COLOR_TO_RGB   => '4',
  SET_XTERM_FONT          => '50'
};

sub set_console_attribute($;$) {
  my ($attr, $value) = @_;

  $value //= '';

  my $fd = get_console_control_fd();
  if (!defined $fd) { return undef; }

  return undef if (!is_console_color_capable());

  my $s = ANSI_CONSOLE_OSC.$attr.';'.$value.END_OSC_ST;

  sys_write($fd, $s, length($s));
  return 1;
}

sub set_console_title(;$) {
  my ($title) = @_;

  $title //= get_user_name().'@'.get_host_name();
  set_console_attribute(SET_XTERM_WINDOW_TITLE, $title);
  return $title;
}

sub set_console_subtitle(;$) {
  my ($subtitle) = @_;

  $subtitle //= $0.' '.join(' ', @ARGV);
  set_console_attribute(SET_XTERM_SESSION_TITLE, $subtitle);
  return $subtitle;
}

BEGIN {
  #
  # Enable color by default early in perl's compile phase so any 
  # users of this module which incorporate the $R/$G/$B/etc values
  # into their own constants will have valid values, independent 
  # of whether or not any given output device can actually handle
  # these escape codes. 
  #
  # At the very early stage when perl processes this block, we have
  # no clue where or what stdout, stderr or any other file handle 
  # may be piped into, since we can't accurately determine this 
  # until the program is actually running after compilation. This
  # is why stdio and stderr are only checked for color capabilities
  # during the INIT block that runs right before main() is called.
  #
  # I/O like this is taboo in BEGIN blocks, which can only contain
  # code the perl compiler can interpret without external inputs.
  # Anything beyond that is also totally contraindicated when
  # compiling with perlcc (whether to bytecode or a real binary).
  #
  # If any user of this module captures the initial values of the
  # $R/$G/$B/etc. variables at this stage, we assume that user
  # realizes these variables may be turned into NOPs if we later
  # determine the output terminal doesn't support color codes, or
  # if the terminal's user has explicitly disabled color. 
  #
  # In this scenario, users of this module must call the functions
  # is_[stderr|stdout|fd]_color_capable() or check the $color_enabled
  # variable before attempting to output a string constructed using
  # the previously captured color codes.
  #
  # In contrast, code which refrains from referencing the $R/$G/$B/etc
  # variables until after main() has started (or an equivalent point
  # at runtime) can always safely use these variables even when color
  # is disabled or impossible, since in that case their use will have
  # no effect anyway because they'll be made into empty strings.
  #
  enable_color(1);
};

INIT {
  if (is_stderr_color_capable() || is_stdout_color_capable()) {
    enable_color();
  } else {
    disable_color();
  }

  set_console_title();
  set_console_subtitle();
};

END {
  # When we exit, clear the terminal window subtitle 
  # (which normally shows our command line):
  set_console_subtitle('');
};

1;
