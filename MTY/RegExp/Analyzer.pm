#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::Analyzer
#
# Regular Expression Analysis, Formatting and Optimization
#
# Copyright 2005 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::RegExp::Analyzer;

use integer; use warnings; use Exporter::Lite;

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($show_colorized_compiled_regexps $show_pretty_compiled_regexps
     $use_enhanced_regexp_unicode_symbols beautify_regexp_token
     convert_perl_regexp_to_boost_xpressive_regexp describe_regexp_metadata
     format_metadata_line format_regexp_parse_tree_node list_compiled_regexps
     regexp_parse_subtree_to_printable_subtree
     regexp_parse_tree_to_printable_tree short_list_compiled_regexps
     show_compiled_regexp show_compiled_regexps show_raw_compiled_regexps
     simple_format_tokenized_regexp);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
use MTY::RegExp::FilesAndPaths;
use MTY::RegExp::PerlRegExpParser;
use MTY::RegExp::PerlSyntax;
use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;
use MTY::Display::Tree;
use re qw(regexp_pattern is_regexp regmust regname regnames regnames_count);

use Text::Format;

use Data::Dumper;

use Data::Printer {
  indent => 2,
  hash_separator => '=>',
  colored => 0,
  index => 0,
  multiline => 1,
  print_escapes => 1,
};

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

our $show_colorized_compiled_regexps = 0;
our $show_pretty_compiled_regexps = 0;
our $use_enhanced_regexp_unicode_symbols = 0;

my $MID_GRAY = fg_color_rgb(192, 192, 192);

my %token_type_to_formatting = (
  RE_TOKEN_ESCAPED_CHAR_CLASS, $Y.$U,
  RE_TOKEN_SPACE_CHAR_CLASS  , $MID_GRAY,
  RE_TOKEN_BRACKETED_CHAR_SET, $M,
  RE_TOKEN_LITERAL         , $G,
  RE_TOKEN_LITERAL_NUMERIC , $R,
  RE_TOKEN_LITERAL_STRING  , $C,
  RE_TOKEN_ANY_CHAR        , $Y.$U,
  RE_TOKEN_QUANTIFIER      , $C,
  RE_TOKEN_ANCHOR          , $M.$U,
  RE_TOKEN_BACKREF         , $R.$U,
  RE_TOKEN_CASE_MOD        , $R,
  RE_TOKEN_CAP_GROUP_START , $C,
  RE_TOKEN_EXT_GROUP_START , $B,
  RE_TOKEN_GROUP_END       , $C,
  RE_TOKEN_OR              , $R,
  RE_TOKEN_WHITESPACE      , $K,
  RE_TOKEN_COMMENT         , $K,
  RE_TOKEN_UNKNOWN         , $X,
  RE_TOKEN_CONTROL         , $R,
  # synthetic types:
  #RE_TOKEN_CAP_GROUP_END   , $C,
  #RE_TOKEN_EXT_GROUP_END   , $W,
);

my %greedy_minimal_nobacktrack_sym_to_name = 
  (undef => 'greedy',
   '?' => 'minimal',
   '+' => 'no-backtrack');

my %anchor_sym_to_name = 
  ('^' => 'line start',
   '$' => 'line end',
   'b' => 'word boundary',
   'B' => ($U.'not'.$X.$K.' word boundary'),
   'A' => 'string start',
   'Z' => 'string end',
   'z' => 'string end incl last \n',
   'G' => 'restart at last pos',
   'K' => 'keep all before this');

my $ul_not = $U.'not'.$X.$K.' ';

my %escaped_class_to_desc =
  ('d' => '0-9',
   'D' => ($ul_not.'0-9'),
   'w' => 'A-Z, a-z, _',
   'W' => ($ul_not.'A-Z, a-z, _'),
   's' => '" ", \n, \t, \r, \v, \f',
   'S' => ($ul_not.'" ", \n, \t, \r, \v, \f'),
   'h' => '" ", \t',
   'H' => ($ul_not.'" ", \t'),
   'N' => ($ul_not.'newline (\n)'),
   'v' => '\n, \r, \v, \f',
   'V' => ($ul_not.'\n, \r, \v, \f'),
   'R' => 'any newline (\n, \n\r, \v)',
   'C' => 'one byte (if Unicode)',
   'p' => 'Unicode property',
   'p' => ($ul_not.'Unicode property'),
   'X' => 'Unicode grapheme');

