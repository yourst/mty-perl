# -*- cperl -*-
#
# Text in a Box (MTY::Display::TextInABox)
#
# Print text inside an ASCII box drawing character frame
# (works with most modern consoles and terminal emulators
# when using fonts which include these Unicode characters)
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Display::TextInABox;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(VERT HORIZ JOIN_TOP JOIN_LEFT JOIN_RIGHT LOWER_LEFT NO_BOX_TOP STYLE_NAME
     UPPER_LEFT JOIN_BOTTOM LOWER_RIGHT NO_BOX_LEFT TEXTBOX_DIV TEXTBOX_ESC
     TEXTBOX_REP TEXTBOX_SYM UPPER_RIGHT HORIZ_BOTTOM NO_BOX_RIGHT
     TEXTBOX_FILL TEXTBOX_TABS print_banner NO_BOX_BOTTOM TEXTBOX_ALIGN
     TEXTBOX_COLOR text_in_a_box TEXTBOX_BG_RGB TEXTBOX_COLUMN TEXTBOX_ENDREP
     TEXTBOX_FG_RGB TEXTBOX_END_BOX expand_alignment lookup_div_style
     print_folder_tab print_horiz_line format_horiz_line %box_style_aliases
     make_div_box_style TEXTBOX_CLEAR_SCREEN lookup_style_by_name
     show_warning_message TAB_IS_ATTACHED_TO_BOX TAB_STRAIGHT_TAB_EDGES
     %textbox_command_to_name TAB_STRAIGHT_BOTTOM_EDGES
     TAB_ONE_LINE_OVERLAY_LABEL make_center_div_only_box_style
     %textbox_command_name_to_command fg_bg_and_rgb_hex_or_list_to_codes
     colorize_insert_symbols_and_interpolate_control_chars);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::StringFormats;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::Blocks;
use MTY::RegExp::Numeric;
use MTY::RegExp::Strings;
#pragma end_of_includes

noexport:; use constant enum qw(
  STYLE_NAME
  UPPER_LEFT HORIZ        UPPER_RIGHT
  JOIN_LEFT  VERT         JOIN_RIGHT
  LOWER_LEFT HORIZ_BOTTOM LOWER_RIGHT
  JOIN_TOP   JOIN_BOTTOM
);

# Box drawing characters
my @no_box_style = (
  'none',
  '', '', '',
  '', '', '',
  '', '', '',
  '', '');

my @single_box_style = (
  'single',
  chr(0x250c), chr(0x2500), chr(0x2510),
  chr(0x251c), chr(0x2502), chr(0x2524), 
  chr(0x2514), chr(0x2500), chr(0x2518),
  chr(0x252c), chr(0x2534));

my @rounded_box_style = (
  'rounded',
  chr(0x256d), chr(0x2500), chr(0x256e),
  chr(0x251c), chr(0x2502), chr(0x2524), 
  chr(0x2570), chr(0x2500), chr(0x256f),
  chr(0x252c), chr(0x2534));

my @double_box_style = (
  'double',
  chr(0x2554), chr(0x2550), chr(0x2557),
  chr(0x2560), chr(0x2551), chr(0x2563), 
  chr(0x255a), chr(0x2550), chr(0x255d),
  chr(0x2566), chr(0x2569));

my @thick_box_style = (
  'thick',
  chr(0x250f), chr(0x2501), chr(0x2513),
  chr(0x2523), chr(0x2503), chr(0x252b),
  chr(0x2517), chr(0x2501), chr(0x251b),
  chr(0x2533), chr(0x253b));

my @ultrawide_box_style = (
  'ultrawide',
  chr(0x259b), chr(0x2584), chr(0x259c),
  chr(0x258c), chr(0x258c), chr(0x2590),
  chr(0x2599), chr(0x2580), chr(0x259f),
  undef, undef);

noexport:; sub make_div_box_style($$$$;$$) {
  my @a = ( );
  @a[STYLE_NAME, JOIN_LEFT, HORIZ, JOIN_RIGHT, JOIN_TOP, JOIN_BOTTOM] = @_;
  return @a;
}

my @single_vert_double_horiz_box_style = (
  'double_vert_single_horiz',
  chr(0x2552), chr(0x2550), chr(0x2555),
  chr(0x255e), chr(0x2551), chr(0x2561),
  chr(0x2558), chr(0x2550), chr(0x255b),
  chr(0x2564), chr(0x2567));

my @double_vert_single_horiz_box_style =
  make_div_box_style('double_vert_single_horiz',
                     chr(0x255f), chr(0x2500), chr(0x2562),
                     chr(0x2565), chr(0x2568));

