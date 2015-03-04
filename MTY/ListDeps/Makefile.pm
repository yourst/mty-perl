#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::ListDeps::Makefile: plugin for Makefiles
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::ListDeps::Makefile;

use MTY::ListDeps::Source;
use parent qw(MTY::ListDeps::Source);
use MTY::ListDeps::Config;

use MTY::Common::Common;
use MTY::Common::Strings;
use MTY::Common::Hashes;
use MTY::Common::CommandLine;
use MTY::Filesystem::Files;
use MTY::RegExp::PerlSyntax;
use MTY::Filesystem::SearchableDirList;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
#pragma end_of_includes

my $makefile_end_of_includes_re = 
  qr{(?> ^ \# (pragma) \s++ (end_of_includes) \b
     .*+ \Z)}oamsx;

my $makefile_comment_re = 
  qr{(?<! \\) \# \N*+ \n}oamsx;

my $makefile_include_directive_re =
  qr{^ \ *+ ([s-]?) include \s*+ ([^\#\n]++)}oamsx;

my $makefile_deps_re = 
  qr{(?|
       (?> () () $makefile_comment_re) |
       (?> $makefile_include_directive_re)
     )
  }oamsx;

my $makefile_interp_names = [ '/usr/bin/make', '/usr/local/bin/make' ];

my $makefile_emacs_modes = [ qw(makefile makefile-gmake) ];

use constant {
  COMMON_MAKEFILE_SOURCE_TYPE_FLAGS => SOURCE_FLAG_INTERPRETED | SOURCE_FLAG_INVARIANT_SYMBOLIC_DEPS_TO_FILENAMES,
};

my $supported_source_types = {
  makefile => {
    description => 'Makefile',
    flags => SOURCE_FLAG_INTERPRETED | SOURCE_FLAG_INVARIANT_SYMBOLIC_DEPS_TO_FILENAMES,
    suffixes => [ qw(mk make makefile) ],
    filenames => [ qw(Makefile makefile) ],
    interps => [ 'make', '/usr/bin/make', '/usr/local/bin/make' ],
    emacs_modes => [ qw(makefile makefile-gmake) ],
    tree_node_symbol => script_m,
  },
};

my @makefile_include_leading_dirs = ( getcwd() );
my @makefile_include_dirs = ( );
my @makefile_include_trailing_dirs = ( '/usr/local/include', '/usr/gnu/include', '/usr/include' );

my $command_line_options = {
  'make-include-dir' => [ \@makefile_include_dirs, OPTION_LIST, [ qw(makeinc makedir) ] ],
};

my @options_relevant_to_cache_validity =
  qw( ); # qw(make-include-dir);

my $option_descriptions = [
  'make-include-dir' => 'List of directories to search for included makefiles (in addition to defaults)',
];

my $searchable_makefile_include_dirs;

noexport:; sub configure($++) {
  my ($plugin, $command_line_option_values, $filenames) = @_;

  @makefile_include_dirs = (
    @makefile_include_leading_dirs, 
    @makefile_include_dirs, 
    @makefile_include_trailing_dirs
  );

  $searchable_makefile_include_dirs = 
    MTY::Filesystem::SearchableDirList->new([ @makefile_include_dirs ], 'makefile_include_dirs');

  return 1;
}

INIT {
  printdebug{__PACKAGE__, ' initializing'};

  register_file_type_plugin(
    'Makefile',
    __PACKAGE__,
    $supported_source_types,
    $command_line_options,
    $option_descriptions,
    @options_relevant_to_cache_validity);
};

method:; sub new($$$;$$) { # (constructor)
  my ($class, $filename, $code, $type, $parent) = @_;

  my %all_deps = ( );

  my $suffix = final_suffix_without_dot_of($filename);
  $type = 'makefile';

  while ($code =~ /$makefile_deps_re/oamsxg) {
    my ($silent, $makefile) = ($1, $2);
    # skip package or use clauses within comments, strings, POD docs, etc.:
    next if (!length $makefile); 

    $all_deps{$makefile} = 1;
    if ($verbose) { printfd(STDERR, 'include'.((length $silent) ? ' ('.$silent.')' : '').' '.$makefile.NL); }
  }

  my $direct_symbolic_deps = [ sort keys %all_deps ];

  my $this = MTY::ListDeps::Source->new($filename, $code, $type, $direct_symbolic_deps, $parent);

  # Set file type specific attributes:
  # setfields $this, ...

  return bless $this, $class;
}

method:; sub resolve_symbolic_dep_to_filename(+$) {
  my ($this, $symdep) = @_;

  return $searchable_makefile_include_dirs->get($symdep);
}

1;
