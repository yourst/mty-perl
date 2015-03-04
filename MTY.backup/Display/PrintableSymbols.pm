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

use integer; use warnings; use Exporter qw(import);
use List::Util qw(pairmap);
#pragma end_of_includes

our @EXPORT;
our %symbols;
our %symbol_groups;
our %enclosed_digit_sequence_symbol_bases;
our %symbols_to_non_unicode_equivalent;
our %top_level_symbol_groups;

#
# These assignments are all done in a begin block so the compiler 
# can use this knowledge to inline these values as constants:
#
BEGIN {
  our %symbol_groups = (
    control_chars => [
      newline                                  => "\n",
      carriagereturn                           => "\r",
      tab                                      => "\t",
      formfeed                                 => "\f",
      esc                                      => "\e",
    ],

    spaces => [
      space                                    => ' ',
      non_breaking_space                       => chr(0xa0),
      nbsp                                     => chr(0xa0),
      en_space                                 => chr(0x2002),
      em_space                                 => chr(0x2003),
      fig_space                                => chr(0x2007),
      punc_space                               => chr(0x2008),
      thin_space                               => chr(0x2009),
      hair_space                               => chr(0x200a),
      zero_space                               => chr(0x200b),
    ],

    barbed_arrows => [
      small_left_barbed_arrow                  => chr(0x2190),
      small_up_barbed_arrow                    => chr(0x2191),
      small_right_barbed_arrow                 => chr(0x2192),
      small_down_barbed_arrow                  => chr(0x2193),
      arrow_barbed                             => chr(0x279c),
      large_arrow_barbed                       => chr(0x2794),
    ],
    triangular_arrows => [
      left_arrow_tri                           => chr(0x25c0),
      left_arrow_open_tri                      => chr(0x25c1),
      alt_left_arrow_open_tri                  => chr(0x140a),
      up_arrow_tri                             => chr(0x25b2),
      up_arrow_open_tri                        => chr(0x25b3),
      alt_up_arrow_open_tri                    => chr(0x1403),
      down_arrow_tri                           => chr(0x25bc),
      down_arrow_open_tri                      => chr(0x25bd),
      alt_down_arrow_open_tri                  => chr(0x1401),
      arrow_tri_small                          => chr(0x2023),
      arrow_tri                                => chr(0x25b6),
      arrow_medium_tri                         => chr(0x25b8),
      arrow_medium_open_tri                    => chr(0x25b9),
      arrow_open_tri                           => chr(0x25b7),
      alt_right_arrow_open_tri                 => chr(0x1405),
      arrow_tri_large                          => chr(0x25ba),
    ],
    bold_arrows => [
      left_arrow_bold                          => chr(0x2b05),
      up_arrow_bold                            => chr(0x2b06),
      down_arrow_bold                          => chr(0x2b07),
      arrow_bold                               => chr(0x27a1),
    ],
    diagonal_arrows => [
      up_left_arrow                            => chr(0x2b08),
      up_right_arrow                           => chr(0x2b09),
      down_left_arrow                          => chr(0x2b0b),
      down_right_arrow                         => chr(0x2b0a),
      arrow_down_right                         => chr(0x2798),
      arrow_right_right                        => chr(0x2799),
      arrow_up_right                           => chr(0x279a),
    ],
    bidirectional_arrows => [
      left_right_arrow_bold                    => chr(0x2b0c),
      up_down_arrow_bold                       => chr(0x2b0d),
      up_down_open_arrows                      => chr(0x27e0),
    ],
    right_arrows => [
      arrow_line                               => chr(0x279e),
      arrow_head                               => chr(0x27a4),
      arrow_half                               => chr(0x27a2),
      arrow_wide                               => chr(0x27a7),
      arrow_right_tiny                         => chr(0x279b),
      arrow_right_thin_tiny                    => chr(0x279d),
      arrow_fade_out                           => chr(0x279f),
      thick_arrow_fade_out                     => chr(0x27a0),
      broken_outlined_arrow                    => chr(0x27be),
    ],
    long_arrows => [
      long_left_arrow                          => chr(0x27f6),
      long_right_arrow                         => chr(0x27f6),
      long_left_right_arrow                    => chr(0x27f7),
      long_hollow_left_right_arrow             => chr(0x27fa),
      long_right_wavy_arrow                    => chr(0x27ff),
    ],
    shadowed_arrows => [  
      shadowed_arrow                           => chr(0x27ad),
      top_shadowed_arrow                       => chr(0x27ae),
      light_shadowed_arrow                     => chr(0x27af),
      light_top_shadowed_arrow                 => chr(0x27b1),
      slanted_shadowed_arrow                   => chr(0x27ab),
    ],
    special_arrows => [
      counterclockwise_curved_arrow            => chr(0x27f2),
      clockwise_curved_arrow                   => chr(0x27f3),
      right_arrow_through_circle               => chr(0x27f4),
      plus_under_left_arrow_arc                => chr(0x293d),
      plus_under_left_arrow                    => chr(0x2946),
      plus_under_right_arrow                   => chr(0x2945),
      three_bars_up_arrow                      => chr(0x27f0),
      three_bars_down_arrow                    => chr(0x27f1),
    ],
    left_quotes => [
      left_quote                               => chr(0x201c), # stylized typographical left double quote
      left_single_quote                        => chr(0x2018), # stylized typographical left single quote
      left_angle_quote                         => chr(0x00ab), # a.k.a left guillemet as in french quotations
      bold_left_quote                          => chr(0x275d),
      bold_left_single_quote                   => chr(0x275b),
    ],
    right_quotes => [
      right_quote                              => chr(0x201d), # stylized typographical right double quote
      right_single_quote                       => chr(0x2019), # stylized typographical right single quote
      right_angle_quote                        => chr(0x00bb), # a.k.a left guillemet as in french quotations
      bold_right_quote                         => chr(0x275e),
      bold_right_single_quote                  => chr(0x275c),
    ],
    left_parens_braces_brackets => [
      round_bold_left_paren                    => chr(0x2768),
      flat_bold_left_paren                     => chr(0x276a),
      double_left_paren                        => chr(0xff5f),
      light_left_paren                         => chr(0xfd3e),
      open_left_paren                          => chr(0x263e),
      bold_left_angle_bracket                  => chr(0x276c),
      alt_bold_left_angle_bracket              => chr(0x276e),
      extra_bold_left_angle_bracket            => chr(0x2770),
      double_left_angle_bracket                => chr(0x27ea),
      left_slightly_rounded_bracket            => chr(0x2772),
      ornate_left_square_bracket               => chr(0x27e6),
      left_semi_rounded_bracket                => chr(0x3014),
      open_left_semi_rounded_bracket           => chr(0x3018),
      open_left_square_bracket                 => chr(0x301a),
      wide_left_square_bracket                 => chr(0xff3b),
      bold_left_brace                          => chr(0x2774),
      wide_left_brace                          => chr(0xff5b),
    ],
    right_parens_braces_brackets => [
      round_bold_right_paren                   => chr(0x2769),
      flat_bold_right_paren                    => chr(0x276b),
      double_right_paren                       => chr(0xff60),
      light_right_paren                        => chr(0xfd3f),
      open_right_paren                         => chr(0x263d),
      bold_right_angle_bracket                 => chr(0x276d),
      alt_bold_right_angle_bracket             => chr(0x276f),
      extra_bold_right_angle_bracket           => chr(0x2771),
      double_right_angle_bracket               => chr(0x27eb),
      right_slightly_rounded_bracket           => chr(0x2773),
      ornate_right_square_bracket              => chr(0x27e7),
      lower_right_corner_bracket               => chr(0x300d),
      open_lower_right_corner_bracket          => chr(0x300f),
      right_semi_rounded_bracket               => chr(0x3015),
      open_right_semi_rounded_bracket          => chr(0x3019),
      open_right_square_bracket                => chr(0x301b),
      wide_right_square_bracket                => chr(0xff3d),
      bold_right_brace                         => chr(0x2775),
      wide_right_brace                         => chr(0xff5d),
    ],
    corner_brackets => [
      upper_left_corner_bracket                => chr(0x300c),
      open_upper_left_corner_bracket           => chr(0x300e),
      small_upper_left_corner_bracket          => chr(0xff62),
      small_lower_right_corner_bracket         => chr(0xff63),
      rounded_upper_left_corner                => chr(0x256d),
      rounded_upper_right_corner               => chr(0x256e),
      rounded_lower_left_corner                => chr(0x2570),
      rounded_lower_right_corner               => chr(0x256f),
      alt_upper_left_corner                    => chr(0x14a5),
      alt_upper_right_corner                   => chr(0x14a3),
      alt_lower_left_corner                    => chr(0x14aa),
      alt_lower_right_corner                   => chr(0x14a7),
      upper_right_corner                       => chr(0x13b1),
      lower_left_corner                        => chr(0x13de),
    ],
    special_symbols => [
      copyright_symbol                         => chr(0x00a9), # copyright symbol (c) inside circle
      reg_tm_symbol                            => chr(0x00ae), # registered trademark symbol (r) inside circle
      trademark_tm_symbol                      => chr(0x2122), # trademark symbol (superscript TM)
      rx_symbol                                => chr(0x211e), # Rx (prescription) symbol 
      exclaimation_point                       => chr(0x2757), # bold ! symbol
      inverted_exclaimation                    => chr(0x00ab), # upside down exclamation point (!) as in spanish
      inverted_question_mark                   => chr(0x00bf), # upside down question mark (?) as in spanish
      paragraph_symbol                         => chr(0x00b6), # paragraph symbol (backwards stylized P) a.k.a. pilcrow symbol
      section_symbol                           => chr(0x00a7), # section symbol (S with open circle in middle)
      elipsis_three_dots                       => chr(0x2026),
      sharp_sign                               => chr(0x266f),
      no_entry_sign                            => chr(0x26d4), # circle with partial horizonal line or dash (-)
      warning_sign                             => chr(0x26a0), # triangle with exclamation mark (!)
      null_circle                              => chr(0x2300), # circle with long diagonal line drawn through it
      info_i_symbol                            => chr(0x2139),
      telephone                                => chr(0x260e),
      open_telephone                           => chr(0x260f),
      telephone_in_circle                      => chr(0x2706),
      p_in_circle                              => chr(0x2117),
      numero_no                                => chr(0x2116),
      degrees_c                                => chr(0x2103), # degrees C (i.e. celsius temperature)
      deg_f                                    => chr(0x2109),
      degrees_f                                => chr(0x2109),
      fax_symbol                               => chr(0x213b),
      infinity_sign                            => chr(0x221e),
      degree_sign                              => chr(0x00b0), # degree sign (superscript open cirle), i.e. for temperature
      plus_minus_symbol                        => chr(0x00b1), # +/- symbol (arranged vertically)
      division_symbol                          => chr(0x00f7), # division symbol (top and bottom dots sep by horiz line)
      micro_symbol                             => chr(0x00b5), # micro symbol (Greek letter mu, i.e. stylized letter u)
      double_less_than                         => chr(0x226a), # <<
      not_equal_symbol                         => chr(0x2260), # => with right facing slash through it
      approx_equal_symbol                      => chr(0x2248), # ~~
    ],
    colons => [
      double_colon                             => chr(0x2836), # :: in one character
      light_double_colon                       => chr(0x589).chr(0x589),
      small_double_colon                       => chr(0x16ec).chr(0x16ec),
      tiny_double_colon                        => chr(0x1362),
      very_light_double_colon                  => chr(0xfe30),
      heavy_colon                              => chr(0x254f),
    ],
    stars_and_asterisks => [
      star                                     => chr(0x2605), # five pointed star (not an asterisk)  
      star_with_8_points                       => chr(0x2734), # eight pointed star with deep points
      star_with_6_points                       => chr(0x2736), # eight pointed star with deep points
      star_with_8_medium_points                => chr(0x2737), # eight pointed star with medium points
      star_with_8_stubby_points                => chr(0x2738), # eight pointed star with short stubby points (more like a medallion shape)
      star_with_12_stubby_points               => chr(0x2739), # twelve pointed star with short stubby points
      star_with_16_points                      => chr(0x273a), # sixteen pointed star with deep points
      large_asterisk                           => chr(0xff0a),
      asterisk                                 => chr(0x273b), # asterisk (six rounded lobes) in typographical style
      pointed_asterisk                         => chr(0xff0a), # six pointed asterisk with lines (not rounded lobes)
      eight_point_asterisk                     => chr(0x274b), # eight pointed (actually rounded lobes) asterisk
    ],
    misc => [
      two_linked_open_dots                     => chr(0x26af),
      inverted_square_u                        => chr(0x3a0), # capital greek pi
      small_u                                  => chr(0x3c5), # lowercase greek upsilon
      delta_up_tri                             => chr(0x394), # uppercase greek delta
      ellipse_divided_by_vert_line             => chr(0x2180),
      sun_rays                                 => chr(0x2600),
      anchor_symbol                            => chr(0x2693),
      lightning_spark                          => chr(0x26a1),
      no_symbol_combining                      => chr(0x20e0), # circle with diagonalar line (/) through it (combines with next character)
      flag_marker                              => chr(0x2691), # flag pole
      open_flag_marker                         => chr(0x2690), # open flag on pole
      gear                                     => chr(0x2699),
      atomic_symbol                            => chr(0x269b),
      pin_head_marker                          => chr(0x26b2),
      heart                                    => chr(0x2764),
      yin_yang                                 => chr(0x262f),
      frown_smiley                             => chr(0x2639), # frowning face emoticon
      smiley                                   => chr(0x263a),
      smiley_inverted                          => chr(0x263b),
    ],
    large_operators => [
      large_gt                                 => chr(0x1433),
      large_lt                                 => chr(0x1438),
      large_plus                               => chr(0x271a),
      large_at_sign                            => chr(0xff20),
      large_equals_sign                        => chr(0x3013),
      wavy_equals                              => chr(0x2652),
      angle_measure                            => chr(0x16a2),
    ],
    small_operators => [
      tiny_plus                                => chr(0x16ed),
    ],
    large_symbols => [
      wide_question_mark                       => chr(0xff1f), # full width question mark (?)
      large_pound_sign                         => chr(0xff03),
      large_dollar_sign                        => chr(0xff04),
      large_percent_sign                       => chr(0xff05),
      large_ampersand_sign                     => chr(0xff06),
    ],
    large_letters => [
      large_u                                  => chr(0x144c),
      large_v                                  => chr(0x142f),
      large_inverted_u                         => chr(0x144e),
      large_c                                  => chr(0x1450),
      large_inverted_c                         => chr(0x1455),
      large_j                                  => chr(0x148d),
      large_k                                  => chr(0x212a),
      big_k                                    => chr(0x212a),
    ],
    superscript_letters => [
      superscript_s                            => chr(0x1506),
      superscript_j                            => chr(0x14a2),  
      superscript_l                            => chr(0x14bb),
      superscript_u                            => chr(0x14d1),
      superscript_x                            => chr(0x1541),
      superscript_v                            => chr(0x1601),
      superscript_z                            => chr(0x1646),
      large_rotated_m                          => chr(0x1552),
    ],
    dots => [
      dot                                      => chr(0x2022), # medium sized dot
      dot_small                                => chr(0x00b7), # small sized dot
      dot_mini                                 => chr(0xff65), # smaller than dot_small
      tiny_dot                                 => chr(0x0387),
      alt_tiny_dot                             => chr(0x1427),
      bullet_small                             => chr(0x2219),
      large_dot                                => chr(0x26ab),
      large_open_dot                           => chr(0x26aa),
      alt_open_dot                             => chr(0x03bf),
      open_dot                                 => chr(0x26ac),
    ],
    x => [
      x_symbol                                 => chr(0x2716), # super bold X with straight edges and stamped appearance
      x_multiplier                             => chr(0x2715),
      times_symbol                             => chr(0x2715),
      multiplied_by                            => chr(0x2715),
      x_signed                                 => chr(0x2718), # bold x with rough hand drawn appearance
      x_signed_light                           => chr(0x2717), # semi-bold x with rough hand drawn appearance
      big_x                                    => chr(0x2573),
      small_x                                  => chr(0x2715),
      x_in_box                                 => chr(0x2612), # also in inside_square
    ],
    checkmarks => [
      checkmark                                => chr(0x2714), # checkmark symbol
      checkmark_in_box                         => chr(0x2611), # checkmark in box
    ],
    keyboard_symbols => [
      return_enter_key_symbol                  => chr(0x23ce), # left open arrow with upward line on right
      eject_symbol                             => chr(0x23cf), # triangle above rectangle
      command_key_symbol                       => chr(0x2318), # command key symbol (as found on Mac keyboards)
    ],
    stylized_e => [
      estimate_e                               => chr(0x212e),
      small_fancy_e                            => chr(0x212f),
      euler_e                                  => chr(0x2107),
      reversed_e                               => chr(0x2108),
    ],
    greek_letters => [
      sigma                                    => chr(0x03a3),
      omega                                    => chr(0x2126),
    ],
    stylized_letters => [
      italic_lowercase_h                       => chr(0x210e),
    ],
    script_letters => [
      script_h                                 => chr(0x210b),
      script_l                                 => chr(0x2112),
      script_small_l                           => chr(0x2113),
      script_h                                 => chr(0x210b),
      script_r                                 => chr(0x211b),
      script_b                                 => chr(0x212c),
      script_e                                 => chr(0x2130),
      script_f                                 => chr(0x2131),
      script_m                                 => chr(0x2133),
    ],
    double_struck_letters => [
      double_struck_c                          => chr(0x2102),
      double_struck_d                          => chr(0x2145),
      double_struck_h                          => chr(0x210d),
      double_struck_n                          => chr(0x2115),
      double_struck_p                          => chr(0x2119),
      double_struck_q                          => chr(0x211a),
      double_struck_r                          => chr(0x211d),
      double_struck_z                          => chr(0x2124),
      double_struck_sigma                      => chr(0x2140),
    ],
    roman_numerals => [
      roman_numeral_i                          => chr(0x2160),
      roman_numeral_ii                         => chr(0x2161),
      roman_numeral_iii                        => chr(0x2162), # same as three_vert_bars
      roman_numeral_iv                         => chr(0x2163),
      roman_numeral_v                          => chr(0x2164),
      roman_numeral_vi                         => chr(0x2165),
      roman_numeral_vii                        => chr(0x2166),
      roman_numeral_viii                       => chr(0x2167),
      roman_numeral_ix                         => chr(0x2168),
      roman_numeral_x                          => chr(0x2169),
      roman_numeral_xi                         => chr(0x216a),
      roman_numeral_xii                        => chr(0x216b),
      roman_numeral_l                          => chr(0x216c),
      roman_numeral_c                          => chr(0x216d),
      roman_numeral_d                          => chr(0x216e),
      roman_numeral_m                          => chr(0x216f),
    ],
    lowercase_roman_numerals => [
      small_roman_numeral_i                    => chr(0x2170),
      small_roman_numeral_ii                   => chr(0x2171),
      small_roman_numeral_iii                  => chr(0x2172),
      small_roman_numeral_iv                   => chr(0x2173),
      small_roman_numeral_v                    => chr(0x2174),
      small_roman_numeral_vi                   => chr(0x2175),
      small_roman_numeral_vii                  => chr(0x2176),
      small_roman_numeral_viii                 => chr(0x2177),
      small_roman_numeral_ix                   => chr(0x2178),
      small_roman_numeral_x                    => chr(0x2179),
      small_roman_numeral_xi                   => chr(0x217a),
      small_roman_numeral_xii                  => chr(0x217b),
      small_roman_numeral_l                    => chr(0x217c),
      small_roman_numeral_c                    => chr(0x217d),
      small_roman_numeral_d                    => chr(0x217e),
      small_roman_numeral_m                    => chr(0x217f),
    ],
    ligatures => [
      ff_ligature                              => chr(0xfb00),
      fi_ligature                              => chr(0xfb01),
      fl_ligature                              => chr(0xfb02),
      ae_ligature                              => chr(0xe6),
      oe_ligature                              => chr(0x153),
      capital_ae_ligature                      => chr(0xc6),
      capital_oe_ligature                      => chr(0x152),
    ],
    medium_large_capital_letters => [
      medium_large_a                           => chr(0x13aa),
      medium_large_b                           => chr(0x13f4),
      medium_large_c                           => chr(0x13df),
      medium_large_d                           => chr(0x13a0),
      medium_large_e                           => chr(0x13ac),
      # medium_large_f => 
      medium_large_g                           => chr(0x13c0),
      medium_large_h                           => chr(0x13bb),
      medium_large_i                           => chr(0x13c6),
      medium_large_j                           => chr(0x13ab),
      medium_large_k                           => chr(0x13e6),
      medium_large_l                           => chr(0x13de),
      medium_large_m                           => chr(0x13b7),
      # medium_large_n => 
      # medium_large_o => 
      medium_large_p                           => chr(0x13e2),
      # medium_large_q => 
      medium_large_r                           => chr(0x13a1),
      medium_large_s                           => chr(0x13da),
      medium_large_t                           => chr(0x13a2),
      # medium_large_u => 
      medium_large_v                           => chr(0x13d9),
      medium_large_w                           => chr(0x13b3),
      # medium_large_x => 
      # medium_large_y => 
      medium_large_z                           => chr(0x13c3),
    ],
    lowercase_medium_large_letters => [
      lowercase_medium_b                       => chr(0x13cf),
      lowercase_medium_d                       => chr(0x13e7),
      lowercase_medium_h                       => chr(0x13c2),
      lowercase_medium_i                       => chr(0x13a5),
      lowercase_backwards_j                    => chr(0x13d3),
    ],
    overstruck_letters => [
      c_with_sparks                            => chr(0x13e8),
      o_with_skewed_slash                      => chr(0x13eb),
      o_with_horiz_line                        => chr(0x13be),
      rotated_left_t                           => chr(0x13b0),
      vert_bar_with_horiz_wave                 => chr(0x13d0),
    ],
    horizontal_bars => [
      three_horiz_bars                         => chr(0x2630),
      horiz_bar                                => chr(0x2500),
      heavy_horiz_bar                          => chr(0x2501),
      double_horiz_bars                        => chr(0x2550),
    ],
    vertical_bars => [
      long_narrow_vert_bar                     => chr(0x2502),
      long_narrow_double_vert_bars             => chr(0x2551),
      heavy_vertical_bar                       => chr(0x2759),
      very_heavy_vertical_bar                  => chr(0x275a),
      long_heavy_vert_bar                      => chr(0x2503),
      three_vert_bars                          => chr(0x2162), # same as roman_numeral_iii
      zigzag_vert_bar                          => chr(0x299a),
    ],
    dashed_horizontal_bars => [
      dashed_horiz_bar_2_dashes                => chr(0x254c),
      dashed_horiz_bar_3_dashes                => chr(0x2504),
      dashed_horiz_bar_4_dashes                => chr(0x2508),
      heavy_dashed_horiz_bar_2_dashes          => chr(0x254d),
      heavy_dashed_horiz_bar_3_dashes          => chr(0x2505),
      heavy_dashed_horiz_bar_4_dashes          => chr(0x2509),
    ],
    dashed_vertical_bars => [
      dashed_vert_bar_2_dashes                 => chr(0x254e),
      dashed_vert_bar_3_dashes                 => chr(0x2506),
      dashed_vert_bar_4_dashes                 => chr(0x250a),
      dotted_vert_bar_3_dots                   => chr(0x2807),
      dotted_vert_bar_4_dots                   => chr(0x2847),
      dotted_vert_bar_3_heavy_dots             => chr(0x2507),
      dotted_vert_bar_4_heavy_dots             => chr(0x250b),
      dotted_vert_bar_3_tiny_dots              => chr(0x1367),
      dotted_vert_bar_2_tiny_dots              => chr(0x16ec),
    ],
    half_dashes => [
      left_half_dash                           => chr(0x2574),
      heavy_left_half_dash                     => chr(0x2578),
      left_heavy_right_light_dash              => chr(0x257e),
      right_half_dash                          => chr(0x2576),
      heavy_right_half_dash                    => chr(0x257a),
      left_light_right_heavy_dash              => chr(0x257c),
    ],
    slashes => [
      large_left_slash                         => chr(0x2572),
      medium_left_slash                        => chr(0x3035),
      large_right_slash                        => chr(0x2571),
      medium_right_slash                       => chr(0x3033),
      split_right_slash                        => chr(0x2215),
      three_right_slashes                      => chr(0x2425),
    ],
    letter_slash_letter => [
      a_slash_c                                => chr(0x2100),
      a_slash_s                                => chr(0x2101),
      c_slash_o                                => chr(0x2105),
      c_slash_u                                => chr(0x2106),
    ],
    overstruck_slashes => [
      right_slash_x_1_with_horiz_line          => chr(0x168b),
      right_slash_x_2_with_horiz_line          => chr(0x168c),
      right_slash_x_3_with_horiz_line          => chr(0x168d),
      right_slash_x_4_with_horiz_line          => chr(0x168e),
      right_slash_x_5_with_horiz_line          => chr(0x168f),
    ],
    accents => [  
      acute_accent                             => chr(0x141f),
      grave_accent                             => chr(0x1420),
    ],
    under_bars => [    
      under_space                              => chr(0x2423),
      long_under_bar                           => chr(0xff3f),
      one_part_under_bar                       => chr(0x268a),
      two_part_under_bar                       => chr(0x268b),
      two_horiz_lines                          => chr(0x268c),
    ],
    dashes => [
      normal_dash                              => chr(0x002d),
      figure_dash                              => chr(0x2012),
      en_dash                                  => chr(0x2013),
      em_dash                                  => chr(0x2014),
      horiz_dash                               => chr(0x2015),
      narrow_wavy_horiz_dash                   => chr(0x2053),
      wavy_horiz_dash                          => chr(0x3030),
      sine_wave_horiz_dash                     => chr(0x301c),
    ],
    boxes_and_squares => [
      empty_box                                => chr(0x2610),
      empty_square                             => chr(0x2610),
      box_with_shadow                          => chr(0x274f),
      dotted_square                            => chr(0x2b1a),
      hatched_square_light                     => chr(0x2591),
      hatched_square_medium                    => chr(0x2592),
      hatched_square_dark                      => chr(0x2593),
      solid_block                              => chr(0x2588),
    ],
    edge_lines => [
      left_edge_vert_bar                       => chr(0x258f),
      right_edge_vert_bar                      => chr(0x2595),
      bottom_edge_horiz_bar                    => chr(0x2581),
      top_edge_horiz_bar                       => chr(0x2594),
      thin_top_edge_horiz_bar                  => chr(0xffe3),
    ],
    blocks => [
      top_half_block                           => chr(0x2580),
      bottom_half_block                        => chr(0x2584),
      left_half_block                          => chr(0x258c),
      right_half_block                         => chr(0x2590),
    ],
    circles => [
      large_circle                             => chr(0x3007),
      medium_circle                            => chr(0x039f),
      circle_with_shadow                       => chr(0x274d),
      copyright_symbol                         => chr(0x00a9), # also in special_symbols
      reg_tm_symbol                            => chr(0x00ae), # also in special_symbols
      telephone_in_circle                      => chr(0x2706), # also in special_symbols
      p_in_circle                              => chr(0x2117), # also in special_symbols
    ],
    inside_circle => [
      dot_in_circle                            => chr(0x2609),
      dot_in_small_circle                      => chr(0x25c9),
      x_in_two_nested_circles                  => chr(0x2a37),
      less_than_in_circle                      => chr(0x29c0),
      greater_than_in_circle                   => chr(0x29c1),
      plus_in_circle                           => chr(0x2295),
      minus_in_circle                          => chr(0x2296),
      divisor_in_circle                        => chr(0x2a38),
      x_in_circle                              => chr(0x2b59), 
    ],
    inside_square => [
      plus_in_square                           => chr(0x229e),
      minus_in_square                          => chr(0x229d),
      asterisk_in_square                       => chr(0x29C6),
      right_slash_in_square                    => chr(0x29C4),
      left_slash_in_square                     => chr(0x29C5),
      circle_in_square                         => chr(0x29C7),
      square_in_square                         => chr(0x29C8),
      overlapping_squares                      => chr(0x29C9),
      x_in_box                                 => chr(0x2612),
      box_with_right_slash                     => chr(0x303c),
    ],
    inside_triangle => [
      plus_in_triangle                         => chr(0x2a39),
      minus_in_triangle                        => chr(0x2a3a),
      s_in_triangle                            => chr(0x29CC),
      x_in_triangle                            => chr(0x2a3b),
    ],
    diamonds => [
      four_diamonds                            => chr(0x2756),
      small_four_diamonds                      => chr(0x700),
      open_diamond                             => chr(0x2662),
      diamond                                  => chr(0x2666),
    ],
    stacked_discs => [
      single_disc                              => chr(0x26c0),
      double_disc                              => chr(0x26c1),
      single_disc_black                        => chr(0x26c2),
      double_disc_black                        => chr(0x26c3),
    ],
    dice => [  
      dice_1_dots                              => chr(0x2680),
      dice_2_dots                              => chr(0x2681),
      dice_3_dots                              => chr(0x2682),
      dice_4_dots                              => chr(0x2683),
      dice_5_dots                              => chr(0x2684),
      dice_6_dots                              => chr(0x2685),
    ],
    subscript_numbers => [
      subscript_0                              => chr(0x2080),
      subscript_1                              => chr(0x2081),
      subscript_2                              => chr(0x2082),
      subscript_3                              => chr(0x2083),
      subscript_4                              => chr(0x2084),
      subscript_5                              => chr(0x2085),
      subscript_6                              => chr(0x2086),
      subscript_7                              => chr(0x2087),
      subscript_8                              => chr(0x2088),
      subscript_9                              => chr(0x2089),
    ], 
    subscript_letters => [
      subscript_a                              => chr(0x2090),
      subscript_e                              => chr(0x2091),
      subscript_o                              => chr(0x2092),
      subscript_x                              => chr(0x2093),
      subscript_h                              => chr(0x2095),
      subscript_k                              => chr(0x2096),
      subscript_l                              => chr(0x2097),
      subscript_m                              => chr(0x2098),
      subscript_n                              => chr(0x2099),
      subscript_p                              => chr(0x209a),
      subscript_s                              => chr(0x209b),
      subscript_t                              => chr(0x209c),
    ],
    subscript_symbols => [
      subscript_plus                           => chr(0x208a),
      subscript_minus                          => chr(0x208b),
      subscript_equals                         => chr(0x208c),
      subscript_left_paren                     => chr(0x208d),
      subscript_right_paren                    => chr(0x208e),
    ],
    superscript_symbols => [
      superscript_plus                         => chr(0x207a),
      superscript_minus                        => chr(0x207b),
      superscript_equals                       => chr(0x207c),
      superscript_1                            => chr(0x00b9),
      squared_symbol                           => chr(0x00b2), # superscript 2 (squared)
      cubed_symbol                             => chr(0x00b3),
      square_root_symbol                       => chr(0x221a),
      cube_root_symbol                         => chr(0x221b),
      fourth_root_symbol                       => chr(0x221c),
      superscript_double_right_slash           => chr(0x1425),
      superscript_small_minus                  => chr(0x1428),
      superscript_small_plus                   => chr(0x1429),
      superscript_uppercase_t                  => chr(0x142a),
    ],
    fractions => [
      fraction_1_4                             => chr(0x00bc),
      fraction_1_2                             => chr(0x00bd),
      fraction_3_4                             => chr(0x00be),
    ],
    large_multi_char_symbols => [ # Multi-character composite symbols:
      long_bold_right_arrow                    => chr(0x2015).chr(0x25b6),
      long_bold_right_arrow_double_line        => chr(0x2550).chr(0x25b6),
      long_bold_right_arrow_heavy_line         => chr(0x2501).chr(0x25b6),
      long_bold_two_dotted_right_arrow         => chr(0x254d).chr(0x25b6),
      long_bold_finely_dotted_right_arrow      => chr(0x2509).chr(0x25b6),
      long_bold_dotted_right_arrow             => chr(0x254d).chr(0x25b6),
      wide_square_root_symbol                  => chr(0x221a).chr(0xffe3),
      large_square_root_symbol                 => chr(0x221a).chr(0x2594),
      wide_open_up_arrow                       => chr(0x2571).chr(0x2572),
      wide_open_down_arrow                     => chr(0x2572).chr(0x2571),
    ],
  );

  our %symbols = map { @$_ } (values %symbol_groups);

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

  our %top_level_symbol_groups = (
    letters => [ qw(large_letters script_letters double_struck_letters medium_large_capital_letters lowercase_medium_large_letters superscript_letters greek_letters stylized_letters overstruck_letters letter_slash_letter subscript_letters) ],
    symbols => [ qw(special_symbols keyboard_symbols subscript_symbols superscript_symbols large_multi_char_symbols) ],
    numbers => [ qw(subscript_numbers fractions) ],
    inside_shapes => [ qw(inside_circle inside_square inside_triangle) ],
    arrows => [ qw(right_arrows bold_arrows barbed_arrows triangular_arrows shadowed_arrows special_arrows long_arrows bidirectional_arrows diagonal_arrows) ],
    bars_and_lines => [ qw(horizontal_bars vertical_bars dashed_horizontal_bars dashed_vertical_bars under_bars) ],
  );

  map {
    $_ = { 
      (map {
        my $pairs = $symbol_groups{$_};
        ($_ => { @$pairs });
      } @$_) 
    };
  } (values %top_level_symbol_groups);

  #
  # Most modern X based terminal programs can display Unicode symbols
  # (at least rxvt, urxvt, konsole, gnome-terminal, etc as well as Mac
  # OS X Terminal and probably more), although a few of these (like
  # KDE 3.x's konsole) cannot properly display some symbols, especially
  # symbols wider than the fixed width font's character cell width.
  #
  # In contrast, some terminal types cannot display Unicode characters
  # at all, including older X terminal versions like the original xterm,
  # and obviously any non-graphical terminal in text based video mode,
  # such as the Linux console (which can only display ASCII characters
  # 0x00-0xff since the frame buffer fonts lack the proper symbols).
  #
  # While users typically will spend most of their time with a terminal
  # that supports Unicode characters, in some situations this is not
  # possible, like doing system administration from the console without
  # an X server, or connecting remotely from a system without Unicode
  # support in its terminal program.
  #
  # Given these differences in terminal capabilities and availability
  # regarding Unicode symbols (and the fact that some situations will
  # preclude the use of a graphical terminal program), there must be
  # a fallback method for displaying alternative characters if the
  # desired Unicode symbols cannot be displayed.
  #
  # Fortunately many of the symbols listed above have similar looking 
  # equivalents, at least enough to imply what the original symbol was, 
  # despite being visually ugly and indistinguishable from any other
  # Unicode symbols mapped to the same alternative.
  #
  # The tables below perform this mapping from supported Unicode 
  # symbols to their non-Unicode replacements. These tables are 
  # used by the prints() and printfd() functions and various other 
  # packages, either directly depending on whether or not the 
  # terminal can handle Unicode, or automatically by letting
  # prints() and printfd() substitute any Unicode symbols right
  # before they write the output to the terminal (via stdout).
  # 
  # (For symbols where no reasonable ASCII alternative character
  # exists, in most cases '?' is printed instead).
  #
  noexport: sub equiv($;@) {
    my ($ascii_chars, @unicode_symbol_names) = @_;
    (map { (($symbols{$_} // $_) => $ascii_chars) } @unicode_symbol_names);
  }

  our %unicode_symbols_to_ascii_equivalent = (
    (equiv ' ' => qw(non_breaking_space nbsp en_space em_space fig_space punc_space thin_space hair_space zero_space)),
    (equiv '<-' => qw(left_arrow_bold long_left_arrow plus_under_left_arrow plus_under_left_arrow_arc small_left_barbed_arrow)),
    (equiv '->' => qw(arrow_right_right arrow_right_thin_tiny arrow_right_tiny long_bold_right_arrow 
                       long_bold_right_arrow_double_line long_bold_right_arrow_heavy_line long_right_arrow 
                       long_right_wavy_arrow plus_under_right_arrow small_right_barbed_arrow)),
    (equiv '-o>' => qw(right_arrow_through_circle)),
    (equiv '/\\' => qw(small_up_barbed_arrow three_bars_up_arrow up_arrow_bold wide_open_up_arrow)),
    (equiv '\\/' => qw(down_arrow_bold small_down_barbed_arrow three_bars_down_arrow wide_open_down_arrow)),
    #+++MTY TODO:
    #    equiv alt_down_arrow_open_tri  down_arrow_open_tri down_arrow_tri
    #alt_left_arrow_open_tri left_arrow_open_tri left_arrow_tri  left_arrow_open_tri
    #alt_up_arrow_open_tri  delta_up_tri up_arrow_open_tri up_arrow_tri 
    #alt_right_arrow_open_tri arrow_medium_open_tri arrow_open_tri
    #equiv qw(arrow_medium_tri arrow_tri arrow_tri_large arrow_tri_small
    #  equiv alt_down_arrow_open_tri alt_left_arrow_open_tri alt_right_arrow_open_tri alt_up_arrow_open_tri arrow_medium_open_tri arrow_medium_tri arrow_open_tri arrow_tri arrow_tri_large arrow_tri_small down_arrow_open_tri down_arrow_tri left_arrow_open_tri left_arrow_tri up_arrow_open_tri up_arrow_tri '
  );

}; # end of BEGIN compile time block

use constant {
  THREE_LETTER_SYMBOLS_FOR_CONTROL_CHARS_BASE => 0x2400
};

use constant \%symbols;
use constant \%enclosed_digit_sequence_symbol_bases;

BEGIN {
  #
  #  All output of UTF-8 Unicode symbols can be disabled 
  #  by running this from the shell: 
  #   
  #     export PrintableSymbols=0
  # 
  # (or the equivalent settings of "no", "off", "disable", "disabled")
  #
  # This will replace any printable characters listed above with new
  # ASCII compatible (low 256 characters) definitions which appear
  # somewhat similar in many cases (see comments above regarding the
  # %unicode_symbols_to_ascii_equivalent hash.
  #
  #

my $envconfig = $ENV{'PrintableSymbols'} // '';

our @symbol_names = keys %symbols;

if ($envconfig =~ /^(?:0|no|off|disable)/oax) {
  foreach my $k (@symbol_names) { $symbols{$k} = '?'; }
  foreach my $k (keys %enclosed_digit_sequence_symbol_bases) 
    { $enclosed_digit_sequence_symbol_bases{$k} = ord('0'); }
}

#
# Define and instantiate actual variables for each symbol name, i.e.
# for this_symbol_name constant, this creates $this_symbol_name:
#
use vars @symbol_names;
foreach my $name (@symbol_names) { ${$name} = $symbols{$name}; }

preserve:; our @EXPORT = (
  @symbol_names, # export all the defined constants by name
  (map { '$'.$_ } @symbol_names), 
  (keys %enclosed_digit_sequence_symbol_bases), 
  qw(@symbol_names %symbols %symbol_groups %top_level_symbol_groups %symbols_to_non_unicode_equivalent)
);

}; # (BEGIN)

1;
 


