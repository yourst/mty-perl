#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::MakeAnalyzer::Target
#
# Copyright 2003-2015 Matt T. Yourst <yourst@yourst.com>. All rights reserved.
#

package MTY::MakeAnalyzer::Target;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(add_implicit_target add_implicit_targets_to_target_list dump_target
     dump_targets_in_category format_target
     print_dependency_tree_from_target_deps_and_labels
     print_dependency_trees_for_all_targets print_summary_of_target
     print_summary_of_targets print_target print_targets
     print_targets_in_all_categories print_targets_in_category
     target_dep_lists_to_printable_tree_labels targets_to_dep_lists);

use MTY::MakeAnalyzer::Common;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Filesystem::Files;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;
use MTY::Display::Tree;
#pragma end_of_includes

#
# Create dummy target structures for any implicit "targets"
# (or more accurately, "sources") which were listed as
# prerequisite dependencies of other targets and/or included
# as makefiles, but were not explicitly defined as targets
# by any makefiles.
#
# These implicit targets are by definition always real files
# that must exist at the start of the build (otherwise make
# would be unable to proceed). Implicit targets generally
# include manually created source code files, header files,
# scripts and makefiles (unless any of these are dynamically 
# created at build time).
#
# Each of these files must have a corresponding structure
# in the %targets hash to ensure the dependency graph is a
# fully connected closed system which only links to other
# items with keys in the %targets hash, since this greatly
# simplifies the rest of the code. 
#
# Each implicit pseudo-target has a type field of 'implicit'
# and an empty list of dependencies (since it is a terminal
# node in the graph).
#

sub add_implicit_target($++) {
  my ($name, $targets, $implicit_targets) = @_;

  if (exists $targets->{$name}) { 
    return $targets->{$name}; 
  }

  my $t = {
    name => $name,
    type => 'implicit',
    phony => 0,
    deps => \@empty_array,
    order_only_deps => \@empty_array,
  };

  $targets->{$name} = $t;

  push @$implicit_targets, $t->{name};

  return $t;
}

sub add_implicit_targets_to_target_list(+) {
  my ($targets) = @_;

  my @implicit_targets = ( );

  printfd(STDERR, print_folder_tab($M.'Adding Missing Implicit Targets...'));
  printfd(STDERR, $C.$U.'Adding missing implicit pseudo-targets (i.e. source files) not declared in makefiles...'.$X.NL);

  foreach $t (values %$targets) {
    my $name = $t->{name};

    foreach $dep (@{$t->{deps}}, @{$t->{order_only_deps}}) {
      if (!exists $targets->{$dep}) 
        { add_implicit_target($dep, $targets, @implicit_targets); }
    }

    my $makefile = $t->{defined_in_makefile};
    if (defined $makefile) {
      if (!exists ($targets->{$makefile})) { add_implicit_target($makefile, $targets, @implicit_targets); }
    }
  }

  printfd(STDERR, $G.' '.checkmark.' done: found and added '.$Y.scalar(@implicit_targets).' implicit pseudo-targets:'.NL.NL);
  foreach my $it (sort @implicit_targets) { 
    printfd(STDERR, $K.' '.dot_small.' '.$Y.format_file_path($it).$X.NL); 
  }
  printfd(STDERR, NL);
}