my @single_vert_thick_horiz_box_style = (
  'single_vert_thick_horiz',
  chr(0x250d), chr(0x2501), chr(0x2511),
  chr(0x251d), chr(0x2502), chr(0x2525),
  chr(0x2515), chr(0x2501), chr(0x2519),
  chr(0x252f), chr(0x2537));
  
my @thick_vert_single_horiz_box_style =
  make_div_box_style('thick_vert_single_horiz',
                     chr(0x2520), chr(0x2500), chr(0x2528),
                     chr(0x2530), chr(0x2538));

my @thick_vert_double_horiz_box_style =
  make_div_box_style('thick_vert_double_horiz',
                     chr(0x2520), chr(0x2550), chr(0x2528),
                     undef, undef);

noexport:; sub make_center_div_only_box_style($$) {
  my @a = ( );
  @a[STYLE_NAME, HORIZ] = @_;
  return @a;
}

my @dotted_box_style = 
  make_center_div_only_box_style('dotted', dashed_horiz_bar_3_dashes);

my @heavy_dotted_box_style = 
  make_center_div_only_box_style('heavy_dotted', heavy_dashed_horiz_bar_2_dashes);

my @sparse_dotted_box_style = 
  make_center_div_only_box_style('sparse_dotted', dot_small);

my @dashed_box_style = 
  make_center_div_only_box_style('dashed', dashed_horiz_bar_2_dashes);

my @heavy_dashed_box_style = 
  make_center_div_only_box_style('heavy_dashed', heavy_left_half_dash);

my @long_dashed_box_style = 
  make_center_div_only_box_style('long_dashed', left_half_dash);

my @alternating_heavy_light_dashed_box_style = 
  make_center_div_only_box_style('alternating_heavy_light_dashed', left_heavy_right_light_dash);

our %box_style_aliases = (
  'none'      => 'none',
  'nobox'     => 'none',
  'invisible' => 'none',

  'single' => 'single',
  'narrow' => 'single',
  'thin'   => 'single',
  'light'  => 'single',

  'double' => 'double',

  'thick'  => 'thick',
  'heavy'  => 'thick',
  'wide'   => 'thick',
  'bold'   => 'thick', 

  'ultrawide' => 'ultrawide',
  'superheavy' => 'ultrawide',
  'extrathick' => 'ultrawide',

  'rounded' => 'rounded',
  'curved' => 'rounded',
  'beveled' => 'rounded',
  'smooth' => 'rounded',

  'single_vert_double_horiz' => 'single_vert_double_horiz',
  'double_vert_single_horiz' => 'double_vert_single_horiz',
  'single_vert_thick_horiz' => 'single_vert_thick_horiz',
  'thick_vert_single_horiz' => 'thick_vert_single_horiz',
  'thick_vert_double_horiz' => 'thick_vert_double_horiz',

  'dotted' => 'dotted',
  'dots'   => 'dotted',

  'heavy_dots' => 'heavy_dotted',
  'heavy_dotted' => 'heavy_dotted',

  'sparse_dotted' => 'sparse_dotted',
  'light_dotted' => 'sparse_dotted',

  'dashed' => 'dashed',
  'dashes' => 'dashed',

  'heavy_dashes' => 'heavy_dashed',
  'heavy_dashed' => 'heavy_dashed',

  'long_dashes' => 'long_dashed',
  'long_dashed' => 'long_dashed',

  'alternating_dashed' => 'alternating_dashed',
);

my %box_styles = (
  none => \@no_box_style,
  single => \@single_box_style,
  double => \@double_box_style,
  rounded => \@rounded_box_style,
  thick => \@thick_box_style,
  ultrawide => \@ultrawide_box_style,
  single_vert_double_horiz => \@single_vert_double_horiz_box_style,
  double_vert_single_horiz => \@double_vert_single_horiz_box_style,
  single_vert_thick_horiz => \@single_vert_thick_horiz_box_style,
  thick_vert_single_horiz => \@thick_vert_single_horiz_box_style,
  thick_vert_double_horiz => \@thick_vert_double_horiz_box_style,
  dotted => \@dotted_box_style,
  heavy_dotted => \@heavy_dotted_box_style,
  sparse_dotted => \@sparse_dotted_box_style,
  dashed => \@dashed_box_style,
  heavy_dashed => \@heavy_dashed_box_style,
  long_dashed => \@long_dashed_box_style,
  alternating_dashed => \@alternating_heavy_light_dashed_box_style);

my %aligntype_as_text_to_aligntype = (
  'left' => ALIGN_LEFT,
  'center' => ALIGN_CENTER,
  'right' => ALIGN_RIGHT,
  'justified' => ALIGN_JUSTIFIED,
  'l' => ALIGN_LEFT,
  'c' => ALIGN_CENTER,
  'r' => ALIGN_RIGHT,
  'j' => ALIGN_JUSTIFIED
);

