# -*- cperl -*-
#
# MTY::Display::PrintableSymbols
#
# Printable symbols in Unicode / UTF-8:
# works with most modern consoles and terminal emulators
# when using fonts which include these Unicode characters.
#
# Note that some terminals have difficulty displaying some
# of these characters, particularly so-called full width
# ones that exceed one character cell (as defined by the
# widest standard ASCII character). Affected characters
# may be chopped in half, displayed as empty boxes, or 
# not displayed at all. Fortunately most of the characters
# in this collection have been tested to be compatible with
# most common monospaced Unicode aware fonts and most 
# terminal programs (at least xterm, kde 3.x konsole, 
# gnome-terminal etc. Interestingly, kde 4.x konsole 
# seems to correctly display virtually any Unicode
# character without clipping its glyph or refusing
# to display it at all).
#
# Module Developer: Matt T. Yourst <yourst@yourst.com>
#
# Public domain - this is merely a labeled list of characters,
# but the actual character glyphs are are probably copyrighted 
# by whomever created your terminal's selected font...
#

package MTY::Display::PrintableSymbols;

use integer; use warnings; use Exporter::Lite;

our @EXPORT;
our %symbols;
our %enclosed_digit_sequence_symbol_bases;

BEGIN {

%symbols = (
  newline => "\n",
  carriagereturn => "\r",
  tab => "\t",
  formfeed => "\f",
  esc => "\e",
  space => ' ',
  zero_space => chr(0x200b),

  small_left_barbed_arrow => chr(0x2190),
  small_up_barbed_arrow => chr(0x2191),
  small_right_barbed_arrow => chr(0x2192),
  small_down_barbed_arrow => chr(0x2193),
  left_arrow_tri => chr(0x25c0),
  left_arrow_open_tri => chr(0x25c1),
  left_arrow_bold => chr(0x2b05),
  up_arrow_tri => chr(0x25b2),
  up_arrow_open_tri => chr(0x25b3),
  up_arrow_bold => chr(0x2b06),
  down_arrow_tri => chr(0x25bc),
  down_arrow_open_tri => chr(0x25bd),
  down_arrow_bold => chr(0x2b07),
  arrow_tri_small => chr(0x2023),
  arrow_tri => chr(0x25b6),
  arrow_medium_tri => chr(0x25b8),
  arrow_medium_open_tri => chr(0x25b9),
  arrow_open_tri => chr(0x25b7),
  arrow_tri_large => chr(0x25ba),
  arrow_barbed => chr(0x279c),
  large_arrow_barbed => chr(0x2794),
  arrow_line => chr(0x279e),
  arrow_head => chr(0x27a4),
  arrow_half => chr(0x27a2),
  arrow_wide => chr(0x27a7),
  arrow_bold => chr(0x27a1),
  up_left_arrow => chr(0x2b08),
  up_right_arrow => chr(0x2b09),
  down_left_arrow => chr(0x2b0b),
  down_right_arrow => chr(0x2b0a),
  left_right_arrow_bold => chr(0x2b0c),
  up_down_arrow_bold => chr(0x2b0d),
  counterclockwise_curved_arrow => chr(0x27f2),
  clockwise_curved_arrow => chr(0x27f3),
  long_left_arrow => chr(0x27f5),
  long_right_arrow => chr(0x27f6),
  long_left_right_arrow => chr(0x27f7),
  
  plus_under_left_arrow_arc => chr(0x293d),
  plus_under_left_arrow => chr(0x2946),
  plus_under_right_arrow => chr(0x2945),

  right_arrow_through_circle => chr(0x27f4),

  left_quote => chr(0x201c), # stylized typographical left double quote (variant of ")
  left_single_quote => chr(0x2018), # stylized typographical left single quote (variant of ')
  left_angle_quote => chr(0x00ab), # a.k.a left guillemet as in french quotations
  round_bold_left_paren => chr(0x2768),
  flat_bold_left_paren => chr(0x276a),
  double_left_paren => chr(0xff5f),
  bold_left_angle_bracket => chr(0x276c),
  alt_bold_left_angle_bracket => chr(0x276e),
  extra_bold_left_angle_bracket => chr(0x2770),
  bold_left_brace => chr(0x2774),
  double_left_angle_bracket => chr(0x27ea),
  left_slightly_rounded_bracket => chr(0x2772),
  ornate_left_square_bracket => chr(0x27e6),
  upper_left_corner_bracket => chr(0x300c),
  open_upper_left_corner_bracket => chr(0x300e),
  left_semi_rounded_bracket => chr(0x3014),
  open_left_semi_rounded_bracket => chr(0x3018),
  open_left_square_bracket => chr(0x301a),
  wide_left_square_bracket => chr(0xff3b),
  wide_left_brace => chr(0xff5b),
  small_upper_left_corner_bracket => chr(0xff62),

  right_quote => chr(0x201d), # stylized typographical right double quote (variant of ")
  right_single_quote => chr(0x2019), # stylized typographical right single quote (variant of ')
  right_angle_quote => chr(0x00bb), # a.k.a left guillemet as in french quotations
  round_bold_right_paren => chr(0x2769),
  flat_bold_right_paren => chr(0x276b),
  double_right_paren => chr(0xff60),
  bold_right_angle_bracket => chr(0x276d),
  alt_bold_right_angle_bracket => chr(0x276f),
  extra_bold_right_angle_bracket => chr(0x2771),
  bold_right_brace => chr(0x2775),
  double_right_angle_bracket => chr(0x27eb),
  right_slightly_rounded_bracket => chr(0x2773),
  ornate_right_square_bracket => chr(0x27e7),
  lower_right_corner_bracket => chr(0x300d),
  open_lower_right_corner_bracket => chr(0x300f),
  right_semi_rounded_bracket => chr(0x3015),
  open_right_semi_rounded_bracket => chr(0x3019),
  open_right_square_bracket => chr(0x301b),
  wide_right_square_bracket => chr(0xff3d),
  wide_right_brace => chr(0xff5d),
  small_lower_right_corner_bracket => chr(0xff63),

  rounded_upper_left_corner  => chr(0x256d),
  rounded_upper_right_corner => chr(0x256e),
  rounded_lower_left_corner  => chr(0x2570),
  rounded_lower_right_corner => chr(0x256f),

  copyright_symbol => chr(0x00a9), # copyright symbol ("(c)" inside circle)
  reg_tm_symbol => chr(0x00ae), # registered trademark symbol ("(r)" inside circle)
  trademark_tm_symbol => chr(0x2122), # trademark symbol (superscript "tm")

  exclaimation_point => chr(0x2757), # bold ! symbol
  inverted_exclaimation => chr(0x00ab), # upside down exclamation point (!) as in spanish
  inverted_question_mark => chr(0x00bf), # upside down question mark (?) as in spanish
  wide_question_mark => chr(0xff1f), # full width question mark (?)
  paragraph_symbol => chr(0x00b6), # paragraph symbol (backwards stylized "p") a.k.a. pilcrow symbol
  section_symbol => chr(0x00a7), # section symbol ("s" with open circle in middle)
  elipsis_three_dots => chr(0x2026),
  large_pound_sign => chr(0xff03),
  sharp_sign => chr(0x266f),
  star => chr(0x2605), # five pointed star (not an asterisk)
  asterisk => chr(0x273b), # asterisk (six rounded lobes) in typographical style
  pointed_asterisk => chr(0xff0a), # six pointed asterisk with lines (not rounded lobes)
  eight_point_asterisk => chr(0x274b), # eight pointed (actually rounded lobes) asterisk
  double_colon => chr(0x2836), # '::' in one character
  
  star_with_8_points => chr(0x2734), # eight pointed star with deep points
  star_with_6_points => chr(0x2736), # eight pointed star with deep points
  star_with_8_medium_points => chr(0x2737), # eight pointed star with medium points
  star_with_8_stubby_points => chr(0x2738), # eight pointed star with short stubby points (more like a medallion shape)
  star_with_12_stubby_points => chr(0x2739), # twelve pointed star with short stubby points
  star_with_16_points => chr(0x273a), # sixteen pointed star with deep points

  dot => chr(0x2022), # medium sized dot
  dot_small => chr(0x00b7), # small sized dot
  bullet_small => chr(0x2219),
  large_dot => chr(0x26ab),
  large_open_dot => chr(0x26aa),
  open_dot => chr(0x26ac),
  two_linked_open_dots => chr(0x26af),
  large_plus => chr(0x271a),
  x_multiplier => chr(0x2715),
  times_symbol => chr(0x2715),
  multiplied_by => chr(0x2715),
  large_circle => chr(0x3007),
  circle_with_shadow => chr(0x274d),

  checkmark => chr(0x2714), # checkmark symbol
  checkmark_in_box => chr(0x2611), # checkmark in box
  no_entry_sign => chr(0x26d4), # circle with partial horizonal line or dash (-)
  warning_sign => chr(0x26a0), # triangle with exclamation mark (!)
  x_symbol => chr(0x2716), # super bold "x" with straight edges and stamped appearance
  x_signed => chr(0x2718), # bold "x" with rough hand drawn appearance
  x_signed_light => chr(0x2717), # bold "x" with rough hand drawn appearance
  big_x => chr(0x2573),
  small_x => chr(0x2715),
  null_circle => chr(0x2300), # circle with long diagonal line drawn through it
  frown_smiley => chr(0x2639), # frowning face emoticon
  return_enter_key_symbol => chr(0x23ce), # left open arrow with upward line on right
  eject_symbol => chr(0x23cf), # triangle above rectangle
  command_key_symbol => chr(0x2318), # command key symbol (as found on Mac keyboards)

  info_i_symbol => chr(0x2139),

  telephone => chr(0x260e),
  open_telephone => chr(0x260f),
  telephone_in_circle => chr(0x2706),
  p_in_circle => chr(0x2117),

  numero_no => chr(0x2116),
  estimate_e => chr(0x212e),
  small_fancy_e => chr(0x212f),
  euler_e => chr(0x2107),
  reversed_e => chr(0x2108),
  deg_f => chr(0x2109),
  script_h => chr(0x210b),
  script_l => chr(0x2112),
  script_small_l => chr(0x2113),
  script_h => chr(0x210b),
  script_r => chr(0x211b),
  double_struck_c => chr(0x2102),
  double_struck_d => chr(0x2145),
  double_struck_h => chr(0x210d),
  double_struck_n => chr(0x2115),
  double_struck_p => chr(0x2119),
  double_struck_q => chr(0x211a),
  double_struck_r => chr(0x211d),
  double_struck_z => chr(0x2124),
  script_b => chr(0x212c),
  script_e => chr(0x2130),
  script_f => chr(0x2131),
  script_m => chr(0x2133),
  big_k => chr(0x212a),
  double_struck_sigma => chr(0x2140),

  long_heavy_vert_bar => chr(0x2503),
  long_narrow_vert_bar => chr(0x2502),
  long_narrow_double_vert_bars => chr(0x2551),
  heavy_vertical_bar => chr(0x2759),
  very_heavy_vertical_bar => chr(0x275a),

  three_horiz_bars => chr(0x2630),
  three_vert_bars => chr(0x2162),

  dashed_horiz_bar_2_dashes => chr(0x254c),
  dashed_horiz_bar_3_dashes => chr(0x2504),
  dashed_horiz_bar_4_dashes => chr(0x2508),
  heavy_dashed_horiz_bar_2_dashes => chr(0x254d),
  heavy_dashed_horiz_bar_3_dashes => chr(0x2505),
  heavy_dashed_horiz_bar_4_dashes => chr(0x2509),
  dashed_vert_bar_2_dashes => chr(0x254e),
  dashed_vert_bar_3_dashes => chr(0x2506),
  dashed_vert_bar_4_dashes => chr(0x250a),
  dotted_vert_bar_3_dots => chr(0x2807),
  dotted_vert_bar_4_dots => chr(0x2847),
  dotted_vert_bar_3_heavy_dots => chr(0x2507),
  dotted_vert_bar_4_heavy_dots => chr(0x250b),

  normal_dash => chr(ord('-')),
  left_half_dash => chr(0x2574),
  right_half_dash => chr(0x2576),
  heavy_left_half_dash => chr(0x2578),
  heavy_right_half_dash => chr(0x257a),
  left_heavy_right_light_dash => chr(0x257e),
  left_light_right_heavy_dash => chr(0x257c),

  large_right_slash => chr(0x2571),
  large_left_slash => chr(0x2572),
  split_right_slash => chr(0x2215),
  three_right_slashes => chr(0x2425),

  a_slash_c => chr(0x2100),
  a_slash_s => chr(0x2101),
  c_slash_o => chr(0x2105),
  c_slash_u => chr(0x2106),

  ellipse_divided_by_vert_line => chr(0x2180),

  omega => chr(0x2126),
  fax_symbol => chr(0x213b),

  zigzag_vert_bar => chr(0x299a),
  horiz_bar => chr(0x2500),
  heavy_horiz_bar => chr(0x2501),
  double_horiz_bars => chr(0x2550),
  under_space => chr(0x2423),
  long_under_bar => chr(0xff3f),

  wavy_horiz_dash => chr(0x3030),
  sine_wave_horiz_dash => chr(0x301c),

  figure_dash => chr(0x2012),
  en_dash => chr(0x2013),
  em_dash => chr(0x2014),
  horiz_dash => chr(0x2015),
  narrow_wavy_horiz_dash => chr(0x2053),
  box_with_shadow => chr(0x274f),
  dotted_square => chr(0x2b1a),
  empty_box => chr(0x2610),
  empty_square => chr(0x2610),
  hatched_square_light => chr(0x2591),
  hatched_square_medium => chr(0x2592),
  hatched_square_dark => chr(0x2593),
  solid_block => chr(0x2588),
  left_edge_vert_bar => chr(0x258f),
  right_edge_vert_bar => chr(0x2595),
  top_edge_horiz_bar => chr(0x2594),
  bottom_edge_horiz_bar => chr(0x2581),
  top_half_block => chr(0x2580),
  bottom_half_block => chr(0x2584),
  left_half_block => chr(0x258c),
  right_half_block => chr(0x2590),
  thin_top_edge_horiz_bar => chr(0xffe3),

  less_than_in_circle => chr(0x29c0),
  greater_than_in_circle => chr(0x29c1),
  plus_in_circle => chr(0x2295),
  minus_in_circle => chr(0x2296),
  divisor_in_circle => chr(0x2a38),
  x_in_circle => chr(0x2b59), 
  dot_in_circle => chr(0x2609),
  x_in_two_nested_circles => chr(0x2a37),

  plus_in_square => chr(0x229e),
  minus_in_square => chr(0x229d),
  asterisk_in_square => chr(0x29C6),
  right_slash_in_square => chr(0x29C4),
  left_slash_in_square => chr(0x29C5),
  circle_in_square => chr(0x29C7),
  square_in_square => chr(0x29C8),
  overlapping_squares => chr(0x29C9),
  x_in_box => chr(0x2612),

  plus_in_triangle => chr(0x2a39),
  minus_in_triangle => chr(0x2a3a),
  s_in_triangle => chr(0x29CC),
  x_in_triangle => chr(0x2a3b),

  four_diamonds => chr(0x2756),
  open_diamond => chr(0x2662),
  diamond => chr(0x2666),

  single_disc => chr(0x26c0),
  double_disc => chr(0x26c1),
  single_disc_black => chr(0x26c2),
  double_disc_black => chr(0x26c3),
  lightning_spark => chr(0x26a1),
  
  dice_1_dots => chr(0x2680),
  dice_2_dots => chr(0x2681),
  dice_3_dots => chr(0x2682),
  dice_4_dots => chr(0x2683),
  dice_5_dots => chr(0x2684),
  dice_6_dots => chr(0x2685),
  sun_rays    => chr(0x2600),
  anchor_symbol => chr(0x2693),

  no_symbol_combining => chr(0x20e0), # circle with diagonalar line (/) through it (combines with next character)

  infinity_sign => chr(0x221e),
  degree_sign => chr(0x00b0), # degree sign (superscript open cirle) (e.g. for temperature)'),
  degrees_c => chr(0x2103), # degrees "C"
  degrees_f => chr(0x2104),
  plus_minus_symbol => chr(0x00b1), # +/- symbol (arranged vertically)'),
  division_symbol => chr(0x00f7), # division symbol (top and bottom dots sep by horiz line)'),
  micro_symbol => chr(0x00b5), # micro symbol (Greek letter mu, i.e. stylized "u")'),
  double_less_than => chr(0x226a), # degree sign (superscript open cirle) (e.g. for temperature)'),
  not_equal_symbol => chr(0x2260), # => with right facing slash through it
  approx_equal_symbol => chr(0x2248), # ~~
  large_equals_sign => chr(0x3013),
  box_with_right_slash => chr(0x303c),
  large_at_sign => chr(0xff20),

  subscript_0 => chr(0x2080),
  subscript_1 => chr(0x2081),
  subscript_2 => chr(0x2082),
  subscript_3 => chr(0x2083),
  subscript_4 => chr(0x2084),
  subscript_5 => chr(0x2085),
  subscript_6 => chr(0x2086),
  subscript_7 => chr(0x2087),
  subscript_8 => chr(0x2088),
  subscript_9 => chr(0x2089),
  subscript_a => chr(0x2090),
  subscript_e => chr(0x2091),
  subscript_o => chr(0x2092),
  subscript_x => chr(0x2093),
  subscript_h => chr(0x2095),
  subscript_k => chr(0x2096),
  subscript_l => chr(0x2097),
  subscript_m => chr(0x2098),
  subscript_n => chr(0x2099),
  subscript_p => chr(0x209a),
  subscript_s => chr(0x209b),
  subscript_t => chr(0x209c),
  subscript_plus => chr(0x208a),
  subscript_minus => chr(0x208b),
  subscript_equals => chr(0x208c),
  subscript_left_paren => chr(0x208d),
  subscript_right_paren => chr(0x208e),

  superscript_plus => chr(0x207a),
  superscript_minus => chr(0x207b),
  superscript_equals => chr(0x207c),
  superscript_1 => chr(0x00b9), # superscript 1'),
  squared_symbol => chr(0x00b2), # superscript 2 (squared)'),
  cubed_symbol => chr(0x00b3),
  square_root_symbol => chr(0x221a),
  cube_root_symbol => chr(0x221b),
  fourth_root_symbol => chr(0x221c),

  fraction_1_4 => chr(0x00bc), # stylized 1/4 fraction'),
  fraction_1_2 => chr(0x00bd), # stylized 1/4 fraction'),
  fraction_3_4 => chr(0x00be), # stylized 1/4 fraction'),

  # Multi-character composite symbols:
  long_bold_right_arrow => chr(0x2015).chr(0x25b6),
  long_bold_right_arrow_double_line => chr(0x2550).chr(0x25b6),
  long_bold_right_arrow_heavy_line => chr(0x2501).chr(0x25b6),
  wide_square_root_symbol => chr(0x221a).chr(0xffe3),
  large_square_root_symbol => chr(0x221a).chr(0x2594),

  wide_open_up_arrow => chr(0x2571).chr(0x2572),
  wide_open_down_arrow => chr(0x2572).chr(0x2571),
);

#
# Note: these are merely the base character numbers (starting from 0)
# for sequences of 9 or more consecutive enclosed digits, where
# chr(..._digits + 1) == "1" inside a circle/square/etc. and so on.
# For most of these character ranges, an enclosed "0" is not defined.
#
our %enclosed_digit_sequence_symbol_bases = (
  solid_circled_digits       => 0x2776-1,
  solid_circled_large_digits => 0x278a-1,
  circled_large_digits       => 0x2780-1);

}; # BEGIN

