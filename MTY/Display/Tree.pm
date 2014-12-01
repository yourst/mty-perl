#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Display::Tree
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#
# Print or format hierarchical tree using colors and box drawing characters,
# similar to the style used by MTY::Display::TextInABox. The tree data 
# structure is specified as a recursive set of arrays of references, where
# each array contains:
#
# - [0] = label text to print for this node, as either:
#         - a scalar text string
#         - a reference to an array of text strings intermixed with optional
#           control commands, which are concatenated without separators between
#            them to print the name
#         
#         If an array is used to provide multiple chunks comprising the label,
#         any of the label array elements may contain control commands, either
#         in the preferred form of a reference to another array of the form
#         [ command, arg1, arg2, ... ] (where command is one of the TREE_CMD_xxx
#         constants), or in the equivalent text form "%{command=arg1,...}.
#
#         The [ TREE_CMD_COLUMN, N ] (or "%{column=N}") directive causes the
#         tree printer to continue printing the next chunk after the directive
#         at column N, relative to the leftmost tree branch.
#
#         Specifically, %{column=N} will skip to the same column N regardless
#         of how deeply the tree may be indented at that point, so the output
#         remains properly lined up whether the tree is only one level deep
#         or a hundred levels deep. (In practice, if a given node is already
#         so far indented that its label starts after the column number N
#         specified by %{column=N}, the column directive will be ignored.
#
#         A label array element may also be a special [ TREE_CMD_SYMBOL, X, Y ]
#         or '%{symbol=X,Y}' directive, which overrides that node's default 
#         character symbol (typically a solid right facing triangle for a node 
#         with subnodes, or an empty triangle for a leaf node). The X and Y 
#         parameters may each specify either one (or several) literal characters, 
#         a hex numbered Unicode character code (using e.g. 0xABCD), or a symbol
#         name chosen from amongst the library provided by the PrintableSymbols
#         package. The Y parameter (which specifies the leaf node symbol) is
#         optional; by default both branch and leaf nodes use the same symbol.
#         The %{symbol=X,Y} directive can only be in the same label array 
#         element as one or more color or formatting markups (e.g. %R/%U/%!U);
#         no literal text is allowed (it must be put in a subsequent element).
#
#         If any label array entries end with newlines, subsequent lines of the
#         label will be properly indented to line up with the first line. For
#         multi-line labels, the array format is mandatory, and each line must
#         be in its own array element, terminated by a newline.
#
# - [1, 2, ...] = subnodes (optional) = references to sub-node arrays, in the
#         same format as described herein (with the first element as the label
#         or array of label chunks and/or directives, and the remaining elements
#         containing recursive references to sub-branches.
#

package MTY::Display::Tree;

use integer; use warnings; use Exporter::Lite;

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($split_leading_spaces_from_text_re $tree_branch_color
     $tree_branch_to_leaf_style $tree_branch_to_node_style
     $tree_branch_to_root_style $tree_horiz_dashed $tree_leading_space
     $tree_leaf_indicator $tree_leaf_indicator_color $tree_node_indicator
     $tree_node_indicator_color $tree_pre_branch_color
     $tree_pre_branch_spacer $tree_root_symbol_and_color
     $tree_subnode_count_if_no_subnodes $tree_subnode_count_prefix
     $tree_subnode_count_suffix $tree_vert_dashed %tree_command_name_to_id
     %tree_styles BRANCH DEPENDENCY_GRAPH_TO_TREE_NO_RECURSION
     DEPENDENCY_GRAPH_TO_TREE_REPRINT_VISIBLE_BRANCHES
     DEPENDENCY_GRAPH_TO_TREE_SHOW_DEPENDENCY_COUNT HORIZ_DASHED HORIZ_LINE
     LAST_BRANCH NO_BRANCH NO_BRANCH_DASHED TREE_CMD_BRANCH_COLOR
     TREE_CMD_BRANCH_DASHED TREE_CMD_BRANCH_STYLE TREE_CMD_COLUMN
     TREE_CMD_DIV TREE_CMD_FIELD TREE_CMD_IF_EVEN TREE_CMD_IF_ODD
     TREE_CMD_LABEL TREE_CMD_PREFIX TREE_CMD_SUBNODE_COUNT TREE_CMD_SYMBOL
     create_histogram_of_used_levels create_level_skip_map
     delimited_paths_to_tree_of_hashes dependency_graph_to_tree
     dependency_graph_to_tree_recursive indented_text_to_tree
     labels_and_levels_to_tree print_tree
     split_text_into_arrays_of_lines_and_indents subtree_label
     subtree_to_text tree_of_hashes_to_printable_tree tree_to_lines
     tree_to_text);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::ANSIColorREs;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::Blocks;
