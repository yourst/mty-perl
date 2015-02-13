#!/usr/bin/perl -w
# -*- cperl -*-
#
# lsdeps: 
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#
# List the dependencies required by numerous file types, including C, C++, 
# Perl, Python, Java, C#, shell scripts, makefiles, ELF executables and
# shared libraries, Linux kernel modules and more. Plugin modules can
# support virtually any file format capable of specifying dependencies on
# other files, either through explicit filenames or symbolic namespaces.
#
# Dependencies may be followed to several levels, from direct dependencies
# explicitly listed by each input file, to the target files corresponding
# to each symbolic or relative dependency, or the inverse dependencies
# of each file. 
#
# Direct dependencies may be extracted starting from files explicitly 
# listed on the command line, and all dependencies may optionally be
# discovered by recursively following the entire graph of dependent
# files, either within a project or extending to system wide libraries.
#
# The collected data can be presented in a variety of formats, including
# text based formats such as makefile compatible rules, makefile variable 
# assignments, tab delimited records, or user specified format templates.
#
# Alternatively, the dependency graph may be displayed in tree format or
# output to a .dot file for graphical rendering using Graphviz.
#
# Previously saved dependency list files can also be quickly updated by
# only parsing files which are newer than the saved dependency data.
#
# For full usage information, simply run 'lsdeps' without arguments.
#

package MTY::ListDeps::ListDeps;

use integer; use warnings; use Exporter qw(import);

use MTY::Common::Common;
use MTY::Common::Strings;
use MTY::Common::Hashes;
use MTY::Common::CommandLine;
use MTY::Common::Strings;

use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::SearchableDirList;

use MTY::RegExp::Strings;

use MTY::Display::Colorize;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;
use MTY::Display::Table;
use MTY::Display::Tree;
use MTY::Display::DataStructures;

use MTY::ListDeps::Config;
use MTY::ListDeps::Source;

use MTY::ListDeps::Perl;
use MTY::ListDeps::C;

#pragma end_of_includes

preserve:; our @EXPORT = qw(main);

my $dep_file_line_re = 
  qr{^ \s*+ 
     (?|
       (?> \w++ \[ ([^\[\]]++) \] \s*+ :=) |
       (?> \w++ \t ([^\t]++) \t) |
       (?> ((?> [^\:\\]++ | \\ .)++) \s*+ :)
     ) \s*+
     $line_with_optional_backslash_newlines_re
  }oamsx;

#
# The configure() static method is called *after* the command line has been 
# parsed and all configuration variables have been filled in.
#
# Subclasses should override this method, since the base class method below
# is intended to configure global state only.
#

sub main(+) {
  my ($filenames, $invalid_option_indexes, $command_line_option_values) = 
    parse_listdeps_command_line();

  my $cache = (defined $cache_file_name) 
    ? retrieve_all_cached_metadata() : undef;

  my @plugin_classes = map { $plugin_name_to_class{$_} } @plugins;

  foreach my $plugin (@plugin_classes) {
    if (!$plugin->configure($command_line_option_values, $filenames, $cache))
      { die("Plugin '$name' failed to initialize"); }
  }

  MTY::ListDeps::Source->configure($command_line_option_values, $filenames, $cache);

  if ($show_supported_file_types) {
    show_supported_file_types();
    return 0;
  }

  foreach my $filename (@$filenames) {
    $filename = resolve_path($filename);
    my $source = read_source_and_instantiate_by_type($filename);
    $source->{explicitly_listed} = 1;
    $source->resolve_symbolic_deps_to_filenames();
  }
  if ($find_recursive_deps) { collect_deps_recursively(@$filenames); }

  @sources = sort { $a->{filename} cmp $b->{filename} } (map { filename_to_source($_) } @sources);
  my @sorted_filenames = map { $_->{filename} } @sources;

  if ($show_all_files_found) 
    { prints('ALL_DEPS_OF_FILES := '.join(' ', @sorted_filenames).NL); }

  if ($show_inverse_deps) { update_all_inverse_deps(); }

  if ($find_recursive_deps) { resolve_all_recursive_deps(); }

  my %tree_key_to_deplist = ( );
  my %tree_key_to_label = ( );

  my @all_source_filenames = sort keys %filename_to_source;

  my $longest_prefix = longest_common_path_prefix(@all_source_filenames);
  register_path_prefixes($longest_prefix => 'prefix') if (length ($longest_prefix // ''));
  
  if ($show_tree) {
    #
    # Recursive deps make no sense for tree format, since the structure
    # of the tree itself depicts the recursion, so flattening it would
    # serve no purpose and would erroneously yield a two level tree:
    #
    my $deptype = 
      ($show_symbolic_deps) ? SYMBOLIC_DEPS :
      ($show_direct_deps) ? DIRECT_DEPS :
      ($show_inverse_deps) ? INVERSE_DEPS : DIRECT_DEPS;

    if (!defined $deptype) { die("Undefined dependency type $deptype"); }

    foreach my $source (@sources) {
      my $filename = $source->{filename};
      my $deps = $source->get_deps_by_type($deptype);
      $tree_key_to_deplist{$filename} = [ (map { filename_of_source($_) } @$deps) ];
      my $typespec = $source->{type};
      my $tree_node_symbol_cmd = $typespec->{tree_node_symbol_cmd} // arrow_tri;
      my $tree_node_symbol_dark_cmd = $typespec->{tree_node_symbol_dark_cmd} // arrow_open_tri;
      $tree_key_to_label{$filename} = [
        $tree_node_symbol_cmd,
        $source->condense_filename()
      ];
    }

    $tree_key_to_deplist{all} = ($show_deps_for_every_file_found) ?
      [ @sorted_filenames ] : $filenames;
    
    $tree_key_to_label{all} = C.U.'(All Specified Input Files)'.UX;

    my $tree = dependency_graph_to_tree('all', %tree_key_to_deplist, %tree_key_to_label);
    print_tree($tree);

    print(NL, print_folder_tab(Y.U.'Path Prefix Abbreviations:'.X));
    print(format_table(
      [ pairmap { [ (format_filesystem_path(strip_trailing_slash($a), undef, undef, 1).X, $b) ] }
          hash_sorted_by_keys_as_pair_array(%path_prefixes) ],
      row_prefix => '    ', 
      colseps => B.'  '.arrow_barbed.'  '.X,
      padding => K_1_2.dot_small,
    ));
    print(NL);
  } else {
    foreach my $source (@sources) {
      next if ((!$show_deps_for_every_file_found) && (!$source->{explicitly_listed}));
      my $filename = $source->{filename};
      if ($show_tree) {
        my $tree = dependency_graph_to_tree($filename, %tree_key_to_deplist, %tree_key_to_label);
        print_tree($tree);
      } else {
        my $out = '';
        
        $out .= $source->format_deps(SYMBOLIC_DEPS, $output_format).NL if ($show_symbolic_deps);
        $out .= $source->format_deps(DIRECT_DEPS, $output_format).NL if ($show_direct_deps);
        $out .= $source->format_deps(ALL_DEPS, $output_format).NL if ($show_all_deps);
        $out .= $source->format_deps(INVERSE_DEPS, $output_format).NL if ($show_inverse_deps);
        prints($out);
      }
    }
  }

  if (defined $cache_file_name) {
    my $cache = prepare_to_store_sources_to_cache_file();

    foreach my $plugin (@plugin_classes) {
      $plugin->prepare_to_store_global_data_into_cache_file($cache);
    }

    store_all_cached_metadata($cache);
  }
    
  return 0;
}

1;