noexport:; sub show_warning_message {
  $include_stack_backtrace = 0;
  warn(@_);
  $include_stack_backtrace = 1;
  return $_[0];
}

noexport:; sub expand_alignment($$$$;$) {
  my ($text, $aligntype_as_text, $tokenoffs, $width, $pad) = @_;

  my $aligntype = $aligntype_as_text_to_aligntype{lc($aligntype_as_text)};

  if (!(defined $aligntype)) {
    show_warning_message('Invalid alignment "'.$aligntype_as_text.'"; using left as default');
    $aligntype = ALIGN_LEFT;
  }
  
  return padstring($text, $width - $tokenoffs, $aligntype, $pad // ' ');
}

noexport:; sub fg_bg_and_rgb_hex_or_list_to_codes($$$$$) {
  my ($fg_or_bg, $hex_rgb, $r, $g, $b) = @_;
  if (is_there $hex_rgb) { ($r, $g, $b) = parse_rgb_hex_triplet($hex_rgb); }
  return ($fg_or_bg eq 'bg')
    ? bg_color_rgb($r, $g, $b)
    : fg_color_rgb($r, $g, $b);
}

noexport:; sub lookup_style_by_name($;$) {
  my ($style_alias, $fallback) = @_;

  $fallback //= 'single';
  
  # Pass through style that waas already resolved into its char array:
  if (is_array_ref($style_alias)) { return $style_alias; }

  my $style_name = $box_style_aliases{$style_alias};
  
  if (!defined $style_name) {
    show_warning_message('Box style "'.$style_alias.'" '.
      'does not exist; using default style "single"'); 
    $style_name = 'single';
  }
  
  my $style = $box_styles{$style_name};
  die if (!defined $style);

  return $style;
}

noexport:; sub lookup_div_style($$;$) {
  my ($style_name, $divstyle_alias, $default_style_ref) = @_;

  my $divstyle_name = $box_style_aliases{$divstyle_alias};

  if (!defined $divstyle_name) {
    show_warning_message('Box divider style "'.$divstyle_alias.'" '.
      'does not exist; using default style instead'); 
    return $default_style_ref;
  }

  my $divstyle_full_name = $style_name.'_vert_'.$divstyle_name.'_horiz';

  my $divstyle = $box_styles{$divstyle_full_name};

  if (!defined $divstyle) {
    # Try to construct a custom style (left and right edges won't
    # perfectly match, but usually it's close enough:
    $divstyle = $box_styles{$divstyle_name};

    if (!$divstyle) {
      show_warning_message('Neither box divider compound style '.
        '"'.$divstyle_full_name.'" nor basic style "'.$divstyle_name.'" '.
        ' are defined; using default style instead'); 
      return $default_style_ref;
    }

    $divstyle = copy_array_elements_where_undef($divstyle, $default_style_ref);
  }

  return $divstyle;
}

my $split_nl_re;
my $colorize_markup_chars_re;
my $remove_markup_re;
my $markup_or_text_re;
my $contains_endbox_re;
my $folder_tab_re;

#
# Integer constants which can be used in place of the equivalent
# %{command[=value]} syntax, to remove the overhead of parsing
# the text based forms of these commands. 
# 
# To use these constants on a given line, specify the line as an
# array instead of a string. Each array element can be either:
#
# 1. a scalar text string (all of these text strings will be joined
#    together without spaces to form the line to be printed. 
#
#    Newlines are NOT required as the last text character on a line; 
#    they will be discarded if included (to avoid starting redundant 
#    new lines which would corrupt the appearance of the box).
#
#    Chunks of text may themselves include %{command[=value]} style 
#    commands; these will be expanded by effectively splitting the text 
#    chunk into its substrings separated by the freely intermixed commands.
#
# 2. a reference to an array, with a TEXTBOX_xxx constant at index 0,
#    and any parameters to that command as the remaining elements
#    (The specified command will apply to any subsequent text strings).
#
# Example:
#
#   my $boxspec = [
#     # line #1 (printed as "Text chunk is purple!" (with "purple" colored)
#     [ 'Text chunk is ', [ TEXTBOX_FG_RGB, 128, 0, 255 ], 'purple!' ],
#     # line #2 (printed as divider similar to "=============...":
#     [ [ TEXTBOX_DIV, 'double' ] ],
#     # line #3 (printed as "         Center Aligned Text Here         ")
#     [ [ TEXTBOX_ALIGN, ALIGN_CENTER ], 'Center Aligned Text Here' ]
#     # line #4 (printed as "           Embedded RED word              ")
#     # with the word "RED" actually colored red.
#     [ 'Embedded %RRED%X word' ]
#   ];
#
# Note that simple colors (the %R, %G, %B, etc escapes along with
# %U/!%U for underlining and %X to reset the colors) can also be
# expressed as [ TEXTBOX_COLOR, 'R' ] (or either $R or R), but this
# is usually not very practical since it's much more compact and
# readable to simply include '...%R...' within a string chunk.
#

# %R,%G,%B,...,%U,%!U,%X,etc => e.g. [ TEXTBOX_COLOR, 'R' ]

use constant enum qw(
  TEXTBOX_COLOR
  TEXTBOX_ALIGN
  TEXTBOX_COLUMN
  TEXTBOX_DIV
  TEXTBOX_TABS
  TEXTBOX_SYM
  TEXTBOX_FG_RGB
  TEXTBOX_BG_RGB
  TEXTBOX_REP
  TEXTBOX_ENDREP
  TEXTBOX_FILL
  TEXTBOX_END_BOX
  TEXTBOX_CLEAR_SCREEN
  TEXTBOX_ESC
);

our %textbox_command_to_name = (
  # TEXTBOX_COLOR,        'color', # (but not representable this way)
  TEXTBOX_ALIGN,        'align',
  TEXTBOX_COLUMN,       'column',
  TEXTBOX_DIV,          'div',
  TEXTBOX_TAB,          'tab',
  TEXTBOX_SYM,          'sym',
  TEXTBOX_FG_RGB,       'rgb',
  TEXTBOX_BG_RGB,       'bgrgb',
  TEXTBOX_REP,          'rep',
  TEXTBOX_ENDREP,       'endrep',
  TEXTBOX_FILL,         'fill',
  TEXTBOX_END_BOX,      'endbox',
  TEXTBOX_CLEAR_SCREEN, 'clearscreen',
  TEXTBOX_ESC,          'esc',
);

our %textbox_command_name_to_command = (
  # TEXTBOX_COLOR,        'color', # (but not representable this way)
  'align'               => TEXTBOX_ALIGN,
  'column'              => TEXTBOX_COLUMN,
  'div'                 => TEXTBOX_DIV,
  'tab'                 => TEXTBOX_TAB,
  'sym'                 => TEXTBOX_SYM,
  'rgb'                 => TEXTBOX_FG_RGB,
  'bgrgb'               => TEXTBOX_BG_RGB,
  'rep'                 => TEXTBOX_REP,
  'endrep',             => TEXTBOX_ENDREP,
  'fill',               => TEXTBOX_FILL,
  'endbox'              => TEXTBOX_END_BOX,
  'clearscreen'         => TEXTBOX_CLEAR_SCREEN,
  'esc'                 => TEXTBOX_ESC,
);

BEGIN {
  $split_nl_re = qr{\n}oamsx;

  $colorize_markup_chars_re = 
  '[RGBCMYKWQrgbcmykwq] | \!? [UNVX]';

  $remove_markup_re = qr{(?<= %) % | (?<! [\%\\]) \% \{ [^\}]++ \}}oamsx;

  $markup_arg_re = qr{(?> ([^\,\}]++)(?> , | (?= \})))}oamsx;

  $generalized_markup_or_text_re = compile_regexp(
    qr{(?<! [\\]) \% (?|
          ($colorize_markup_chars_re) (*:COLOR) |
          \{ (?|
            ($colorize_markup_chars_re) (*:COLOR) |
            (?> (\w+) (?: = $markup_arg_re (?> $markup_arg_re (?> $markup_arg_re (?> $markup_arg_re)?)?)?)?)
          ) \}) |
        ((?> [^\%\n\\] | %% | \\ .)++) (*:TEXT)
       }oamsx, 'markup_or_text_re');

  $markup_or_text_re = compile_regexp(
    qr{(?<! [\\]) \% (?|
          ($colorize_markup_chars_re) (*:COLOR) |
          \{ (*:MARKUP) (?|
            ($colorize_markup_chars_re) (*:COLOR) |
            (?> (left|center|right) (*:ALIGN)) |
            (?> (align) = (\w+) (?> ,pad = ([^\}]++))? (*:ALIGN)) |
            (?> (column) = ([\+\-]?) (\d+) (?> ,pad = ([^\}]++))? (*:COLUMN)) |
            (?> (div) (?: = ($inside_braces_re))? (*:DIV)) |
            (?> (tab) = ([\d\+\,]+) (*:TAB)) |
            (?> (sym) = ($printable_symbol_spec_re) (*:SYM)) |
            (?> (fg | bg | rgb (?:fg | bg)?) =
              (?>
                (\# [[:xdigit:]]{6}) |
                (?: (\d+) , (\d+) , (\d+))
              ) (*:RGB)
            ) |
            (?> (rep) (?> = (\d+))? (*:REP)) |
            (?> (endrep) (?> = (\d+))? (*:ENDREP)) |
            (?> (fill) (*:FILL)) |
            (?> (consoletitle) = ($inside_braces_re) (*:TITLE)) |
            (?> (consolesubtitle) = ($inside_braces_re) (*:SUBTITLE)) |
            (?> (endbox) (*:ENDBOX)) |
            (?> (clear(?>screen)?) (*:CLEAR)) |
            (?> (esc) = ($inside_braces_re) (*:ESC))
          ) \} |
          \[ () ($printable_symbol_spec_re) (*:SYM) 
        )
      | ((?> [^\%\n\\] | \\ .)++) (*:TEXT)
     }oamsx, 'markup_or_text_re');

  $contains_endbox_re = qr{(?<! \\) \%\{endbox\}}oamsx;

  $folder_tab_re = qr{^ \%\{tab (?: = (\w+) (?: , (\w+))? )? \} (.+)$}oax;
  $folder_tab_div_re = qr{^ \%\{tabdiv\} $}oax;
};

