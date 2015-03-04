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
use MTY::Display::TreeBuilder;
use MTY::Display::DataStructures;

use MTY::ListDeps::Config;
use MTY::ListDeps::Source;

#
# Plugins:
#
use MTY::ListDeps::Perl;
use MTY::ListDeps::C;
use MTY::ListDeps::Makefile;
# use MTY::ListDeps::ShellScript;
# use MTY::ListDeps::Python;
# use MTY::ListDeps::ELFBinary;
# use MTY::ListDeps::RPMPackage;
# use MTY::ListDeps::ConfFile;

use MTY::ListDeps::OutputFormat;

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

#
# Using all collected metadata on all known sources, construct a generic
# hash for dependencies of the specified type which maps any given filename
# (the hash key) to an array of other filenames on which it depends. We'll
# construct a separate hash in this format for each of the dependency types
# (i.e. symbolic, direct, recursive, inverse) the user has requested. These
# hashes are then passed to the output format plugins for formatting.
#

sub format_and_print_output($+) {
  my ($fd, $outspec) = @_;

  my $top_level_source_filenames = [
    sort 
    map { $_->{filename} } 
    grep { ($show_deps_for_every_file_found || $_->{explicitly_listed}) } @sources
  ];

  my @dep_type_to_hash_of_dep_lists = ( );

  my @selected_dep_types = filter_pairs(
    $show_symbolic_deps => SYMBOLIC_DEPS,
    $show_direct_deps => DIRECT_DEPS,
    $show_all_deps => RECURSIVE_DEPS,
    $show_inverse_deps => INVERSE_DEPS);

  foreach my $deptype (@selected_dep_types) {
    my $filenames_to_dep_lists = { };
    $dep_type_to_hash_of_dep_lists[$deptype] = $filenames_to_dep_lists;

    foreach my $source (@sources) {
      my $filename = $source->{filename};
      my $deps = $source->get_deps_by_type($deptype);
      $filenames_to_dep_lists->{$filename} = 
        [ map { filename_of_source($_) } @$deps ];
    }

    $filenames_to_dep_lists->{(ALL_SELECTED_SOURCES_KEY)} = 
      $top_level_source_filenames;
  }

  my $func = $outspec->{function};

  foreach my $deptype (@selected_dep_types) {
    my $filenames_to_dep_lists = $dep_type_to_hash_of_dep_lists[$deptype];
    #use DDS; pp $filenames_to_dep_lists;
    
    my @out = $func->($outspec, $top_level_source_filenames, 
          $filenames_to_dep_lists, \%filename_to_source, $deptype);

    printfd($fd, join(NL, @out));
  }
}

sub adjust_end_of_includes_pragma() {
  printfd(STDERR, print_folder_tab(G.'Adjusting '.K.left_quote.C.'#pragma end_of_includes'.K.right_quote.' markers:', G_1_2), NL);

  foreach my $source (@sources) {
    next if (!$source->{explicitly_listed});
    my $filename = $source->{filename};
    my $newcode = $source->adjust_end_of_includes_pragma();
    if (defined $newcode) {
      if ($print_code_to_stdout) {
        printfd(STDOUT, $newcode);
      } else {
        if (write_file_safely($filename, $newcode)) {
          printfd(STDERR, ' '.G.checkmark.' '.Y.'Saved adjusted source code back into ', 
                  format_filesystem_path($filename), NL);
        } else {
          warning('Could not write updated source code back to ', $filename, 
                  '; original file has not been modified.');
        }
      }
    }
  }
}

sub main {
  my ($filenames, $invalid_option_indexes, $command_line_option_values) = 
    parse_listdeps_command_line(@_);

  my $cache = (defined $cache_file_name) 
    ? retrieve_all_cached_metadata() : undef;

  configure_global_settings($cache);
  printdebug{'Ready to read ', scalar(@$filenames), ' sources'};

  printfd(STDERR, $listdeps_banner, NL) if (
    $show_tree || $show_supported_file_types || 
    $adjust_end_of_includes_pragma);
  
  if ($show_supported_file_types) {
    show_supported_file_types();
    return 0;
  }
  
  foreach my $filename (@$filenames) {
    $filename = resolve_path($filename);
    my $source = read_source_and_instantiate_by_type($filename);
    next if (!defined $source);
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

  my @all_source_filenames = sort keys %filename_to_source;

  my $longest_prefix = longest_common_path_prefix(@all_source_filenames);
  register_path_prefixes($longest_prefix => 'prefix') if (length ($longest_prefix // ''));

  if ($adjust_end_of_includes_pragma) {
    adjust_end_of_includes_pragma();
  } else {
    # this should be checked by parse_listdeps_command_line():
    die if (!defined $output_format_spec);

    format_and_print_output(STDOUT, $output_format_spec);
  }

  if (is_there($cache_file_name)) {
    my $cache = ($disable_deps_cache) ? { } : prepare_to_store_sources_to_cache_file();

    foreach my $plugin (@plugins) {
      $plugin->prepare_to_store_global_data_into_cache_file($cache);
    }

    store_all_cached_metadata($cache);
  }
    
  return 0;
}

1;