sub format_target(+) {
  my ($t) = @_;

  my $tree = [ 
    [ 
      [ TREE_CMD_SYMBOL, $C.dot_in_circle ], 
      $C.subst_path_prefix_strings($t->{name}, $C),' '.
      $K.' (on line #'.$B.$t->{input_line}.$K.')' 
    ]
  ];

  push @$tree,[ $Y.'type'.$K.' = '.$G.$t->{type} ];

  if ($t->{phony}) { push @$tree,[ $Y.'phony '.$K.' = '.$G.'phony' ]; }

  if (exists $t->{defined_in_makefile}) {
    push @$tree,[ $Y.'defined in'.$K.': '.$M.
      subst_path_prefix_strings($t->{defined_in_makefile}, $M).
      $K.' line '.$M.($t->{defined_in_makefile_line} // $R.'(unknown)') ];
  }

  if ((scalar @{$t->{deps}}) > 0) {
    my $deps_tree_node = [ 
      [ 
        [ TREE_CMD_SYMBOL, $M.chr(0x27f4) ],
        $Y.'deps'.$K.':' 
      ]
    ];
    foreach my $dep (@{$t->{deps}}) {
      push @$deps_tree_node, [ $G.subst_path_prefix_strings($dep, $G) ]; 
    }
    push @$tree,$deps_tree_node;
  }

  if ((scalar @{$t->{order_only_deps}}) > 0) {
    my $deps_tree_node = [ $Y.'order-only-deps '.$K.':' ];
    foreach my $dep (@{$t->{order_only_deps}}) 
      { push @$deps_tree_node, [ $G.subst_path_prefix_strings($dep, $G) ]; }
    push @$tree,$deps_tree_node;
  }

  if ((scalar @{$t->{recipe}}) > 0) {
    my $recipe_node = [ [ [ TREE_CMD_SYMBOL, $Y.checkmark ], $Y.'recipe: ' ] ];
    foreach my $line (@{$t->{recipe}}) 
      { push @$recipe_node, [ $Y.subst_path_prefix_strings($line, $Y) ]; }
    push @$tree,$recipe_node;
  }

  return $tree;
}

sub print_target($;$) {
  my ($target, $fd) = @_;

  $fd //= STDOUT;

  print_tree(format_target($target), $fd);
}


sub print_targets(+;$) {
  my ($targets, $fd) = @_;

  $fd //= STDOUT;

  my $tree = [
    [ 
      [ TREE_CMD_SYMBOL, dot_in_circle ],
      $C.$U.'TARGETS'.$X
    ]
  ];

  my @target_names = sort keys %$targets;

  foreach my $name (@target_names) {
    # skip pseudo-targets like .PHONY, .ONESHELL, etc. since they add no
    # useful information in the output that we don't print elsewhere:
    next if ($name =~ /^\.[A-Z]+/oax);
    push @$tree, format_target($targets->{$name}); 
  }

  print_tree($tree, $fd);
}

sub print_targets_in_category(+$;$) {
  my ($tgtlist, $category, $fd) = @_;

  $fd //= STDOUT;

  printfd($fd, NL.text_in_a_box($M.$category.$C.' Targets '.$B.
    ' ('.scalar(@$tgtlist).')'.$X, 0, $B, 'single', undef, 20, 40).NL);
  
  foreach my $t (@$tgtlist) {
    print_target($t, $fd);
  }
}

sub print_targets_in_all_categories(+;$) {
  my ($categories, $fd) = @_;

  $fd //= STDOUT;

  foreach my $category (sort keys %{$categories}) {
    my $tgtlist = $categories->{$category};
    next if (!defined $tgtlist);
    print_targets_in_category($tgtlist, $category, $fd);
  }
}

my %target_type_to_color = (
  'explicit' => $C,
  'implicit' => $R,
  'special' => $M,
  'phony' => $Y,
  'variable' => $G,
  'deps' => $M,
  'dir' => $B);

my $target_summary_format = 
  '%-60s '.'  %-8s'.$Y.'  %-5s'.$K.'  '.
  $G.'%3s '.$K.'deps  '.$G.'%3s '.$K.'oodeps  '.
  $B.'%4s '.$K.' lines'.$K.' @ '.$M.'%s'.$K.':'.$M.'%s'.NL;

sub print_summary_of_target(+;$) {
  my ($t, $fd) = @_;

  $fd //= STDOUT;

  die if (!defined $t);

  my $name = $t->{name};
  my $type = $t->{type};
  if ($type =~ /dir\[/oax) { $type = 'dir'; }
  my $color = $target_type_to_color{$type} // $G;

  my $printed_name = subst_path_prefix_strings($name, $color);

  my $dep_count = (defined $t->{deps}) ? scalar(@{$t->{deps}}) : 0;
  my $order_only_dep_count = (defined $t->{order_only_deps}) ? scalar(@{$t->{order_only_deps}}) : 0;
  my $recipe_line_count = (defined $t->{recipe}) ? scalar(@{$t->{recipe}}) : 0;
  if (printed_length($name) > 55) { $name = elipsis_three_dots.substr($name, -55, 55).'  '; }
  my $defined_in_makefile = subst_path_prefix_strings($t->{defined_in_makefile} // '-', $M);

  printf($fd $color.$target_summary_format,
         subst_path_prefix_strings($name), 
         $t->{type}, ($t->{phony} ? 'phony' : ''),
         $dep_count, $order_only_dep_count, $recipe_line_count,
         $defined_in_makefile, $t->{defined_in_makefile_line} // '-');
}

sub print_summary_of_targets(+;+$) {
  my ($targets, $categories, $fd) = @_;

  $fd //= STDOUT;

  print_summary_of_categories($categories, 'targets', $fd);

  my @target_names = sort keys %$targets;

  foreach my $tn (@target_names) 
    { print_summary_of_target($targets->{$tn}, $fd); }
}

sub dump_target(+) {
  my ($t) = @_;


  my $name = $t->{name};
  my $excluded = (exists $excluded_targets{$name});
  foreach my $re (@exclude_target_regexps) 
    { if ($name =~ /$re/) { $excluded = 1; last; } }
  if ($excluded) { return '# excluded target: '.$name.NL; }

  my $dep_count = scalar(@{$t->{deps}});
  my $order_only_dep_count = scalar(@{$t->{order_only_deps}});
  my $recipe_line_count = scalar(@{$t->{recipe}});

  my $out = NL.'# target '.$name;

  $out .= ': type='.$t->{type} .
    ', phony='.$t->{phony} .
    ', deps='.$dep_count .
    ', order_only_deps='.$order_only_dep_count .
    ', recipe_lines='.$recipe_line_count . 
    ', loc='.($t->{defined_in_makefile} // '-').
      ':'.($t->{defined_in_makefile_line} // 0).NL;

  if ($t->{phony}) { $out .= '.PHONY: '.$name.NL; }

  $out .= $name.':';
  if ($dep_count > 0) 
    { $out .= ' '.join(' ', @{$t->{deps}}); }
  if ($order_only_dep_count) 
    { $out .= ' | '.join(' ', @{$t->{order_only_deps}}); }
  $out .= NL;

  foreach my $line (@{$t->{recipe}}) {
    $out .= TAB.$line.NL;
  }
  $out .= NL;
  return $out;
}

sub dump_targets_in_category(+$) {
  my ($tgtlist, $category) = @_;


  my $out = NL.'#'.NL.'# '.$category.': '.
    scalar(@$tgtlist).' targets:'.NL.'#'.NL.NL;

  foreach my $t (@$tgtlist) {
    $out .= dump_target($t);
  }

  $out .= NL;
  return $out;
}

sub targets_to_dep_lists(+;$$) {
  my ($targets, $include_normal_deps, $include_order_only_deps) = @_;

  $include_normal_deps //= 1;
  $include_order_only_deps //= 1;

  my %target_names_to_deps = ( );

  foreach my $t (values %{$targets}) {
    my $name = $t->{name};
    my $deps = $t->{deps};
    my $oodeps = $t->{order_only_deps};
    #prints( "targets_to_dep_lists: target name [$name] @ ".$t." => deps ".($t->{deps}//'undef').', oodeps '.($t->{oodeps}//'undef').NL);
    my @deplist = ( );
    push @deplist, @{$t->{deps}} if ($include_normal_deps);
    push @deplist, @{$t->{order_only_deps}} if ($include_order_only_deps);

    $target_names_to_deps{$name} = \@deplist;
  }

  return \%target_names_to_deps;
}

my %type_to_abbrev = (
  'explicit' => $C.round_bold_left_paren.estimate_e.round_bold_right_paren,
  'implicit' => $R.round_bold_left_paren.info_i_symbol.round_bold_right_paren,
  'special' => $M.round_bold_left_paren.double_struck_sigma.round_bold_right_paren,
  'phony' => $Y.round_bold_left_paren.p_in_circle.round_bold_right_paren,
  'variable' => $G.round_bold_left_paren.'V'.round_bold_right_paren,
  'deps' => $M.round_bold_left_paren.double_struck_d.round_bold_right_paren,
  'dir' => $B.round_bold_left_paren.double_struck_r.round_bold_right_paren);
  
sub target_dep_lists_to_printable_tree_labels(++;++) {
  my ($targets, $target_names_to_deps, $target_names) = @_;

  my %target_names_to_labels = ( );

  # Optimization: if the caller already assembled an array of all target names,
  # we can reuse this array here. If not, we'll just regenerate it:
  $target_names //= [ keys %{$targets} ];

  my %printed_target_names = ( );

  foreach $tn (@$target_names) {
    my $t = $targets->{$tn};
    if (!defined $t) { die("Cannot find target '$tn' in the hash of all targets"); }
        
    my $name = $t->{name};
    my $type = $t->{type};
    my $type_color = $target_type_to_color{$type} // $Y;

    #
    # Anything in deps will eventually become a target anyway,
    # so we already would have mapped any path prefixes in it:
    #
    my $deps = $target_names_to_deps->{$name} // \@empty_array;

    my $printed_name = subst_path_prefix_strings($name, $type_color);
    $printed_target_names{$name} = $printed_name;

    my $label = $type_to_abbrev{$type}.' '.$printed_name;
    
    my $makefile = $t->{defined_in_makefile};

    if (defined $makefile) {
      $printed_makefile_name = $printed_target_names{$makefile};
      if (!defined $printed_target_name) {
        $printed_makefile_name = subst_path_prefix_strings($makefile, $M);
        $printed_target_names{$makefile} = $printed_makefile_name;
      }
      $label .= $K.' (from '.$M.$printed_makefile_name.
        $K.' @ '.$M.($t->{defined_in_makefile_line} // 0).$K.'); ';
    }
    
    my $depcount = scalar(@{$t->{deps}});
    if ($depcount > 0) 
      { $label .= $R.' '.$depcount.' '.$B.' deps'.$K; }
    
    my $oodepcount = scalar(@{$t->{order_only_deps}});
    if ($oodepcount > 0) 
      { $label .= $K.' ('.$M.$oodepcount.
          $UX.$G.' order only deps'.$K.')'; }

    $target_names_to_labels{$name} = $label;
  }

  return \%target_names_to_labels; 
}

sub print_dependency_tree_from_target_deps_and_labels(+$++;$+) {
  my ($t, $target_name, $target_names_to_deps, $target_names_to_labels, $outfd, $visited) = @_;

  $outfd //= STDOUT;
  
  my $options = ($target_name =~ /^\./oax) ? DEPENDENCY_GRAPH_TO_TREE_NO_RECURSION : 0;

  my $type = $t->{type};
  if ($type =~ /dir\[/oax) { $type = 'dir'; }

  my $color = $target_type_to_color{$type} // $G;
  # my $printed_name = subst_path_prefix_strings($name, $color);
  my $label = $color.format_file_path($target_name).$B.'   '.four_diamonds.'   '.$color.$type.$K;
  if ($t->{defined_in_makefile}) {
    $label .= ' from '.$M.subst_path_prefix_strings($t->{defined_in_makefile}, $M).
      $K.':'.$B.($t->{defined_in_makefile_line} // '?');
  }

  if (!defined $visited) { $visited = { }; }

  printfd($outfd, print_folder_tab($label));
  my $tree = dependency_graph_to_tree($target_name, $target_names_to_deps, $target_names_to_labels, $options, $visited);
  print_tree($tree, $outfd);
  printfd($outfd, NL);
}

sub print_dependency_trees_for_all_targets(+;$$$$) {
  my ($targets, $outfd, $target_names_to_deps, $target_names_to_labels, $target_names) = @_;

  $outfd //= STDOUT;
  # Optimization: if the caller already assembled an array of all target names,
  # we can reuse this array here. If not, we'll just regenerate it:
  $target_names //= [ sort keys %{$targets} ];

  $target_names_to_deps //= targets_to_dep_lists($targets);
  $target_names_to_labels //= target_dep_lists_to_printable_tree_labels($targets, $target_names_to_deps, $target_names);

  my %visited = ( );

  printfd(STDERR, print_folder_tab($R.'Implicit Targets (source files, Makefiles, etc)'));

  my $implicit_targets_pseudo_root_node = [ $R.'Implicit Targets' ];

  foreach $name (@$target_names) {
    my $t = $targets->{$name};
    #
    # print all of these up front, since they 
    # have no deps and just clutter the output:
    #
    next if ($t->{type} ne 'implicit');

    push @$implicit_targets_pseudo_root_node, subst_path_prefix_strings($t->{name}, $Y);
  }

  print_tree($implicit_targets_pseudo_root_node);
  $implicit_targets_pseudo_root_node = undef; # let it be freed!

  foreach $name (@$target_names) {
    next if ($name =~ /^\.[A-Z]+/oax);
    my $t = $targets->{$name};
    next if ($t->{type} eq 'implicit'); # we already printed these before
    %visited = ( );
    print_dependency_tree_from_target_deps_and_labels($t, $name, 
      $target_names_to_deps, $target_names_to_labels, $outfd, \%visited);
  }
}

1;
