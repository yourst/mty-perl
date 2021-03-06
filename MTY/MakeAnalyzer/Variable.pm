#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::MakeDatabaseParser
#
# Parse the database of make rules and recipes output of 'make -p' 
# so it can be saved and reloaded to accelerate make's performance
# on complex collections of many makefiles, or analyzed for many
# other useful applications
#
# Copyright 2003-2015 Matt T. Yourst <yourst@yourst.com>. All rights reserved.
#

package MTY::MakeAnalyzer::Variable;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(dump_variable format_variable print_variables print_summary_of_variable
     dump_variables_in_category print_summary_of_variables
     print_variables_in_category print_variables_in_all_categories
     create_reverse_map_of_path_variable_values_to_names);

use MTY::MakeAnalyzer::Common;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::StringFormats;
use MTY::Display::TextInABox;
use MTY::Display::Tree;
#pragma end_of_includes

my %var_origin_to_color = (
  'makefile' => $C,
  'environment' => $M,
  'automatic' => $Y,
  'default' => $R,
  'command line' => $G);

sub format_variable(+) {
  my ($v) = @_;

  my $color = $var_origin_to_color{$v->{origin}} // $Y;

  my $tree = [ 
    [ 
      [ TREE_CMD_SYMBOL, $Y.asterisk ], 
      $color.$U.subst_path_prefix_strings($v->{name}, $color).$X,
    ],
    [ $K.'(Defined on line '.$B.'#'.$v->{input_line}.$K.' in make dump'.$X ],
  ];

  if (is_there($v->{defined_in_makefile})) {
    push @$tree, [ $Y.'location'.$K.' = '.$M.
                     subst_path_prefix_strings($v->{defined_in_makefile}, $M).
                     (is_there($v->{defined_in_makefile_line}) ? $K.' on line '.
                        $M.$v->{defined_in_makefile_line}.$X : '') ];
  }

  push @$tree, [ $Y.'op '.$K.' = '.$G.
                   (($v->{op} eq ':=') ? ('immediate ('.$M.':='.$G.')') : ('recursive ('.$M.'='.$G.')')).$X ];
  push @$tree, [ $Y.'origin'.$K.' = '.$color.$v->{origin}.$X ];
  if ($v->{special}) { push @$tree, [ $Y.'special'.$K.' = '.$G.$v->{special}.$X ]; }
  
  my $value = $v->{value};

  # my $value = subst_path_prefix_strings($v->{value} // '<unknown>', $G);

  if ($v->{multiline}) {
    my @lines = split /\n/, $value;
    my $multi_line_node = [ $Y.'multiline'.$K.' = '.$G.scalar(@lines).$K.' lines:'.$X ];
    foreach my $line (@lines) 
      { push @$multi_line_node, [ $G.$line.$X ]; }
    push @$tree, $multi_line_node;
  } else {
    push @$tree, [ $Y.'value'.$K.' = '.format_quoted($G.$value).$X ];
  }

  return $tree;
}

sub print_variables(+;$$) {
  my ($variables, $fd) = @_;

  $fd //= STDOUT;

  my @var_names = sort keys %{$variables};

  foreach my $v (@var_names) {
    $v = $variables->{$v};
    my $tree = format_variable($v);
    print_tree($tree, $fd);
  }
}