use MTY::RegExp::Numeric;
use MTY::RegExp::Strings;
use Data::Printer;

#
# Defaults:
#
our $tree_branch_to_root_style;
our $tree_branch_to_node_style;
our $tree_branch_to_leaf_style;
our $tree_branch_color;
our $tree_node_indicator_color;
our $tree_node_indicator;
our $tree_leaf_indicator_color;
our $tree_leaf_indicator;
our $tree_horiz_dashed;
our $tree_vert_dashed;
our $tree_leading_space;
our $tree_pre_branch_spacer;
our $tree_pre_branch_color;
our $tree_subnode_count_prefix;
our $tree_subnode_count_suffix;
our $tree_subnode_count_if_no_subnodes;
our $tree_root_symbol_and_color;

my $use_rgb_color;

INIT {
  $use_rgb_color = (is_console_color_capable() >= ENHANCED_RGB_COLOR_CAPABLE) ? 1 : 0;
  my $darkK = ($use_rgb_color) ? fg_color_rgb(96, 96, 96) : $K;

  $tree_branch_to_root_style = 'rounded';
  $tree_branch_to_node_style = 'rounded';
  $tree_branch_to_leaf_style = 'rounded';
  $tree_branch_color         = ($use_rgb_color) ? fg_color_rgb(128, 64, 192) : $B;
  $tree_node_indicator_color = ($use_rgb_color) ? fg_color_rgb(172, 86, 255) : $C;
  $tree_leaf_indicator_color = $tree_branch_color;
  $tree_node_indicator       = $tree_node_indicator_color.arrow_tri;
  $tree_leaf_indicator       = $tree_leaf_indicator_color.arrow_open_tri;
  $tree_horiz_dashed         = 0;
  $tree_vert_dashed          = 0;
  $tree_leading_space        = ' ';
  $tree_pre_branch_spacer    = ' ';
  $tree_pre_branch_color      = $X;
  $tree_subnode_count_prefix = $darkK.' (#'.$R;
  $tree_subnode_count_suffix = $darkK.')'.$X;
  $tree_subnode_count_if_no_subnodes = '';
  $tree_root_symbol_and_color = $tree_node_indicator_color.square_root_symbol.' ';
};

#
# Tree Styles
#

noexport:; use constant {
  BRANCH                   => 0, # e.g.  |-
  LAST_BRANCH              => 1, # e.g.  L_
  NO_BRANCH                => 2, # e.g.  |
  NO_BRANCH_DASHED         => 3, # e.g.  |
  HORIZ_LINE               => 4, # e.g.  -
  HORIZ_DASHED             => 5, # e.g.  --
};

# Don't print any branch lines for the top level root node:

my @no_tree_style = (' ', ' ', ' ', ' ', ' ', ' ');

my @single_tree_style  = (chr(0x251c), chr(0x2514), chr(0x2502), chr(0x2506), chr(0x2500), chr(0x254c));
my @double_tree_style  = (chr(0x2560), chr(0x255a), chr(0x2551), chr(0x2551), chr(0x2550), chr(0x2550));
my @rounded_tree_style = (chr(0x251c), chr(0x2570), chr(0x2502), chr(0x2506), chr(0x2500), chr(0x254c));
my @thick_tree_style   = (chr(0x2523), chr(0x2517), chr(0x2503), chr(0x2507), chr(0x2501), chr(0x254d));