my %ext_group_sym_to_desc = 
  ('#'  => 'comment',
   ':'  => 'non-capturing group',
   '='  => 'positive look ahead',
   '!'  => 'negative look ahead',
   '<=' => 'positive look behind',
   '<!' => 'negative look behind',
   '>'  => 'no backtracking',
   '|'  => 'branch cap group reset',
   '-'  => 'recurse into earlier subpattern',
   '+'  => 'recurse into later subpattern',
   'R'  => 'recurse back to start of regexp',
   '&'  => 'recurse into named subpattern');

sub beautify_regexp_token($$+;$$$$) {
  my ($token, $type, $subparts, $cap_group_index, $append_to_comment, $keep_orig_spacing, $hide_implied_backslashes) = @_;


#  if ($type !~ /^\d+$/) { print(STDERR NL.NL."type = [$type]\n".NL.NL); die; }
  $cap_group_index //= 0;
  $keep_orig_spacing //= 0;
  $hide_implied_backslashes //= (!$keep_orig_spacing);

  my $invert_bracketed_char_set = 0;
  my $comment = '';

  if ($type == RE_TOKEN_UNKNOWN) {
    $token =~ s/^/$R/oamsxg;
    my $out = $R.$token.$X;
    return $out;
  } elsif ($type == RE_TOKEN_COMMENT) {
    # Remove the trailing newline
    chomp $token;
  } elsif ($type == RE_TOKEN_BRACKETED_CHAR_SET) {
    $token = $subparts->{chars_in_brackets};
    $invert_bracketed_char_set = (exists($subparts->{invert_bracketed_char_set}) ? 1 : 0);
    # Don't show redundant backslashes for what is obviously a literal character:
    if ($hide_implied_backslashes) { $token =~ s/$any_escaped_symbol_re//oamsxg; }
  } elsif ($type == RE_TOKEN_LITERAL) {
    if ($hide_implied_backslashes) { $token =~ s/$any_escaped_symbol_re//oamsxg; }
    $token = $K.left_quote.$G.$token.$K.right_quote;
  } elsif ($type == RE_TOKEN_ESCAPED_CHAR_CLASS) {
    if ($token eq '\\s') {
      $token = ($use_enhanced_regexp_unicode_symbols) ? ($empty_square.' ') : ($Y.$U.' ');
    } elsif ($hide_implied_backslashes) {
      $token =~ s/\\//oamsxg; 
    }
    $comment .= ($escaped_class_to_desc{$token} // '(escaped char class)') . ' ';
  } elsif ($type == RE_TOKEN_ANCHOR) {
    if ($hide_implied_backslashes) { $token =~ s/\\//oamsxg; }
    $comment .= $anchor_sym_to_name{$token} . ' ';
  } elsif ($type == RE_TOKEN_CAP_GROUP_START) {
    my $cap_group_name = $subparts->{name} // $cap_group_index;
    if ($keep_orig_spacing) {
      if (exists($subparts->{name})) {
        $token = $C.'('.$K."'".$C.$cap_group_name.$K."'";
      } else {
        $token = $C.'(';
      }
    } else {
      my $sym = ($use_enhanced_regexp_unicode_symbols) ? $round_bold_left_paren : '(';
      my $displayed_cap_group_index = 
        ($B.$round_bold_left_paren.'$'.$C.$cap_group_index.$B .round_bold_right_paren);
      #my $displayed_cap_group_index = ($cap_group_index < 10) ? 
      #($C.chr(circled_large_digits + $cap_group_index).' ') : 
      #($B.$round_bold_left_paren.sharp_sign.$C.$cap_group_index.$B.round_bold_right_paren);
      $token = $C.$sym.$K.$C.$cap_group_name.
        $K.' '.$displayed_cap_group_index.$X;
    }
  } elsif ($type == RE_TOKEN_EXT_GROUP_START) {
    $token =~ /^\(\?(.*)$/oamsxg;
    my $group_type = $1;
    $comment .= ($ext_group_sym_to_desc{$group_type} // '('.$X.$group_type.$B.')') . ' ';
    #$token = ($token eq '(?:') ? $bold_left_brace : $flat_bold_left_paren;
    if ($use_enhanced_regexp_unicode_symbols||0) {
      $token = $bold_left_brace;
      if ($group_type =~ /^[\+\-]? \d | $R | \&/oamsx) {
        $token .= $counterclockwise_curved_arrow . $group_type;
      } elsif ($group_type eq ':') {
        # This group type is so common that we abbreviate it to reduce visual clutter
      } else {
        $token .= $group_type;
      }
    } else {
      #$token = $flat_bold_left_paren;
      if ($group_type eq ':') { $group_type = ''; }
      $token = $B.'('.$group_type;
    }
  } elsif ($type == RE_TOKEN_GROUP_END) {
    $token = $round_bold_right_paren if ($use_enhanced_regexp_unicode_symbols);
#  } elsif ($type == RE_TOKEN_EXT_GROUP_END) {
#    $token = $flat_bold_right_paren if ($use_enhanced_regexp_unicode_symbols);
  } elsif ($type == RE_TOKEN_QUANTIFIER) {
    my $min; my $max;
    if (exists($subparts->{short_count})) {
      $min = $short_count_to_min{$subparts->{short_count}} // 0;
      $max = $short_count_to_max{$subparts->{short_count}} // 0;
    } else {
      $min = ($subparts->{min_count} // 0);
      $max = ($subparts->{max_count} // (1<<31));
    }
    if ($min == (1<<31)) { $min = 'inf'; }
    if ($max == (1<<31)) { $max = 'inf'; }
    my $gmb = $greedy_minimal_nobacktrack_sym_to_name{$subparts->{greedy_minimal_nobacktrack}} // 'greedy';
    $comment .= $K.'['.$C.$U.$gmb.$X.$B.' range: '.
      $G.$min.$B.elipsis_three_dots.$R.$max.$K.']'.$X;
    if ($use_enhanced_regexp_unicode_symbols) {
      if (exists $short_count_to_beautified_symbol{$token}) 
        { $token = $short_count_to_beautified_symbol{$token} . ' '; }
    }
  } elsif ($type == RE_TOKEN_CONTROL) {
    if (0) {
    $token = $R.bold_left_angle_bracket.$Y.warning_sign.' ';
    my $action = $subparts->{control_action};
    my $is_mark = ((!is_there($action)) || ($action eq 'MARK'));
    $token .= ($is_mark ? $C : ($Y.$action));
    $token .= $M.($subparts->{control_arg}).
      $R.bold_right_angle_bracket.$X;
  }
  } elsif ($type == RE_TOKEN_OR) {
    #$token = long_narrow_double_vert_bars if ($use_enhanced_regexp_unicode_symbols||1);
    $token = '     ';
  } elsif ($type == RE_TOKEN_ANY_CHAR) {
    $token = checkmark_in_box.' ' if ($use_enhanced_regexp_unicode_symbols); 
  }
  my $formatting = $token_type_to_formatting{$type} // '';
  $token =~ s{[^\\]\K\\}{$K\\$formatting}oamsxg;
  my $out = '';
  if ($type == RE_TOKEN_BRACKETED_CHAR_SET) {
    if ($invert_bracketed_char_set) {
      if ($use_enhanced_regexp_unicode_symbols||1) {
        $out = ($R.not_equal_symbol.' '.$X);
      } else {
        $out = ($R.$U.'^ '.$X);
      }
      $formatting = $R;
    }
    if ($use_enhanced_regexp_unicode_symbols) {
      $out .= $K.double_left_angle_bracket.$formatting.$token.
        $K.double_right_angle_bracket.' '.$X;
    } else {
      $out .= $R.small_upper_left_corner_bracket.$formatting.$token.
        $R.small_lower_right_corner_bracket.$X;
    }
  } else {
    $out = $formatting.$token.$X;
  }
  if (defined($append_to_comment)) { $$append_to_comment .= $comment; }
  return $out;
}

my @index_to_greedyness_symbol = ($G.'(greedy)', $R.'? (minimal)', $M.'+ (possessive)');

my %token_type_to_token_symbol_color = (
  RE_TOKEN_CAP_GROUP_START,             $C,
  RE_TOKEN_EXT_GROUP_START,             $B,
  RE_TOKEN_LITERAL,                     $G,
  RE_TOKEN_LITERAL_STRING,              $C,
  RE_TOKEN_LITERAL_NUMERIC,             $R,
  RE_TOKEN_ANY_CHAR,                    $Y,
  RE_TOKEN_ESCAPED_CHAR_CLASS,          $Y,
  RE_TOKEN_SPACE_CHAR_CLASS,            $MID_GRAY,
  RE_TOKEN_BRACKETED_CHAR_SET,          $M,
  RE_TOKEN_ANCHOR,                      $M,
  RE_TOKEN_BACKREF,                     $R,
  RE_TOKEN_OR,                          $R,
  RE_TOKEN_COMMENT,                     $K,
  RE_TOKEN_CONTROL,                     $R,
);

my %token_type_to_token_symbol = (
  RE_TOKEN_CAP_GROUP_START,             checkmark, #$C.round_bold_left_paren.round_bold_right_paren, #$C.round_bold_left_paren.round_bold_right_paren,
  RE_TOKEN_EXT_GROUP_START,             dice_5_dots,    #$B.bold_left_brace.bold_right_brace,
  RE_TOKEN_LITERAL,                     left_quote.right_quote,
  RE_TOKEN_LITERAL_STRING,              left_quote.right_quote,
  RE_TOKEN_LITERAL_NUMERIC,             left_quote.right_quote,
  RE_TOKEN_ANY_CHAR,                    star_with_6_points,
  RE_TOKEN_ESCAPED_CHAR_CLASS,          copyright_symbol.copyright_symbol,
  RE_TOKEN_SPACE_CHAR_CLASS,            under_space,
  RE_TOKEN_BRACKETED_CHAR_SET,          small_upper_left_corner_bracket.small_lower_right_corner_bracket,
  RE_TOKEN_ANCHOR,                      anchor_symbol,
  RE_TOKEN_BACKREF,                     counterclockwise_curved_arrow,
  RE_TOKEN_OR,                          three_vert_bars,
  RE_TOKEN_COMMENT,                     sharp_sign,
  RE_TOKEN_CONTROL,                     warning_sign,
);

my %token_type_to_node_symbol = (
  RE_TOKEN_CAP_GROUP_START,             checkmark_in_box, #$C.round_bold_left_paren.round_bold_right_paren, #$C.round_bold_left_paren.round_bold_right_paren,
  RE_TOKEN_EXT_GROUP_START,             dice_5_dots, #$B.bold_left_brace.bold_right_brace,
  RE_TOKEN_LITERAL,                     chr(0x275d).chr(0x275e),
  RE_TOKEN_LITERAL_STRING,              arrow_open_tri,
  RE_TOKEN_LITERAL_NUMERIC,             arrow_open_tri,
  RE_TOKEN_ANY_CHAR,                    star_with_6_points,
  RE_TOKEN_ESCAPED_CHAR_CLASS,          copyright_symbol,
  RE_TOKEN_SPACE_CHAR_CLASS,            under_space,
  RE_TOKEN_BRACKETED_CHAR_SET,          small_upper_left_corner_bracket.small_lower_right_corner_bracket,
  RE_TOKEN_ANCHOR,                      anchor_symbol,
  RE_TOKEN_BACKREF,                     counterclockwise_curved_arrow,
  RE_TOKEN_OR,                          three_vert_bars,
  RE_TOKEN_COMMENT,                     sharp_sign,
  RE_TOKEN_CONTROL,                     warning_sign,
);

my %simple_token_type_to_node_symbol = (
  RE_TOKEN_CAP_GROUP_START,             arrow_tri,
  RE_TOKEN_EXT_GROUP_START,             arrow_tri,
  RE_TOKEN_OR,                          arrow_tri,
);

my %token_type_to_node_symbol_color = ( );

#  my $node_symbol_color = 
#    ($type == RE_TOKEN_OR) ? R.three_vert_bars :
#    ($parent_type == RE_TOKEN_OR) ? R.arrow_tri :
#      $token_sym_color.arrow_tri;

my %parent_type_to_branch_color = (
  RE_TOKEN_OR,              $R,
  RE_TOKEN_CAP_GROUP_START, $C,
  RE_TOKEN_EXT_GROUP_START, $B,
);

my %parent_type_to_branch_style = (
  RE_TOKEN_OR,               'double',
  RE_TOKEN_CAP_GROUP_START,  'thick',
  RE_TOKEN_EXT_GROUP_START,  'single',
);

my $obnoxiously_big_undef_marker = fg_color_rgb(255, 0, 64).bg_color_rgb(128, 128, 0).'Undefined! '.$BLINK.$R.big_x.$M.'B'.$R.big_x.$M.'O'.$R.big_x.$M.'G'.$R.big_x.$M.'U'.$R.big_x.$M.'S'.$R.big_x.$X;

sub format_regexp_parse_tree_node(+;+) {
  my ($node, $parent) = @_;

  my ($type, $token, $inputpos, $subnodes, $fields, $min_quant, $max_quant, $greedyness, $groupid) = @{$node};
  #$inputpos //= '???';
  my $parent_type = (defined $parent) ? $parent->[RE_TREE_NODE_TYPE] : RE_TOKEN_UNKNOWN;

  $greedyness //= RE_GREEDYNESS_GREEDY;

  my $typename = $regexp_token_type_to_name{$type} // ($R.'<type #'.$type.'>');

  my $quantifier_and_greed = ' ';

  if ((defined $min_quant && ($min_quant != 1)) || 
      (defined $max_quant && ($max_quant != 1))) {
    my $minq = $min_quant // -1;
    my $maxq = $max_quant // -1;

    my $short_quantifier = 
      (($minq == 0) && ($maxq == INFINITE_QUANTIFIER)) ? $G.asterisk :
      (($minq == 1) && ($maxq == INFINITE_QUANTIFIER)) ? $Y.large_plus :
      (($minq == 0) && ($maxq == 1)) ? $M.large_right_slash : '';
  
    my $greedyness_symbol = 
      (defined $greedyness) ? $index_to_greedyness_symbol[$greedyness] : '';
 
    $quantifier_and_greed .= $M.$short_quantifier.' '.
      $K.' {'.$R.($min_quant // 1).$K.elipsis_three_dots.
       $R.((($max_quant // 1) eq INFINITE_QUANTIFIER) ? infinity_sign : ($max_quant // 1)).$K.'}'.
       $M.' '.$greedyness_symbol;
  }

  my $comment = '';
  my $beautified_token = $X.beautify_regexp_token($token, $type, $fields, $groupid, \$comment);
  
  my $token_color = $token_type_to_formatting{$type} // $Y;
  if ($type == RE_TOKEN_EXT_GROUP_START) { $token_color = $C; }

  $DARKGRAY = fg_color_rgb(64, 64, 64);

  my $token_sym_color = $token_type_to_token_symbol_color{$type} // B;
  my $token_symbol = $token_sym_color.($token_type_to_token_symbol{$type} // '   ');
  my $branch_color = ($parent_type_to_branch_color{$parent_type} // $tree_branch_color);
  my $branch_style = ($parent_type_to_branch_style{$parent_type} // $tree_branch_to_node_style);
  
  if ($type == RE_TOKEN_COMMENT) { chomp $token; }

#  my $node_symbol_color = 
#    ($type == RE_TOKEN_OR) ? R.three_vert_bars :
#    ($parent_type == RE_TOKEN_OR) ? R.arrow_tri :
#      $token_sym_color.arrow_tri;
  my $node_symbol_color = 
    ($parent_type == RE_TOKEN_OR) ? R :
     ($token_type_to_node_symbol_color{$type} // $token_sym_color);

  my $node_symbol = 
    ($token_type_to_node_symbol{$type} // arrow_open_tri).' ';

#  my $leaf_symbol =
#    $token_sym_color.arrow_open_tri;

  my $label = [
    [ TREE_CMD_PREFIX, bg_color_rgb(32, 32, 32), bg_color_rgb(20, 20, 20) ],
    [ TREE_CMD_PREFIX, fg_color_rgb(64,  96, 128).' '.padstring($inputpos // R.'???', -4).
        ' '.X.$DARKGRAY.long_narrow_double_vert_bars.' ' ],
    [ TREE_CMD_BRANCH_COLOR, $branch_color ],
    [ TREE_CMD_BRANCH_STYLE, $branch_style ],
    [ TREE_CMD_SYMBOL, $node_symbol_color.$node_symbol.X ],
    $token_color.(($type == RE_TOKEN_COMMENT) ? K.'(comment)' : $beautified_token).X,
    [ TREE_CMD_FIELD ],
    ' '.$token_symbol,
    [ TREE_CMD_FIELD ],
    $token_color.UX.$typename,
    [ TREE_CMD_FIELD ],
    $quantifier_and_greed,
    [ TREE_CMD_FIELD ],
    (($type == RE_TOKEN_COMMENT) 
       ? K.' '.long_narrow_vert_bar.' '.($token =~ s/^\#\s*//roamsxg)
       : B.' '.long_narrow_vert_bar.' '.$comment).X,
  ];

  return $label;
}

noexport:; sub regexp_parse_subtree_to_printable_subtree {
  my ($node, $level, $parent) = @_;

  $level //= 0;

  my $info = format_regexp_parse_tree_node($node, $parent);
  my $printnode = [ $info ];

  my $subnodes = $node->[RE_TREE_NODE_SUBNODES];

  if (defined ($subnodes)) {
    foreach $subnode (@$subnodes) {
      push @$printnode, regexp_parse_subtree_to_printable_subtree($subnode, $level+1, $node);
    }
  }

  return $printnode;
}

sub regexp_parse_tree_to_printable_tree($;$) {
  my ($rootnode, $name) = @_;

  return regexp_parse_subtree_to_printable_subtree($rootnode);
}

sub simple_format_tokenized_regexp {
  my ($tokens) = @_;


  my $out = '';
  
  my $n = scalar(@{$tokens});
  my $i = 0;
  
  for (my $i = 0; $i < $n; $i++) {
    my $t = $tokens->[$i];
    my ($token, $type, $startpos, $len, $subparts) = @{$t};
    $out .= $B.$type.' '.$C.$token.$B.dashed_vert_bar_4_dashes;
  }

  return $out;
}

sub short_list_compiled_regexps(;+) {
  #my $regexp_names_to_print = $_[0];

  my @keylist = sort(keys %compiled_regexps);
  my $re_name_line_len = 2;
  print(STDOUT "  ");

  foreach my $regexpname (@keylist) {
    #if (defined(@{$regexp_names_to_print})) {
    #next if (!list_contains($regexp_names_to_print, $regexpname));
    #}

    if (($re_name_line_len + (length($regexpname) + 2)) >= 78) {
      print(STDOUT "\n  ");
      $re_name_line_len = 2;
    }
    print(STDOUT $G.$regexpname.$K.", ");
    $re_name_line_len += length($regexpname) + 2;
  }
  print(STDOUT "${X}\n\n");
}

sub list_compiled_regexps() {
  my @keylist = sort(keys %compiled_regexps);

  my $longest_name = 0;

  foreach my $regexpname (@keylist) {
    my $n = length($regexpname) + 3; # +3 for '_re'
    # Ignore very long names over 30 characters:
    if (($n < 40) && ($n > $longest_name)) {
      $longest_name = $n;
    }
  }

  foreach my $regexpname (@keylist) {
    my $description = $compiled_regexp_descriptions{$regexpname};
    if (is_filled($description)) {
      $description = $K.''.$C.$description.$K.''.$X // undef;
      my $n = length($regexpname) + 3;
      my $padcount = 40 - (($n <= 40) ? $n : 40);
      my $regexpname_padded = $Y.$regexpname.'_re'.$K.('.' x $padcount);
      print(STDOUT '  '.$regexpname_padded.$description."\n");
    } else {
      print(STDOUT '  '.$Y.$regexpname.'_re'.$X."\n");
    }
  }
}

my $dark_gray = fg_color_rgb(64, 64, 64);

sub describe_regexp_metadata($) {
  my ($m) = @_;

  my $out = '';

  sub format_metadata_line {
    my ($field, $value) = @_;

    return $K.dot.' '.$G.$U.$field.':'.$UX.$dark_gray.
      (elipsis_three_dots x (26 - length($field))).' '.$Y.
       $value.NL;
  };

  $out .= format_metadata_line('Modifiers', $M.join($B.dashed_vert_bar_3_dashes.$M, split(//oax, ($m->{modifiers} // ''))));
  $out .= format_metadata_line('Characters', $m->{characters});
  $out .= format_metadata_line('Tokens', $m->{tokens});
  $out .= format_metadata_line('Structural Groups', $m->{structural_groups});
  $out .= format_metadata_line('Capture Groups', $m->{cap_groups});
  $out .= format_metadata_line('Named Capture Groups', $m->{named_cap_groups});
  $out .= format_metadata_line('Numbered Capture Groups', $m->{numbered_cap_groups});
  $out .= format_metadata_line('Anchored string', format_quoted($m->{anchored_string}));
  $out .= format_metadata_line('Floating string', format_quoted($m->{anchored_string}));

  return $out;
}

sub show_compiled_regexp($;$$$) {
  my ($regexp_name, $re, $description, $pretty_print) = @_;

  $re //= $compiled_regexps{$regexp_name};

  if (ref $re) { $re = ${$re}; }

  $tree_pre_branch_color = fg_color_rgb(64, 64, 64);
  
  my ($resrc, $modifiers) = regexp_pattern($re);
  $resrc //= $re;
  $modifiers //= '';

  my $tokens = tokenize_regexp($resrc, $modifiers);
  my $metadata = get_tokenized_regexp_metadata($re, $tokens);
  my $rootnode = tokenized_regexp_to_tree($tokens, $modifiers);
  my $printable_tree = regexp_parse_tree_to_printable_tree($rootnode, 'regexp_name');

  $description //= $compiled_regexp_descriptions{$regexp_name} // '';
  $pretty_print //= 1;

  my $box_width = get_terminal_width_in_columns() - 10;

  $description =~ s/\n/\ /oamsxg;

  my $boxed_text = '%{tab=left,rounded}%B %{sym=arrow_head}  %C%U'.$regexp_name.'%!U'.NL;

  if (length($description) > 0) {
    my $description_color = '%{rgb=#d8d8d8}';

    my $wrapped = Text::Format->new(columns => $box_width-4,
                                    firstIndent => 0, 
                                    bodyIndent => 0, 
                                    justify => 1, 
                                    tabstop => 1)->format($description);
    chomp $wrapped;
    $wrapped =~ s{\n\K}{$description_color}oamsxg;
    $boxed_text .= $description_color.$wrapped.NL;
    $boxed_text .= '%{div=dashed}'.NL;
  }

  #
  # Apply simple colorization to the original regexp, but make sure we print it
  # exactly the same way it was originally provided for compilation in text form:
  #
  my $printable_original_regexp = $resrc 
    =~ s{(\[[^\]]+\])}{$R$1$X}roamsxg
    =~ s{\\ (.)}{$K\\$M$1}roamsxg
    =~ s{(?= $regexp_comment_re)}{$K}roamsxg
    =~ s{((?<! \\) \( \? . | (?<! \\) \))}{$B$1$X}roamsxg
    =~ s{((?<! \\) \( (?! \?))}{$C$1$X}roamsxg
    =~ s{\\ (?! \w)}{$K\\$X}roamsxg
    =~ s{\|}{$R\|$X}roamsxg
    =~ s{\]}{$R]}roamsxg
    =~ s{((?<! \() [\+\*\?] | $braces_re)}{$Y$1$X}roamsxg;

  $boxed_text .= $printable_original_regexp.NL;

  $boxed_text .= '%{div=dashed}'.NL;
  my $modifier_separator = $B.dashed_vert_bar_3_dashes.$M;
  $boxed_text .= describe_regexp_metadata($metadata);

  print(STDOUT text_in_a_box($boxed_text, ALIGN_LEFT, $B, 'rounded', 'dashed', undef, $box_width));
  print(STDOUT NL);
  
  if ($pretty_print) {
    print_tree($printable_tree, STDOUT);
  } else {
    print(STDOUT $resrc.NL.NL);
  }

  print(STDOUT NL);
}

sub show_compiled_regexps(;++$) {
  my $regexp_hash_table = $_[0] // \%compiled_regexps;
  my $regexp_name_list = $_[1] // \@compiled_regexp_names;
  my $pretty_print = $_[2] // 1;

  foreach my $regexp_name (@$regexp_name_list) {
    die if (!defined($regexp_name));
    if (!exists($regexp_hash_table->{$regexp_name})) {
      print(STDERR NL.$Y.' '.warning_sign.' '.$Y.$U.'WARNING:'.$X.$R.
            ' specified built-in regexp '.$K.left_quote.
            $C.$re_name.$K.right_quote.$R.' does not exist'.$X.NL.NL);
      next;
    }

    my $description = $compiled_regexp_descriptions{$regexp_name} // '';

    show_compiled_regexp($regexp_name, $regexp_hash_table->{$regexp_name},
                         $description, $pretty_print);
  }
  print(NL.$K.'Finished presenting '.$Y.scalar(@$regexp_name_list).$K.' regular expressions.'.$X.NL.NL);
}

sub show_raw_compiled_regexps(;++) {
  show_compiled_regexps($1, $2, 0);
}

my %perl_to_boost_xpressive_regexp_token_map = 
  (
   '.' => '_',
   '|' => '|',
   '(?:' => '(',
   '^' => 'bos',  '$' => 'eos',
   '\\b' => '_b', '\\B' => '~_b',
   '\\n' => '_n',
   '\\w' => '_w', '\\W' => '~_w',
   '\\d' => '_d', '\\D' => '~_d',
   '\\s' => '_s', '\\S' => '~_s',
   '(?i:' => 'icase(',
   '(?>' => 'keep(',
   '(?=' => 'before(', '(?!' => '~before(',
   '(?<=' => 'after(', '(?<!' => '~after('
  );

sub convert_perl_regexp_to_boost_xpressive_regexp($) {
  my ($re) = @_;


  my $tokens = tokenize_regexp($re);
  my $out = '';
  my $n = scalar(@{$tokens});
  my $cap_group_count = 0;

  for (my $i = 0; $i < $n; $i++) {
    my $token = $tokens->[$i];

    my $new_token = $perl_to_boost_xpressive_regexp_token_map{$token};

    if (defined($new_token)) {
      $out .= ' << '. $new_token;
      next;
    }

    if ($token eq '(') {
      $cap_group_count++;
      $new_token = '(s'.$cap_group_count.'= ';
    } elsif ($token =~ /\\ (\d+)/oamsx) {
      $new_token = 's'.$1;
    } elsif ($token =~ /[\*\+\?]/oamsx) {
      #$
    }
  }
}

1;