my $may_be_directory_path_re = 
  qr{^ [\w\ \~\!\@\$\%\^\&\-\_\+\=\|\:\;\'\"\<\>\,\.\/]+ $}oax;

my $exclude_variable_names_from_path_map_re = 
  qr{^(?: \w+ \[ | \.)}oax;

sub create_reverse_map_of_path_variable_values_to_names(+;+) {
  my ($variables, $revmap) = @_;

  $revmap //= { };
  my $varcount = 0;
  my $uniquevars = 0;
  my $candidates = 0;
  my $dirvars = 0;
  my $DEBUG = 1;

  if ($DEBUG) {
    printfd(STDERR, $C.$U.'Creating a reverse mapping of variables which specify directory names...'.$X.NL);
  }

  while (my ($k, $v) = each %{$revmap}) {
    $v = normalize_and_add_trailing_slash($v);
    if ($DEBUG) { 
      printfd(STDERR, '  '.$G.checkmark.' '.$Y.$U.$k.$UX.
            $K.' ('.$B.'built-in'.$K.')'.$B.' = '.
             $K.left_quote.fg_gray(216).$v.$K.right_quote.
            $G.' '.checkmark.' is a directory!'.$UX.'  '.$X.NL); 
    }
  }

  while (my ($k, $var) = each %{$variables}) {
    next if ($k =~ $exclude_variable_names_from_path_map_re);
    my $o = $var->{origin};
    next unless ($o eq 'makefile') || ($o eq 'command line') || ($o eq 'override') || ($o eq 'environment override');
    my $v = $var->{value} // '';
    $varcount++;
    next if ((length($v) == 0) || (exists $revmap->{$v}));
    $uniquevars++;
    next unless (($v =~ /\//oax) && ($v =~ /$may_be_directory_path_re/oax));
    $candidates++;
    $v = normalize_and_add_trailing_slash($v);

    if (-d $v.'/') {
      $revmap->{$v} = $k;
      $dirvars++; 
      if ($DEBUG) { 
        printfd(STDERR, '  '.$G.checkmark.' '.$Y.$U.$k.$UX.
                $K.' ('.($o eq 'makefile' ? $C : $R).$o.$K.')'.$B.' = '.
                $K.left_quote.fg_gray(216).$v.$K.right_quote.
                $G.' '.checkmark.' '.$U.'is a directory!'.$UX.'  '.$X.NL); 
      }
    }
  }

  if ($DEBUG) {  
    printfd(STDERR, $C.' '.checkmark.' done'.$X.NL);
    printfd(STDERR,             $K.' '.dot.' '.$C.padstring($varcount, -5).' '.$Y.'total variables'.$X.NL.
             $K.' '.dot.' '.$C.padstring($uniquevars, -5).' '.$Y.'unique variable values'.$X.NL.
             $K.' '.dot.' '.$C.padstring($candidates, -5).' '.$Y.'candidate values which may be directories'.$X.NL.
                  $K.' '.dot.' '.$C.padstring($dirvars, -5).' '.$Y.'values which actually named directories'.$X.NL.NL);
    printfd(STDERR, NL);
  }

  return $revmap;
}

sub print_variables_in_category(+$;$) {
  my ($varlist, $category, $fd) = @_;

  $fd //= STDOUT;

  printfd($fd, NL.text_in_a_box($Y.$category.$G.' Variables'.$B.
    ' ('.scalar(@$varlist).')'.$X, 0, $G, 'single', undef, 20, 40).NL);
  
  foreach my $v (@$varlist) {
    print_variable($v, $fd);
  }
}

sub print_variables_in_all_categories(+;$) {
  my ($categories, $fd) = @_;

  $fd //= STDOUT;

  foreach my $category (sort keys %{$categories}) {
    my $varlist = $categories->{$category};
    print_variables_in_category($varlist, $category, $fd);
  }
}

my $variable_summary_format = 
  '%-60s '.$Y.'%-2s'.'%s'.'  %-12s  '.$R.'%-3s  '.$B.'%4s '.$K.' lines'.
  $K.' @ '.$M.'%s'.$K.':'.$M.'%s'.NL;

sub print_summary_of_variable(+;$$) {
  my ($v, $fd, $filenames_relative_to_dir_re) = @_;

  $fd //= STDOUT;

  my $color = ($var_origin_to_color{$v->{origin}} // $Y);
  my $value = $v->{value};

  my $name = subst_path_prefix_strings($v->{name}, $color);
  if (printed_length($name) > 55) { $name = elipsis_three_dots.substr($name, -55, 55).'  '; }
  my $defined_in_makefile = $v->{defined_in_makefile} // '-';

  if (defined $filenames_relative_to_dir_re) 
    { $defined_in_makefile =~ s{$filenames_relative_to_dir_re}{}oamsxg; }
    
  printf($fd $color.$variable_summary_format,
         $name, $v->{op}, $color, $v->{origin}, ($v->{special} ? '(S)' : '   '),
         ($v->{multiline} ? scalar(@{$value}) : 1),
         subst_path_prefix_strings($defined_in_makefile, $M), 
         $v->{defined_in_makefile_line} // '-');
}

sub print_summary_of_variables(+;$$) {
  my ($variables, $categories, $fd) = @_;

  $fd //= STDOUT;

  print_summary_of_categories($categories, 'variables', $fd);

  my @variable_names = sort keys %$variables;

  foreach my $vn (@variable_names) {
    print_summary_of_variable($variables->{$vn}, $fd, $cwd_re);
  } 
}

sub dump_variable(+) {
  my ($v) = @_;

  my $value = $v->{value};

  my $name = $v->{name};
  my $excluded = (exists $excluded_vars{$name});
  foreach my $re (@exclude_var_regexps) 
    { if ($name =~ /$re/) { $excluded = 1; last; } }
  if ($excluded) { return '# excluded variable: '.$name.NL; }

  my $is_empty = ((length($value)) == 0);
  if ($is_empty && $skip_empty_vars) { return '# empty: '.$name.NL; }

  my $out = NL.'# variable '.$name.': '.
    'origin='.$v->{origin}.', '.
    'flavor='.$v->{flavor};

  if ($v->{special}) 
    { $out .= ', special='.$v->{special}; }

  $out .= ', loc='.($v->{defined_in_makefile} // '-').
    ':'.($v->{defined_in_makefile_line} // 0).NL;
  
  if ($v->{multiline}) { $out .= 'define '; }
  $out .= $name;
  if (is_there($v->{op})) { $out .= ' '.$v->{op}.' '; }
  if ($v->{multiline}) {
    $out .= NL.$value;
    $out .= 'endef  # '.$name.NL;
  } else {
    $out .= $value.NL;
  }
  
  return $out;
}

sub dump_variables_in_category(+$) {
  my ($varlist, $category) = @_;

  my $out = NL.'#'.NL.'# '.$category.': '.
    scalar(@$varlist).' variables:'.NL.'#'.NL.NL;

  foreach my $v (@$varlist) {
    if (exists $excluded_variables{$v->{name}}) {
      $out .= '# excluded: '.$v->{name}.NL;
    } else {
      $out .= dump_variable($v);
    }
  }
  $out .= NL;
  return $out;
}

1;