sub format_horiz_line(;$$$) {
  my ($color, $style_name, $width) = @_;
  $color //= $B;
  $style_name //= 'single';
  $width //= (get_terminal_width_in_columns() - 1);

  my $style = lookup_style_by_name($style_name, 'single');
  return $color.($style->[HORIZ] x $width).X.NL;
}

sub print_horiz_line(;$$$$) {
  my ($color, $style_name, $width, $fd) = @_;
  $fd //= STDOUT;
  printfd($fd, format_horiz_line($color, $style_name, $width));
}

use constant enumbits qw(
  NO_BOX_TOP
  NO_BOX_BOTTOM
  NO_BOX_LEFT
  NO_BOX_RIGHT
);

use constant enumbits qw(
  TAB_STRAIGHT_BOTTOM_EDGES
  TAB_STRAIGHT_TAB_EDGES
  TAB_ONE_LINE_OVERLAY_LABEL
  TAB_IS_ATTACHED_TO_BOX
);

sub colorize_insert_symbols_and_interpolate_control_chars($) {
  return 
    interpolate_control_chars(
      replace_printable_symbol_names_with_characters(
        colorize($_[0])));
}

my %style_name_to_tab_style_name = (
  'single' => 'rounded',
  'double' => 'single_vert_double_horiz',
  'thick' => 'single_vert_thick_horiz'
);