my @single_vert_double_horiz_tree_style  = (chr(0x255e), chr(0x2558), chr(0x2502), chr(0x2506), chr(0x2550), chr(0x2550));
my @single_vert_thick_horiz_tree_style   = (chr(0x255e), chr(0x2558), chr(0x2502), chr(0x2506), chr(0x2501), chr(0x254d));
my @double_vert_single_horiz_tree_style  = (chr(0x255f), chr(0x2559), chr(0x2551), chr(0x2551), chr(0x2550), chr(0x2550));
my @thick_vert_single_horiz_tree_style   = (chr(0x2520), chr(0x2516), chr(0x2503), chr(0x2507), chr(0x2500), chr(0x254c));

my @tree_root_style = @thick_tree_style;

our %tree_styles = (
  'none'            => \@no_tree_style,
  'single'          => \@single_tree_style,
  'double'          => \@double_tree_style,
  'rounded'         => \@rounded_tree_style,
  'thick'           => \@thick_tree_style,

  'none,none'       => \@no_tree_style,

  'single,single'   => \@single_tree_style,
  'single,double'   => \@single_vert_double_horiz_tree_style,
  'single,thick'    => \@single_vert_thick_horiz_tree_style,

  'double,double'   => \@double_tree_style,
  'double,single'   => \@double_vert_single_horiz_tree_style,

  'thick,thick'     => \@thick_tree_style,
  'thick,single'    => \@thick_vert_single_horiz_tree_style,
);

my $tree_label_markup_re = 
  qr{(?|
       (?>
         \% \{ 
         ([^\=\}]++) 
         (?> \= ($inside_of_braces_re))?
         \} 
       ) | 
       (?>
         (\t) ()
       )
     )}oax;

use constant {
  TREE_CMD_LABEL              => 0,
  TREE_CMD_COLUMN             => 1,
  TREE_CMD_FIELD              => 2,
  TREE_CMD_SUBNODE_COUNT      => 3,
  TREE_CMD_PREFIX             => 4,
  TREE_CMD_IF_EVEN            => 5,
  TREE_CMD_IF_ODD             => 6,
  TREE_CMD_SYMBOL             => 7,
  TREE_CMD_BRANCH_COLOR       => 8,
  TREE_CMD_BRANCH_STYLE       => 9,
  TREE_CMD_BRANCH_DASHED      => 10,
  TREE_CMD_DIV                => 11,
};

our %tree_command_name_to_id = (
  'label'                     => TREE_CMD_LABEL,
  'column'                    => TREE_CMD_COLUMN,
  'field'                     => TREE_CMD_FIELD,
    "\t"                      => TREE_CMD_FIELD,
    "\f"                      => TREE_CMD_FIELD,
  'subnodes'                  => TREE_CMD_SUBNODE_COUNT,
  'prefix'                    => TREE_CMD_PREFIX,
  'prefix_if_even'            => TREE_CMD_PREFIX_IF_EVEN,
  'prefix_if_odd'             => TREE_CMD_PREFIX_IF_ODD,
  'if_even'                   => TREE_CMD_IF_EVEN,
  'if_odd'                    => TREE_CMD_IF_ODD,
  'symbol'                    => TREE_CMD_SYMBOL,
  'branch_color'              => TREE_CMD_BRANCH_COLOR,
  'branch_style'              => TREE_CMD_BRANCH_STYLE,
  'branch_dashed'             => TREE_CMD_BRANCH_DASHED,
  'div'                       => TREE_CMD_DIV,
);