use constant {
  THREE_LETTER_SYMBOLS_FOR_CONTROL_CHARS_BASE => 0x2400
};

use constant \%symbols;
use constant \%enclosed_digit_sequence_symbol_bases;

BEGIN {
#
# All output of UTF-8 Unicode symbols can be disabled 
# by running this from the shell: 
#
#   export PrintableSymbols=0
#
# (or the equivalent settings of "no", "off", "disable", "disabled")
#
# This will undefine any character codes above the first 128 ASCII characters.
#
#

my $envconfig = $ENV{'PrintableSymbols'} // '';

our @symbol_names = keys %symbols;

if ($envconfig =~ /^(?:0|no|off|disable)/oax) {
  foreach my $k (@symbol_names) { $symbols{$k} = '?'; }
  foreach my $k (keys %enclosed_digit_sequence_symbol_bases) 
    { $enclosed_digit_sequence_symbol_bases{$k} = ord('0'); }
}

use vars @symbol_names;
foreach my $name (@symbol_names) { ${$name} = $symbols{$name}; }

preserve:; our @EXPORT = (
  @symbol_names, 
  (map { '$'.$_ } @symbol_names), 
  (keys %enclosed_digit_sequence_symbol_bases), 
  qw(%symbols @symbol_names)
);

}; # (BEGIN)

1;