sub print_folder_tab($;$$$$$$$$) {
  my $label = shift;
  my ($outline_color, $alignment, $width, $style_name, $flags, $prefix, $suffix, $dots_under_label_color) = 
    named_or_ordered_args @_, qw(outline_color alignment width style flags prefix suffix dots_under_label_color);

  chomp $label;

  $flags //= (defined $style_name) ? 0 : TAB_STRAIGHT_BOTTOM_EDGES;

  my $tab_is_attached_to_box = ($flags & TAB_IS_ATTACHED_TO_BOX) ? 1 : 0;
  my $straight_bottom_edges = ($flags & TAB_STRAIGHT_BOTTOM_EDGES) ? 1 : 0;
  my $one_line_overlay_label = ($flags & TAB_ONE_LINE_OVERLAY_LABEL) ? 1 : 0;

  if ($tab_is_attached_to_box) { $flags &= ~TAB_STRAIGHT_BOTTOM_EDGES; }

  if (!$tab_is_attached_to_box) 
    { $label = colorize_insert_symbols_and_interpolate_control_chars($label); }

  $label =~ s{\\ \%}{%}oamsxg;

  my $is_rgb_capable = 
    (is_console_color_capable() >= ENHANCED_RGB_COLOR_CAPABLE);

  $outline_color //= (($is_rgb_capable) ? fg_color_rgb(128, 64, 192) : $B);

  my $tab_div_str = $outline_color.long_narrow_vert_bar;
  $label =~ s{$folder_tab_div_re}{$tab_div_str}oax;

  $alignment //= (($flags // 0) & TAB_ONE_LINE_OVERLAY_LABEL) ? ALIGN_CENTER : ALIGN_LEFT;

  $prefix //= '';
  $suffix //= '';

  $width //= (get_terminal_width_in_columns() - 1) - 
    (printed_length($prefix) + printed_length($suffix));

  $dots_under_label_color = (($is_rgb_capable) ? scale_rgb_fg($outline_color, 0.5) : $outline_color);

  $style_name //= 'rounded';
  my $tab_style_name = $style_name;

  # round the corners of the tabs if the style is compatible (i.e. single line):
  if (!($flags & TAB_STRAIGHT_TAB_EDGES)) {
    $tab_style_name = $style_name_to_tab_style_name{$style_name} // $style_name;
  }

  $style = lookup_style_by_name($style_name, 'rounded');

  my $tab_style = ($style_name eq $tab_style_name) ? $style : 
    lookup_style_by_name($tab_style_name, 'rounded');

  if (!($flags & TAB_STRAIGHT_TAB_EDGES)) {
    # make the tab itself like the single rounded style, 
    # but still join it to the bottom like smoothly:
    # (create a new array so we don't corrupt the template):
    $tab_style = [ @$tab_style ];
    @{$tab_style}[UPPER_LEFT, HORIZ, UPPER_RIGHT, VERT] = 
      @rounded_box_style[UPPER_LEFT, HORIZ, UPPER_RIGHT, VERT];
  }

  my $label_width = printed_length($label);

  my $tab_width = 2 + $label_width + 2;

  my $alignment_spaces = 
    ($alignment == ALIGN_LEFT) ? 2 :
    ($alignment == ALIGN_CENTER) ? (($width - $tab_width) / 2) :
    ($alignment == ALIGN_RIGHT) ? (($width - 2) - $tab_width) : 2;

  my $right_line_width = $width - ($alignment_spaces + $tab_width);

  my $out = '';

  my $horiz = $style->[HORIZ];
  my $top_horiz = $tab_style->[HORIZ];

  if (!$one_line_overlay_label) {
    # top of tab
    $out .= $prefix.X.$outline_color.
      (' ' x $alignment_spaces).$tab_style->[UPPER_LEFT].$top_horiz;
    
    $out .= ($top_horiz x $label_width);
    $out .= $top_horiz.$tab_style->[UPPER_RIGHT].X.NL;
    
    # tab sides and text
    $out .= $prefix.X.$outline_color.(' ' x $alignment_spaces).$tab_style->[VERT].X.' '.$label.X.
      $outline_color.' '.$tab_style->[VERT].X.NL;
  }

  # bottom of tab (and possibly top of following box)
  $out .= $prefix.X.$outline_color;

  if ($straight_bottom_edges) {
    $out .= ($horiz x $alignment_spaces);
  } else {
    $out .= $style->[UPPER_LEFT].($horiz x ($alignment_spaces - 1));
  }

  if ($one_line_overlay_label) {
    $out .= $horiz.X.' '.$label.X.' '.$outline_color.$horiz;
  } else {
    $out .= $tab_style->[LOWER_RIGHT].$dots_under_label_color.
      (dashed_horiz_bar_2_dashes x ($label_width + 2)).
        $outline_color.$tab_style->[LOWER_LEFT];
  }

  if ($straight_bottom_edges) {
    $out .= ($horiz x $right_line_width);
  } else {
    $out .= ($horiz x ($right_line_width - 1)).$style->[UPPER_RIGHT];
  }
  $out .= X.NL;

  return $out;
}