noexport:; sub subtree_label {
  my ($chunks, $node, $leading_space,
      $branch_to_node_style, $branch_to_leaf_style,
      $branch_color, $node_indicator, $leaf_indicator,
      $horiz_dashed, $vert_dashed, $output_line_number) = @_;
  
  my $subnode_count = (is_array_ref($node)) ? scalar(@$node)-1 : 0;

  my $is_even_line = ($output_line_number % 2) == 0;

  $leading_space //= '';

  my $per_line_header = '';

  my $field_id = 0;
  my @fields = ( '' );

  if (!is_array_ref($chunks)) {
    $chunks = [ split($tree_label_markup_re, $chunks) ];
  } else {
    # Even with an array, any literal chunks could still contain
    # %{tree_cmd=...} or \t (tab to next field), so also split 
    # any array elements that are scalars containing these:
    $chunks = [ map { (is_array_ref($_)) ? $_ : (split($tree_label_markup_re, $_)) } @$chunks ];
  }

  foreach my $chunk (@$chunks) {
    my $cmd; my $arg; my @args = ( );
    next if (!defined $chunk); # undef chunks are no-ops: just skip them
    
    if (is_array_ref($chunk)) {
      @args = @$chunk;
      $cmd = shift @args;
      $arg = $args[0] // '';
    } elsif ($chunk =~ /$tree_label_markup_re/oax) {
      ($cmd, $arg) = ($tree_command_name_to_id{$1}, $2 // '');
      @args = split(/,/, $arg);
      if (!defined $cmd) {
        die('Invalid tree formatting command "'.$1.'" with arguments ['.
              join(', ', @args).']');
      }
    } else {
      $cmd = TREE_CMD_LABEL;
      $arg = $chunk;
    }

    # Second argument matches first argument by default for all of these:
    $args[1] = is_there($args[1]) ? $args[1] : $args[0];

    my $added = undef;
    my $added_to_prefix = undef;

    if ($cmd == TREE_CMD_LABEL) {
      $added = $arg;
    } elsif ($cmd == TREE_CMD_SUBNODE_COUNT) {
      my $before = is_there($args[1]) // $tree_subnode_count_prefix;
      my $after = is_there($args[2]) // $tree_subnode_count_suffix;
      my $if_no_subnodes = is_there($args[3]) // 
        $tree_subnode_count_if_no_subnodes;
      $added = ($subnode_count > 0) ? $before.$subnode_count.$after : $if_no_subnodes;
    } elsif ($cmd == TREE_CMD_FIELD) {
      if (is_there($arg)) {
        $field_id = $arg;
      } else {
        # add a new field at the end
        $field_id++;
      }
    } elsif ($cmd == TREE_CMD_PREFIX) {
      $added_to_prefix = ((scalar @args) > 1) ? 
        $args[$is_even_line ? 0 : 1] : $args[0];
    } elsif ($cmd == TREE_CMD_SYMBOL) {
      $$node_indicator = $args[0] // $$node_indicator;
      $$leaf_indicator = $args[1] // $$node_indicator;
    } elsif ($cmd == TREE_CMD_BRANCH_COLOR) {
      $$branch_color = $arg;
    } elsif ($cmd == TREE_CMD_BRANCH_STYLE) {
      my ($br_to_node, $br_to_leaf) = @args;
      if (!exists $tree_styles{$br_to_node}) { warn('Style "'.$br_to_node." (for branch to node) is invalid"); }
      $$branch_to_node_style = $tree_styles{$br_to_node};
      if (!exists $tree_styles{$br_to_leaf}) { warn('Style "'.$br_to_leaf." (for branch to leaf) is invalid"); }
      $$branch_to_leaf_style = $tree_styles{$br_to_leaf};
    } elsif ($cmd == TREE_CMD_BRANCH_DASHED) {
      ($$vert_dashed, $$horiz_dashed) = @args;
    } elsif ($cmd == TREE_CMD_DIV) {
      $args[0] //= dashed_horiz_bar_2_dashes;
      $args[1] //= $$branch_color;
      $added = $args[1].($args[0] x 80);
    } elsif ($cmd == TREE_CMD_IF_EVEN) {
      $added = $arg if ($is_even_line);
    } elsif ($cmd == TREE_CMD_IF_ODD) {
      $added = $arg unless ($is_even_line);
    } else {
      die('Invalid formatting command #'.$cmd.
            ' with arguments ['.join(', ', @args).']');
    }

    if (defined $added) {
      $fields[$field_id] //= '';
      $fields[$field_id] .= $added;
    } elsif (defined $added_to_prefix) {
      $per_line_header .= $added_to_prefix;
    }
  }

  $per_line_header .= $leading_space;

  return ($per_line_header, \@fields);
}

noexport:; sub subtree_to_text {
  my ($nodelist, $out, $level, $prefix, 
      $branch_to_node_style, $branch_to_leaf_style, 
      $branch_to_root_style, $branch_color, 
      $parent_branch_color, $node_indicator, 
      $leaf_indicator, $horiz_dashed, $vert_dashed) = @_;

  $prefix //= '';

  my $nodecount = 0;
  
  my @empty_array = ( );

  my $node_count = scalar(@$nodelist);

  my $this_node_sym = $node_indicator // $tree_indicator;
  my $this_leaf_sym = $leaf_indicator // $leaf_indicator;

  if ($level == 0) {
    # we need to print the header line for the top-level root node:
    my $root_node_prefix = $tree_root_symbol_and_color;

    my ($per_line_header, $fields) = subtree_label(
      ($nodelist->[0] // $C.'root'.$X),
      $node, $tree_leading_space,
      \$branch_to_node_style, \$branch_to_leaf_style,
      \$branch_color, \$this_node_sym, \$this_leaf_sym,
      \$horiz_dashed, \$vert_dashed, scalar(@$out));

    $fields->[0] = $per_line_header . $root_node_prefix . ($fields->[0] // '');
    push @$out, $fields;
  }

  # $nodelist->[0] is this node's text to print (already printed by the 
  # calling subtree_to_text()), so we start with index 1 here:

  for (my $i = 1; $i < $node_count; $i++) {
    my $node = $nodelist->[$i];
    my $is_last_node = ($i == ($node_count-1));
    my $is_array_node = is_array_ref($node);
    
    my $chunks = (((defined $node) && $is_array_node) ? $node->[0] : $node) // '';
    
    my $subnode_count = ($is_array_node ? scalar(@$node)-1 : 0);
    
    my ($per_line_header, $fields) = subtree_label(
      $chunks, $subnode, $tree_leading_space,
      \$branch_to_node_style, \$branch_to_leaf_style,
      \$branch_color, \$node_indicator, \$leaf_indicator,
      \$horiz_dashed, \$vert_dashed, scalar(@$out));

    my $style_set = 
      (($level == 0) 
        ? $branch_to_root_style
        : (($subnode_count > 0) ? $branch_to_node_style : $branch_to_leaf_style));
    
    my $style =
      (($is_last_node)
        ? LAST_BRANCH
        : ((is_there($node))
            ? BRANCH
            : ($vert_dashed ? NO_BRANCH_DASHED : NO_BRANCH)));
        
    my $horiz_style =
      ((is_there($node)) ? HORIZ_LINE : HORIZ_DASHED);

    die if (!defined $parent_branch_color);
    die if (!defined $branch_color);
    die if (!defined $tree_pre_branch_color);
    die if (!defined $style_set->[NO_BRANCH]);

    my $subnode_prefix = 
      $parent_branch_color.$prefix.$branch_color.(($is_last_node) ? $tree_pre_branch_spacer.$tree_pre_branch_spacer : ($style_set->[NO_BRANCH].' '));

    my $indicator = 
      (($subnode_count > 0)
        ? $node_indicator
        : (is_there($node) ? $leaf_indicator : $empty_indicator));

    my $branch_symbols .= $parent_branch_color.$prefix.
      $branch_color.$style_set->[$style].$style_set->[$horiz_style].
      $indicator.' '.(($subnode_count > 0) ? $G : $X);

    #
    # Prepend the branch symbols to the start of the first field,
    # rather than giving them their own field, since we want the
    # first field's label to appear immediately after the branches.
    #
    # (If this was aligned to the next field boundary, nodes closer
    # to the root would have a huge gap between the branch and its
    # label, which would look visually confusing).
    #
    $fields->[0] = $per_line_header . $branch_symbols . ($fields->[0] // '');

    push @$out, $fields;

    if ($subnode_count > 0) {
      subtree_to_text($node, $out, $level + 1, $subnode_prefix,
        $branch_to_node_style, $branch_to_leaf_style, $branch_to_root_style,
        $branch_color, $parent_branch_color, $node_indicator, $leaf_indicator, 
        $horiz_dashed, $vert_dashed);
    }
  }

  return $out;
}

noexport:; sub tree_to_lines {
  my $nodelist             = $_[0];
  my $branch_to_node_style = $_[1] // $tree_branch_to_node_style;
  my $branch_to_leaf_style = $_[2] // $tree_branch_to_leaf_style;
  my $branch_to_root_style = $_[3] // $tree_branch_to_root_style;
  my $branch_color         = $_[4] // $tree_branch_color;
  my $node_indicator       = $_[5] // $tree_node_indicator;
  my $leaf_indicator       = $_[6] // $tree_leaf_indicator;
  my $horiz_dashed         = $_[7] // $tree_horiz_dashed;
  my $vert_dashed          = $_[8] // $tree_vert_dashed;

  if (!(exists $tree_styles{$branch_to_node_style}))
    { die('Undefined tree branch style "'.$branch_to_node_style.'"'); }

  $branch_to_node_style = $tree_styles{$branch_to_node_style};

  if (!(exists $tree_styles{$branch_to_leaf_style}))
    { die('Undefined tree branch style "'.$branch_to_leaf_style.'"'); }

  $branch_to_leaf_style = $tree_styles{$branch_to_leaf_style};

  if (!(exists $tree_styles{$branch_to_root_style}))
    { die('Undefined tree branch style "'.$branch_to_root_style.'"'); }

  $branch_to_root_style = $tree_styles{$branch_to_root_style};
  
  my $parent_branch_color = $branch_color;

  if ((is_console_color_capable() >= ENHANCED_RGB_COLOR_CAPABLE)) {
    $parent_branch_color = fg_color_rgb(scale_rgb($branch_color, 0.5));
  }

  my $rows_and_columns = [ ];

  subtree_to_text($nodelist, $rows_and_columns, 0, '',
    $branch_to_node_style, $branch_to_leaf_style, $branch_to_root_style,
    $branch_color, $parent_branch_color, $node_indicator, $leaf_indicator,
    $horiz_dashed, $vert_dashed);

  my @out = format_columns($rows_and_columns, ' ', '', NL, ALIGN_LEFT);

  return (wantarray ? @out : \@out);
}

sub print_tree($;$$$$$$$$$) {
  my ($node, $fd) = @_;

  $fd //= STDOUT;
  my $out_lines = tree_to_lines($node, @_[2..((scalar @_)-1)]);
  foreach $line (@$out_lines) { print($fd $line); }
  return $out_lines;
}

sub tree_to_text {
  return join('', @{tree_to_lines(@_)});
}

sub indented_text_to_tree($) {
  my ($text) = @_;

  my ($line_list, $indent_list) = split_text_into_arrays_of_lines_and_indents($text);
  return labels_and_levels_to_tree($line_list, $indent_list);
}

use constant {
  DEPENDENCY_GRAPH_TO_TREE_REPRINT_VISIBLE_BRANCHES => (1 << 0),
  DEPENDENCY_GRAPH_TO_TREE_SHOW_DEPENDENCY_COUNT    => (1 << 1),
  DEPENDENCY_GRAPH_TO_TREE_NO_RECURSION             => (1 << 2),
};

noexport:; sub dependency_graph_to_tree_recursive { # prototype ($+;+$+$)
  my ($from, $key_to_deplist, $key_to_label, $options, $visited, $origin) = @_;

  my $reprint_visited_branches = 
    ($options & DEPENDENCY_GRAPH_TO_TREE_REPRINT_VISIBLE_BRANCHES) != 0;
  my $show_dep_counts = 
    ($options & DEPENDENCY_GRAPH_TO_TREE_SHOW_DEPENDENCY_COUNT) != 0;

  my $no_recursion = 
    ((($options & DEPENDENCY_GRAPH_TO_TREE_NO_RECURSION) != 0) && ($from ne $origin)) ? 1 : 0;

  my $deps = $key_to_deplist->{$from};
  my @one_elem_array = ( $deps );
  $deps = (defined $deps) ? ((ref $deps) ? $deps : \@one_elem_array) : \@empty_array;

  my $n = scalar(@$deps);

  my $already_visited = (exists $visited{$from});
  my $label = $key_to_label->{$from} // $from;
  my $info = [ ($already_visited ? $Y : $G), $label, ' '.$X ];

  if ($already_visited && ($n > 0)) {
    push @$info, (
      [ TREE_CMD_SYMBOL, $G.checkmark ],
      $B.' (already examined) ');
  } else {
    push @$info, [ TREE_CMD_SYMBOL, $B.arrow_tri, $B.arrow_open_tri ],
  }

  if (($n > 0) && $show_dep_counts) 
    { push @$info, $K.' ('.$C.$n.$B.' deps'.$K.')'.$X; }

  my $node = [ $info ];

  $visited{$from} = $node;
  if ($already_visited && (!$reprint_visited_branches)) { return $node; }
  if ($no_recursion) { return $node; }

  foreach $dep (@$deps) {
    next if (!defined $dep);

    my $label = $key_to_label->{$dep} // $dep;

    if ($dep eq $origin) {
      push @$node, [[
        [ TREE_CMD_SYMBOL, R.x_symbol ],
        M.$label.'  '.X.R.U.'(circular dependency)'.X
      ]];
    } else {
      push @$node, dependency_graph_to_tree_recursive
        ($dep, $key_to_deplist, $key_to_label, $options, $visited, $origin);
    }
  }

  return $node;
}

sub dependency_graph_to_tree($+;+$+$) {
  my ($from, $key_to_deplist, $key_to_label, $options, $visited, $origin) = @_;

  $options //= 0;
  $key_to_label //= { };
  $visited //= { };
  $origin //= $from;
  
  return dependency_graph_to_tree_recursive($from, $key_to_deplist, $key_to_label, $options, $visited, $origin);
}

#
# Convert a pair of equal length arrays into a tree,
# where a given entry in the first array contains a
# scalar text string for the node's label, and the
# corresponding entry (at the same index) in the
# second array specifies that node's absolute depth,
# where 0 is the root, and all depths in the array 
# except for the first (root) entry must be >= 1.
#
our $split_leading_spaces_from_text_re = 
  compile_regexp(qr{^ ([\ \t]*+) ([^\n]*+) (?> \n | \Z)}oamsx, 
                 'split_leading_spaces_from_text');

noexport:; sub create_histogram_of_used_levels($$) {
  my ($levels, $n) = @_;

  my @levels_used = ( );

  for (my $i = 0; $i < $n; $i++) {
    my $level = $levels->[$i];
    $levels_used[$level] = (defined $levels_used[$level]) ? ($levels_used[$level] + 1) : 1;
  }
  return \@levels_used;
}

noexport:; sub create_level_skip_map($) {
  my ($levels_used) = @_;

  my $n = scalar @$levels_used;

  my @skip_map = ( );
  prealloc(\@skip_map, scalar(@$levels_used));

  my $valid_levels = 0;

  for (my $i = 0; $i < $n; $i++) {
    if ($levels_used->[$i]) { $skip_map[$i] = $valid_levels++; }
    die if (!$levels_used);
  }

  return \@skip_map;
}

sub split_text_into_arrays_of_lines_and_indents {
  my ($text) = @_;

  my $linenum = 0;

  my $lines = (is_array_ref($text)) ? $text : [ split(/\n/oamsx, $text) ];

  my $linecount = scalar @$lines;
  if (!$linecount) { return ([ ], [ ]); }

  my @indents = ( );
  prealloc(\@indents, $linecount);
  
  my @indent_levels_used = ( );
  
  for (my $linenum = 0; $linenum < $linecount; $linenum++) {
    my $line = $lines->[$linenum];
    next if (!defined $line);
    my $spaces;
    ($spaces, $line) = ($line =~ /$split_leading_spaces_from_text_re/oamsx);
    my $indent_level = length($spaces);

    $indent_levels_used[$indent_level] = 
      (defined $indent_levels_used[$indent_level]) ? 
        ($indent_levels_used[$indent_level] + 1) : 1;

    $lines->[$linenum] = $line;
    $indents[$linenum] = $indent_level;
  }

  #
  # Add two special refernece entries to the end of the indents array:
  #
  # = the skip list, which maps potentially sparse input indent sizes
  #   onto a contiguous monotonically increasing set of indents
  #
  # - the histogram, which counts the number of occurrences of each
  #   input indent level.
  #
  $indents[$linecount+0] = \@indent_levels_used;
  $indents[$linecount+1] = create_level_skip_map(\@indent_levels_used);

  return ($lines, \@indents);
}

sub labels_and_levels_to_tree($;$) {
  my ($labels, $levels) = @_;

  my $n = scalar @$labels;

  if (!defined $levels) {
    ($labels, $levels) = split_text_into_arrays_of_lines_and_indents($labels);
  }

  my $used_levels = $levels->[$n+0];
  my $skip_map = $levels->[$n+1];

  if (!defined $used_levels) 
    { $used_levels = create_histogram_of_used_levels($levels, $n); }

  if (!defined $skip_map)
    { $skip_map = create_level_skip_map($used_levels); }

  my $rootnode = [ [ '(root) ' ] ];

  my @node_at_level = ( );

  for (my $i = 0; $i < $n; $i++) {
    my $label = $labels->[$i];
    my $level = $levels->[$i];
    next if (!defined $label);
    die if (!defined $level);
    $level = $skip_map->[$levels->[$i]];
    die if (!defined $level);

    my $node = [ $label ];
    my $parent = ($level > 0) ? $node_at_level[$level-1] : $rootnode;
    $node_at_level[$level] = $node;    
    push @$parent, $node;
  }

  return $rootnode;
}

sub delimited_paths_to_tree_of_hashes(+;$+) {
  my ($pathlist, $delimiter, $path_to_metadata) = @_;
  $delimiter //= '/';

  $delimiter = quotemeta($delimiter);
  my $splitter_re = qr{$delimiter}oa;

  my $root = { };

  foreach my $path (@$pathlist) {
    my @chunks = split(/$splitter_re/, $path);

    my $node = $root;

    foreach my $chunk (@chunks) {
      next if (!length $chunk);

      if (exists $node->{$chunk}) {
        $node = $node->{$chunk};
      } else {
        my $subnode = { };
        $node->{$chunk} = $subnode;
        $node = $subnode;
      }
    }

    my $metadata = $path_to_metadata->{$path};

    if (defined $metadata) { $node->{''} = $metadata; }
  }

  return $root;
}

sub tree_of_hashes_to_printable_tree {
  my ($hash_root, $name, $metadata, $parent) = @_;

  my $label = $metadata // $name;

  my $tree_node = [
    [ 
      [ TREE_CMD_SYMBOL, ((defined $metadata) ? arrow_tri : arrow_open_tri) ],
      $label,
    ],
  ];

  while (my ($subnode_name, $subnode) = each %$hash_root) {
    next if (!length $subnode_name);
    my $metadata = $subnode->{''};
    push @$tree_node, tree_of_hashes_to_printable_tree($subnode, $subnode_name, $metadata, $tree_node);
  }

  return $tree_node;
}

1;