sub text_in_a_box($;$$$$$$$$) {
  my $input = shift;
  my ($align, $color, $style_alias, $divstyle_name, $left_space, $width, $right_space, $skip_sides_bitmap) = 
    named_or_ordered_args @_, qw(align color style divstyle left width right skip_sides);

  my $lines = (is_array_ref($input)) ? [ @$input ] : [ split($split_nl_re, $input) ];

  $align //= ALIGN_LEFT; # left aligned by default
  $orig_align = $align;  # alignment resets on each subsequent line
  my $pad_alignment_with = ' ';
  $color //= X;
  $style_alias //= 'single';
  $divstyle_name //= $style_alias;
  $skip_sides_bitmap //= 0;

  my $style = lookup_style_by_name($style_alias);
  my $style_name = $style->[STYLE_NAME];

  my $invisible_box = ($style_name eq 'none') ? 1 : 0;
  
  my $divstyle = lookup_div_style($style_name, $divstyle_name, $style);
  die if (!defined $divstyle);

  $left_space //= ($invisible_box ? '' : ' ');
  $right_space //= '';
  
  my $left_space_count = parse_integer($left_space);
  if (defined($left_space_count)) { $left_space = (' ' x $left_space_count); }

  my $has_tab = 0;
  my $tab_align = undef;
  my $tab_style = undef;
  my $tab_text = undef;
  my $tab_flat = 0;

  #
  # Do these preprocessing steps first since they may cause %{...} markups
  # to expand into actual characters (which affect the calculated box width),
  # specifically in the cases of control characters and %{sym=xxx} symbols:
  #
  foreach my $line (@$lines) {
    if ($line =~ /$folder_tab_re/oax) {
      $has_tab = 1;
      $tab_align = ALIGN_LEFT;
      my $align_type_name = $1;
      if (is_there($align_type_name)) {
        $tab_align = $aligntype_as_text_to_aligntype{lc($align_type_name)};
        if (!(defined $tab_align)) {
          show_warning_message('Invalid tab alignment "'.$align_type_name.'"; using left as default');
          $tab_align = ALIGN_LEFT;
        }
      }
      $tab_style = $2 // $style_name;

      if ($tab_style eq 'flat') {
        $tab_style = $style_name;
        $tab_flat = 1;
      }

      $tab_text = colorize_insert_symbols_and_interpolate_control_chars($3 // '');
      $line = undef; # don't include this line within the box
    } else {
      $line = colorize_insert_symbols_and_interpolate_control_chars($line);
    }
  }

  my $first_line = $lines->[0] // $lines->[1] // '';
  my $first_line_printed_length = printed_length($first_line);

  my $width_limit = get_terminal_width_in_columns() - 5;

  if ((!defined($width)) || ($width <= 0)) {
    $width = 0;
    foreach my $line (@$lines) {
      next if (!defined $line);
      my $n = printed_length($line =~ s/$remove_markup_re//roamsxg);
      set_min($n, $width_limit);
      if ($invisible_box) { $n = max($n - 4, 0); }
      set_max($width, $n);
      last if ($line =~ /$contains_endbox_re/oamsx);
    }
  }
  
  my $left_margin = $left_space.$color;
  my $right_margin = X.$right_space.X;

  my $out = '';
 
  my $orig_width = $width;

  if ($has_tab) {
    $width = min(max($width, 2 + printed_length($tab_text) + 2), $width_limit);
    $orig_width = $width;

    my $tab = 
      print_folder_tab($tab_text, $color, $tab_align, $width + 4, $tab_style, 
      TAB_IS_ATTACHED_TO_BOX | ($tab_flat ? TAB_ONE_LINE_OVERLAY_LABEL : 0), 
      $left_space, $right_space);
    $out .= $tab;
    $skip_sides_bitmap |= NO_BOX_TOP;
  }

  if (!$invisible_box) {
    $width = 2 + $width + 2;
    if (!($skip_sides_bitmap & NO_BOX_TOP)) {
      $out .= $left_margin.$color.$style->[UPPER_LEFT].($style->[HORIZ] x ($width-2)).$style->[UPPER_RIGHT].$right_margin.NL;
    }
  }

  my $linenum = 0;
  foreach my $linein (@$lines) {
    next if (!defined $linein);
    my $line = '';
    my $width_so_far = 0;
    $align = $orig_align;
    
    my $first_in_line = 1;
    my $accum_chunks_to_repeat = 0;
    my $chunks_to_repeat = '';
    
    local $REGMARK = undef;
    my $basepos = 0;
    
    my $left_side = ($invisible_box) ? '' : $style->[VERT].X.' ';
    my $right_side = ($invisible_box) ? '' : ' '.$color.$style->[VERT];
    
    my $chunks;
    if (is_array_ref($linein)) {
      $chunks = $linein;
    } else {
      # parse the %{...} tags and text spans comprising the line:
      #while ($linein =~ /$new_markup_or_text_re/oamsxg) { }
    }

    while ($linein =~ /$markup_or_text_re/oamsxg) {
      my ($op, $arg1, $arg2, $arg3, $arg4, $text) = ($1, $2, $3, $4, $5, $6);
      my $mark = $REGMARK // ''; $REGMARK = undef;
      my $chunk = '';
      $op //= ''; $arg1 //= ''; $arg2 //= ''; $arg3 //= ''; $arg4 //= ''; $text //= '';

      if ($mark eq 'TEXT') {
        $text =~ s{\\ \%}{%}oamsxg;

        if ($rest_is_filler_to_repeat) {
          my $remaining = max($orig_width - $width_so_far, 0);
          my $n = printed_length($text);
          my $reps = $remaining / $n;
          my $leftover = $remaining % $n;
          $chunk = ($text x $reps) . truncate_printed_string($text, $leftover);
        } else {
          if ($align == ALIGN_LEFT) {
            $chunk = $text;  # just a span of ordinary non-markup text
          } else {
            $chunk = padstring($text, max($orig_width - $width_so_far, 0), 
                               $align, $pad_alignment_with, 
                               (defined($pad_alignment_with) && 
                                  ($pad_alignment_with ne ' ')));
          }
        }
      } elsif ($mark eq 'COLUMN') {
        my $col = 
          ($arg1 eq '-') ? ($width_so_far - $arg2) :
          ($arg1 eq '+') ? ($width_so_far + $arg2) : $arg2;
        my $delta = $col - $width_so_far;
        if ($delta > 0) 
          { $chunk = ((if_there $arg3) // ' ') x $delta; }
      } elsif ($mark eq 'COLOR') {
        $chunk = replace_color_code($op);
      } elsif ($mark eq 'ALIGN') {
        # no output produced until the next non-markup token is processed:
        if ($op ne 'align') { $arg1 = $op; }
        $align = $aligntype_as_text_to_aligntype{lc($arg1)};
        if (!defined $align) {
          show_warning_message('Invalid alignment "'.$arg1.'"; ignored');
          $align = ALIGN_LEFT;
        } 
        $pad_alignment_with = (is_there($arg2) ? get_printable_symbol($arg2) : ' ');
      } elsif ($mark eq 'DIV') {
        if ($first_in_line) {
          if (is_there($arg1)) 
            { $divstyle = lookup_div_style($style_name, $arg1, $divstyle); }
          if ($invisible_box) {
            $chunk = $divstyle->[HORIZ] x $width;
          } else {
            my $horiz = ($divstyle->[HORIZ] // $style->[HORIZ]);
            $left_side = ($invisible_box) ? '' : 
              ($color. ($divstyle->[JOIN_LEFT] // $style->[JOIN_LEFT]) . $horiz);
            $chunk = $horiz x $orig_width;
            $right_side = ($invisible_box) ? '' : 
              ($color . $horiz . ($divstyle->[JOIN_RIGHT] // 
                                    $style->[JOIN_RIGHT]));
          }
        } else {
          show_warning_message('%{div} must be first and only markup tag in a line (%{div} ignored)');
          $chunk = '';
        }
      } elsif ($mark eq 'TAB') {
        # This should never happen since we pre-process tabs at the start
      } elsif ($mark eq 'SYM') {
        die('%{sym=...} in input should already have been expanded');
      } elsif ($mark eq 'RGB') {
        $chunk = fg_bg_and_rgb_hex_or_list_to_codes($op, $arg1, $arg2, $arg3, $arg4);
      } elsif ($mark eq 'REP' || $mark eq 'ENDREP') {
        if (is_there($arg1)) {
          # %{rep=123} or %{endrep=123} means take the accumulated chunk and repeat it e.g. 123 times:
          # (between the %{rep}...and...%{endrep=123} we already printed the first repetition):
          $chunk = $chunks_to_repeat x (max($arg1-1, 0));
          $accum_chunks_to_repeat = 0;
          $chunks_to_repeat = '';
        } else {
          # %{rep} without arg means start accumulating text chunks to repeat:
          $accum_chunks_to_repeat = 1;
        }
      } elsif ($mark eq 'FILL') {
        # fill the remainder of the right portion of the line with 
        # repeats of the text following the %{fill} markup:
        $rest_is_filler_to_repeat = 1;
      } elsif ($mark eq 'TITLE') {
        # nothing is written to output itself - this is done on /dev/pts/*)
        set_console_title($arg1);
      } elsif ($mark eq 'SUBTITLE') {
        set_console_subtitle($arg1);
      } elsif ($mark eq 'CLEAR') {
        $chunk = CLEAR_SCREEN;
      } elsif ($mark eq 'ENDBOX') {
        if (!$invisible_box) {
          $chunk = $color.$style->[LOWER_LEFT].($style->[HORIZ_BOTTOM] x ($width-2)).$style->[LOWER_RIGHT];
          $width = $orig_width;
          $invisible_box = 1;
        }
      } elsif ($mark eq 'ESC') {
        $chunk = ESC.$arg1;
      } else {
        die($Y.$U.'text_in_a_box:'.$UX.$R.' unknown markup on line '.
              $B.$linenum.$R.' column '.$B.$basepos.$R.' (mark was '.
              format_quoted($mark).$R.'): '.
              format_chunk(substr($linein, $basepos), 32).$R);
      }

      $width_so_far += printed_length($chunk);
      $line .= $chunk;
      if ($accum_chunks_to_repeat) { $chunks_to_repeat .= $chunk; }
      $basepos = pos($linein);
      $first_in_line = 0;
    }

    if ($width_so_far < $orig_width) {
      $line .= (' ' x ($orig_width - $width_so_far));
      $width_so_far = $orig_width;
    }

    $line .= X;
    $out .= $left_margin.$left_side.$line.$right_side.X.$right_margin.NL;
    $linenum++;
  }
  
  if (!$invisible_box) {
    if (!($skip_sides_bitmap & NO_BOX_BOTTOM)) {
      $out .= $left_margin.$color.$style->[LOWER_LEFT].
        ($style->[HORIZ_BOTTOM] x ($width-2)).
          $style->[LOWER_RIGHT].$right_margin.NL;
    }
  }
  
  return $out;
}

sub print_banner($$;$$) {
  my $title = C.$_[0];
  my $description = Y.$_[1];
  my $boxcolor = $_[2] // B;

  my $message =
    $boxcolor.arrow_head.'  '.$title.$boxcolor.' '.dot_small.' '.$description.X.NL.
    '%{div}'.NL.
    X.'Copyright '.copyright_symbol.' 2015 '.Y.'Matt T. Yourst '.X.'<yourst@yourst.com>'.X.NL.
    K.'This program is free software licensed under GPLv2'.NL.
    ($_[3] // '');

  return text_in_a_box($message, -1, $boxcolor, 'heavy', 'single'); 
}

1;
