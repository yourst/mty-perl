#!/usr/bin/perl -w
# -*- cperl -*-

package MTY::ListDeps::C;

use MTY::ListDeps::Source;
use parent qw(MTY::ListDeps::Source);
use MTY::ListDeps::Config;

use MTY::Common::Common;
use MTY::Common::Strings;
use MTY::Common::Hashes;
use MTY::Common::CommandLine;

use MTY::Filesystem::Files;
use MTY::Filesystem::SearchableDirList;

use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;

use MTY::RegExp::CxxREs;
use MTY::RegExp::Numeric;
use MTY::System::POSIX;
#pragma end_of_includes

noexport:; use constant {
  c_symbol => medium_large_c, # roman_numeral_c,
  h_symbol => lowercase_medium_h, # italic_lowercase_h
  plus_plus_symbol => superscript_small_plus.superscript_small_plus, # superscript_plus
  preprocessed_symbol => p_in_circle, # p_in_circle
};

my $c_source_type = {
  description => 'C source',
  flags       => SOURCE_FLAG_COMPILABLE | SOURCE_FLAG_PROGRAM,
  suffixes    => [ 'c' ],
  emacs_modes => [ 'c' ],
  tree_node_symbol => C.c_symbol.'  ',
};

my $c_header_source_type = {
  description => 'C header',
  flags       => SOURCE_FLAG_INCLUDABLE, 
  suffixes    => 'h',
  emacs_modes => [ 'c.h' ],
  tree_node_symbol => M.h_symbol.'  ',
};

my $c_preproc_source_type = {
  description => 'C preprocessed source',
  flags       => SOURCE_FLAG_PREPROCESSED | SOURCE_FLAG_COMPILABLE | SOURCE_FLAG_NO_DEPS,
  suffixes    => [ 'i' ],
  emacs_modes => [ 'c' ],
  tree_node_symbol => R.preprocessed_symbol.c_symbol.' ',
};

my $cpp_source_type = { 
  description => 'C++ source',
  flags       => SOURCE_FLAG_COMPILABLE | SOURCE_FLAG_PROGRAM,
  aliases     => [ qw(c++ cxx) ],
  suffixes    => [ qw(cpp c++ cxx cc C) ],
  emacs_modes => [ 'c++' ],
  tree_node_symbol => G.c_symbol.plus_plus_symbol,
};

my $cpp_header_source_type = {
  description => 'C++ header',
  flags       => SOURCE_FLAG_INCLUDABLE,
  aliases     => [ qw(c++.h h++ hxx hpp hh) ],
  suffixes    => [ qw(h h++ hpp hxx hh h) ],
  emacs_modes => [ 'c++.h' ],
  tree_node_symbol => Y.h_symbol.plus_plus_symbol,
};

my $cpp_preproc_source_type = { 
  description => 'C++ preprocessed source', 
  flags       => SOURCE_FLAG_PREPROCESSED | SOURCE_FLAG_COMPILABLE | SOURCE_FLAG_NO_DEPS, 
  aliases     => [ qw(c++.i cppi) ],
  suffixes    => [ qw(ii i++ cppi I) ],
  emacs_modes => [ 'c++'],
  tree_node_symbol => B.preprocessed_symbol.c_symbol.plus_plus_symbol,
};
  
my $supported_source_types = {
  c => $c_source_type,
  c_header => $c_header_source_type,
  c_preproc => $c_preproc_source_type,
  cpp => $cpp_source_type,
  cpp_header => $cpp_header_source_type,
  cpp_preproc => $cpp_preproc_source_type,
};

my $no_default_includes = 0;
my @extra_include_dirs = ( );
my @extra_quoted_include_dirs = ( );

my @c_include_dirs = ( );
my @c_quoted_include_dirs = ( );
my @cxx_include_dirs = ( );
my @cxx_quoted_include_dirs = ( );

my $searchable_c_include_dirs;
my $searchable_c_quoted_include_dirs;
my $searchable_cxx_include_dirs;
my $searchable_cxx_quoted_include_dirs;

# this can be set via the command line options:
my $recheck_default_c_cxx_compiler_include_paths = 0;

# this must be either 'gcc' or 'clang':
my $c_cxx_compiler = 'gcc';
my $c_cxx_compiler_base_dir = undef;
my $cxx_base_include_dir = undef;

my $default_c_include_paths = undef;
my $default_cxx_include_paths = undef;

my $c_defines = { };
my $cxx_defines = { };

my %specified_defines = ( );

my $DEBUG = 0;

my $command_line_options = {
  'compiler' => [ \$c_cxx_compiler, OPTION_VALUE_REQUIRED ],
  'gcc' => [ \$c_cxx_compiler, 0, [ 'g++' ], 'gcc' ],
  'clang' => [ \$c_cxx_compiler, 0, [ 'clang++' ], 'clang' ],
  'recheck-include-paths' => [ \$recheck_default_c_cxx_compiler_include_paths ],
  'no-default-includes' => [ \$no_default_includes ],
  'I' => [ \@extra_include_dirs, OPTION_VALUE_REQUIRED | OPTION_APPEND_REPEATS | OPTION_NO_SEPARATOR_BEFORE_VALUE, [ 'c-include-dir' ] ],
  'iquote' => [ \@extra_quoted_include_dirs, OPTION_VALUE_REQUIRED | OPTION_APPEND_REPEATS, [ 'c-quoted-include-dir' ] ],
  'D' => [ \%specified_defines, OPTION_VALUE_REQUIRED | OPTION_APPEND_REPEATS | OPTION_NO_SEPARATOR_BEFORE_VALUE, [ 'define' ] ],
};

my @options_relevant_to_cache_validity =
  qw(compiler no-default-includes I iquote D);

my $option_descriptions = [
  'compiler' => 'C/C++ compiler executable name',
  'gcc' => 'short for "-compiler gcc"',
  'clang' => 'short for "-compiler clang"',
  'recheck-include-paths' => 'Ignore any previously cached C/C++ include paths, and re-invoke the compiler to refresh this cached data',
  'no-default-includes' => 'Omit default built-in compiler include paths (e.g. /usr/include, /usr/lib/gcc/.../, etc)',
  'I' => 'Append the specified directory to the C/C++ include path (for #include <filename.h>)',
  'iquote' => 'Append the specified directory to the C/C++ quoted include path (for #include "filename.h")',
  'D' => 'Define a C/C++ preprocessor definition used by #ifdef or #ifndef blocks which contain conditional includes',
];

my $deferred_setup_complete = 0;

method:; sub deferred_setup(+) {
  my ($this) = @_;

  return 1 if ($deferred_setup_complete);

  $searchable_c_include_dirs = MTY::Filesystem::SearchableDirList->new(\@c_include_dirs, 'c_include_dirs');
  $searchable_cxx_include_dirs = MTY::Filesystem::SearchableDirList->new(\@cxx_include_dirs, 'cxx_include_dirs');
  $searchable_c_quoted_include_dirs = MTY::Filesystem::SearchableDirList->new(\@c_quoted_include_dirs, 'c_quoted_include_dirs');
  $searchable_cxx_quoted_include_dirs = MTY::Filesystem::SearchableDirList->new(\@cxx_quoted_include_dirs, 'cxx_quoted_include_dirs');

  register_path_prefixes($cxx_base_include_dir, SYSTEM_PATH_PREFIX_COLOR.'c++inc') if (defined $cxx_base_include_dir);
  register_path_prefixes($c_cxx_compiler_base_dir.'/include', COMPILER_PATH_PREFIX_COLOR.$c_cxx_compiler.'inc');
  register_path_prefixes('/usr/include' => SYSTEM_PATH_PREFIX_COLOR.'inc');
  register_path_prefixes('/usr/local/include' => SYSTEM_PATH_PREFIX_COLOR.'localinc');

  return 0;
}

noexport:; sub configure($+++) {
  my ($plugin, $command_line_option_values, $filenames, $cache) = @_;

  if ($no_default_includes) {
    $default_c_include_paths = [ ];
    $default_cxx_include_paths = [ ];
    $c_defines = { };
    $cxx_defines = { };
  } else {
    get_default_c_cxx_compiler_include_paths($cache);
  }

  push @c_include_dirs, @extra_include_dirs, @$default_c_include_paths;
  push @cxx_include_dirs, @extra_include_dirs, @$default_cxx_include_paths;
  @c_quoted_include_dirs = @extra_quoted_include_dirs;
  @cxx_quoted_include_dirs = @extra_quoted_include_dirs;

  if (is_debug) {
    printdebug{'c_include_dirs = ', NL, '  ', join(NL.'  ', @c_include_dirs), NL};
    printdebug{'c_quoted_include_dirs = ', NL, '  ', join(NL.'  ', @c_quoted_include_dirs), NL};
    printdebug{'cxx_include_dirs = ', NL, '  ', join(NL.'  ', @cxx_include_dirs), NL};
    printdebug{'cxx_quoted_include_dirs = ', NL, '  ', join(NL.'  ', @cxx_quoted_include_dirs), NL};
  }

  printdebug{'c_cxx_compiler_base_dir = ', $c_cxx_compiler_base_dir, NL};
  printdebug{'cxx_base_include_dir = ', $cxx_base_include_dir, NL};

  return 1;
}

my %cxx_suffixes = map { $_ => 1 } qw(cpp c++ cxx cc C h++ hpp hxx hh ii i++ cppi I);
my %header_suffixes = map { $_ => 1 } qw(h++ hpp hxx hh);
my %preproc_suffixes = map { $_ => 1 } qw(ii ipp i++ cppi I);

method:; sub new($$$;$$) { # (constructor)
  my ($class, $filename, $code, $type, $parent, $suffix, $interp, $emacs_mode) = @_;

  my %included_headers = ( );

  #
  # If this source has a parent source that included it, by definition 
  # this source must be an included header file (nonwithstanding the
  # rare practice of including .c/.cpp files in each other e.g. to
  # use different macro expansions for compile time code specialization).
  #
  my $is_header = (defined $parent) || (exists $header_suffixes{$suffix});

  #
  # If the top-level source file to be compiled (.c or .cpp) is C++,
  # we propagate this choice of language down the entire dependency
  # tree to all subsequent header files, since this matches the
  # semantics used by the compiler itself. Any headers that can be
  # included by both C and C++ code (e.g. various standard system
  # headers in /usr/include, etc.) are responsible for including
  # any necessary #ifdefs, extern "C" blocks, etc. where needed
  # to ensure all such headers will compile properly as C++ code.
  #

  my $parent_is_cxx = (defined $parent) ? $parent->{is_cxx} : undef;

  my $is_cxx = $parent_is_cxx // (
    (($emacs_modes // '') =~ '[Cc]\+\+') ||
    (exists $cxx_suffixes{$suffix}) ||
    ((defined $parent_suffix) && (exists $cxx_suffixes{$parent_suffix})) ||
    ($code =~ /$looks_like_cxx_re/oamsx));

  # Propagate this down the dependency tree from the top level .c/.cpp file:
  $this->{is_cxx} = $is_cxx;
  
  #
  # The file is considered to be preprocessed if and only if it has an
  # .i, .ii, etc. suffix *and* it lacks #include directives and/or other
  # similar constructs that are eliminated by preprocessing. (Note that
  # various settings for most compilers will still result in #defines,
  # #line markers, etc. being included even in preprocessed code).
  #

  my $is_preprocessed = (exists $preproc_suffixes{$suffix});
  my $header_include_guard = undef;
  my $ignored_ifdef_nesting_level = 0;
  my $pos_after_last_include = 0;
  my $defines = ($is_cxx) ? $cxx_defines : $c_defines;
  my $local_defines = { };

  while ($code =~ /$c_cxx_included_deps_re/oamsxg) {
    my ($directive, $angle_bracket_or_quote_or_line, $argument, $arg2) = ($1 // '', $2 // '', $3 // '', $4 // '');

    # gcc's cpp preprocessor avoids the standard '#line 123 "filename" 1 2 3...' syntax,
    # and instead uses its own shorthand form '# 123 "filename" 1 2 3...', but this lacks 
    # an actual directive name, so we manually set the directive to 'line' in this case:
    if ($angle_bracket_or_quote_or_line =~ /\A \d/oamsx) { $directive = 'line'; }

    # Skip over comments, strings, etc. which could contain character sequences 
    # otherwise considered to be preprocessor directives we're interested in:
    # (e.g. printf("... this is a string with #include <xyz.h> inside of it"),
    next if (!length $directive); 

    # printdebug{'  (@ offset ', pos($code), '): [', $directive, '] [', 
    #  $angle_bracket_or_quote_or_line, '] [', $argument, '] [', $arg2, ']'};

    next if (!length $directive); 

    if ($directive eq 'include') {
      if ($ignored_ifdef_nesting_level > 0) {
        # printdebug{$filename, ': #include ', $argument, ': ignoring since '.
        #   'ignored_ifdef_nesting_level is ', $ignored_ifdef_nesting_level};
        $ignored_ifdef_nesting_level++; 
      } else {
        # printdebug{$filename, ': #include ', $argument};
        $included_headers{$angle_bracket_or_quote_or_line.$argument.$arg2} = 
          $angle_bracket_or_quote_or_line;
      }
      $pos_after_last_include = pos($code);
      $is_preprocessed = 0; # preprocessed sources cannot have any #include directives
    } elsif ($directive eq 'pragma') {
      # fast path bail out so we don't even need to scan the rest of this file for #includes:
      if ($argument eq 'end_of_includes' || $argument eq 'end_of_headers') 
        { last if (!$adjust_end_of_includes_pragma); }
      elsif ($argument eq 'once') { $is_header = 1; }
    } elsif ($directive eq 'if') {
      my $ok = (exists $defines->{$argument}) || (exists $local_defines->{$argument});
      my $invert = ((length $angle_bracket_or_quote_or_line) > 0);
      $ok = (!$ok) if ($invert);

      if (!$ok) {
        $ignored_ifdef_nesting_level++;
        # printdebug{$filename, ': #if '.($invert ? 'not' : '').' ', $argument, ': '.
        #   'increment ignored_ifdef_nesting_level to ', $ignored_ifdef_nesting_level};
      }

      if ($argument eq $arg2) {
        $is_header = 1;
        $header_include_guard = $argument;
        $local_defines->{$arg2} = 1;
      }
    } elsif ($directive eq 'endif') {
      if ($ignored_ifdef_nesting_level > 0) { 
        $ignored_ifdef_nesting_level--; 
        # printdebug{$filename, ': #endif: decrement ignored_ifdef_nesting_level to ', 
        #   $ignored_ifdef_nesting_level};
      }
    } elsif ($directive eq 'define') {
      if (!$ignored_ifdef_nesting_level) {
        # printdebug{$filename, ': #define ', $argument, ' ', $arg2};
        $local_defines->{$argument} = $arg2;
      }
    } elsif ($directive eq 'line') {
      $is_preprocessed = 1;
    }
  }
  
  my $included_headers_list = [ sort keys %included_headers ];

  $type = 
    ($is_preprocessed) ? ($is_cxx ? $cpp_preproc_source_type : $c_preproc_source_type) :
    ($is_cxx) ? ($is_header ? $cpp_header_source_type : $cpp_source_type) :
    ($is_header ? $c_header_source_type : $c_source_type);

  # printdebug{$filename, ': type ', $type_name, ', is_cxx? ', ($is_cxx ? 1 : 0), 
  #   ', is_header? ', ($is_header ? 1 : 0), ', is_preprocessed? ', 
  #   ($is_preprocessed ? 1 : 0)};
  # printdebug{'  ', join(NL.'  ', @$included_headers_list)};

  my $this = MTY::ListDeps::Source->new(
    $filename, $code, $type, $included_headers_list, $parent,
    $suffix, $interp, $emacs_modes, $pos_after_last_include);

  setfields $this,
    is_cxx => $is_cxx,
    is_header => $is_header,
    is_preprocessed => $is_preprocessed,
    header_include_guard => $header_include_guard,
    local_defines => $local_defines;

  printdebug{'C source info for ', $filename, ':', NL, $this};
  
  return bless $this, $class;
}

#-----------------------------------------------------------------------------#
# C/C++ direct dependency extraction from .cpp, .c, .h files                  #
#-----------------------------------------------------------------------------#

#
# The '#include "quoted_filename.h"' directive uses slightly different 
# semantics compared to the '#include <filename.h>' directive, since
# the quoted form searches for the included file in the following order:
#
# 1. same directory as the parent file which is including this filename
# 2. each quoted include directory in order (i.e. gcc -iquote option)
# 3. if not yet found, revert to the semantics of '#include <filename>'.
#
# The semantics for '#include <filename.h>' are much simpler, 
# since only the list of include directories is searched.
#

method: sub resolve_symbolic_dep_to_filename(+$) {
  my ($this, $included_filename) = @_;

  my $parent_filename_invoking_include = $this->{filename};
  my $is_cxx = $this->{is_cxx};
  my $angle_bracket_or_quote_or_line;

  # printdebug{'resolve_symbolic_dep_to_filename(): included ', $included_filename};

  ($angle_bracket_or_quote, $included_filename) = 
    ($included_filename =~ /$c_cxx_included_filename_with_angle_bracket_or_quote_re/oamsx);

  my $include_dirs = ($is_cxx) ? $searchable_cxx_include_dirs : $searchable_c_include_dirs;
  my $quoted_include_dirs = ($is_cxx) ? $searchable_cxx_quoted_include_dirs : $searchable_c_quoted_include_dirs;

  my $found = undef;
  
  if ($included_filename =~ /^\//oamsx) {
    # it's an absolute path, so there's no need to search for it:
    $found = resolve_path($included_filename);
    goto out;
  }

  if ($angle_bracket_or_quote eq '"') {
    my $parent_file_dir = directory_of($parent_filename_invoking_include);

    $found = resolve_path($parent_file_dir.'/'.$included_filename);
    goto out if (defined $found);

    $found = $quoted_include_dirs->get($included_filename);
    goto out if (defined $found);
  }

  $found = $include_dirs->get($included_filename);

  out:

  # printdebug{'  searched for ', $included_filename, ' => ',
  #   ((defined $found) ? 'found in ', $found : 'not found'), NL, NL};

  return $found;
}

#
# The default C and C++ system-wide header include directories often
# differ significantly depending on the compiler (e.g. gcc uses various
# subdirectories in e.g. /usr/lib64/gcc/x86_64-gnu-linux/4.x, while
# clang uses another set of subdirectories in /usr/lib64/clang/3.x.x).
# These directories also heavily depend on the specific version of the
# compiler, the operating system distribution and obviously the case
# where the user installed the intended compiler version in a
# non-standard directory for some reason. Finally, C and C++ will
# often have different directories in their include paths.
#
# To help outside programs determine which directories to use, all
# of the supported compilers (at least gcc and clang) will print a
# list of their specific include paths when run with the options
# "-v -x<c|c++> -E /dev/null". These directories are intermixed
# with a variety of other irrelevant information, but at least
# the part wer're looking for is consistent (i.e. the lines
# '#include <...> search starts here" and likewise for "...".)
#
# To avoid wasting time re-running the C/C++ compiler every time 
# this code is invoked, the first time this is run, it will save
# the relevant directory lists to the file:
#
# /tmp/.default-<gcc|g++|clang|clang++-include-paths-for-user-<uid>
#
# It will then simply read this file at startup to reconstruct
# the proper include search paths. IMPORTANT: This means the user
# must invalidate this include directory cache whenever the
# specified compiler is updated or its directories have changed.
# This can be done by passing the -recheck-include-paths command 
# line option to this program.
#
noexport:; sub get_default_c_cxx_compiler_include_paths(+) {
  my ($cache) = @_;
  my $DEBUG = 1;
  
  if ($recheck_default_c_cxx_compiler_include_paths) {
    printdebug{'Cache invalidated for C/C++ because of '.
               'recheck_default_c_cxx_compiler_include_paths'};
    $c_cxx_compiler_base_dir = undef;
    $default_c_include_paths = undef;
    $default_cxx_include_paths = undef;
    $c_defines = undef;
    $cxx_defines = undef;
  }
  
  return if (defined $c_cxx_compiler_base_dir);

  # my $cache_file_name = '/tmp/.default-'.basename_of($c_cxx_compiler).'-include-paths-for-uid-'.getuid();

  if ((defined $cache) && ($c_cxx_compiler ne $cache->{c_cxx_compiler})) { 
    printdebug{'Cache invalidated because cached C/C++ compiler ',
               '(', $cache->{c_cxx_compiler}, ') != current compiler (',
               $c_cxx_compiler, ')'};
    $cache = undef; 
  }

  if (defined $cache) {
    ($c_cxx_compiler_base_dir, $cxx_base_include_dir,
     $default_c_include_paths, $default_cxx_include_paths, $c_defines, $cxx_defines) =
      getfields $cache, qw(c_cxx_compiler_base_dir cxx_base_include_dir 
                           default_c_include_paths default_cxx_include_paths c_defines cxx_defines);

    printdebug{'Cache provided the following C/C++ settings for ', $c_cxx_compiler, ' compiler:', NL,
               'c_cxx_compiler_base_dir = ', $c_cxx_compiler_base_dir, NL,
               'cxx_base_include_dir = ', $cxx_base_include_dir, NL,
               'default_c_include_paths = ', join(' ', @$default_c_include_paths), NL,
               'default_cxx_include_paths = ', join(' ', @$default_cxx_include_paths), NL,
               'c_defines = ', join(' ', sort keys %$c_defines), NL,
               'cxx_defines = ', join(' ', sort keys %$cxx_defines)};
    return;
  }

  my $compiler_base_dir_query_cmd = $c_cxx_compiler.' -print-file-name=';
  printdebug{'Regenerating C/C++ config: executing: ', $compiler_base_dir_query_cmd};
  $c_cxx_compiler_base_dir = qx{$compiler_base_dir_query_cmd};
  printdebug{'  Base directory query output was: ', $c_cxx_compiler_base_dir};

  if (!defined $c_cxx_compiler_base_dir) {
    warning('Cannot execute the specified C/C++ compiler '.
      '('.$compiler_base_dir_query_cmd.'): error was '.$!.'. '.
      'C/C++ support will be disabled until you fix this.');
    $c_cxx_compiler = undef;
    return;
  }

  chomp $c_cxx_compiler_base_dir;

  my $compiler_c_cxx_common_query_cmd = '-v -include features.h -dM -E - < /dev/null 2>&1';

  my $compiler_c_query_cmd = $c_cxx_compiler.' -xc -std=c11 '.$compiler_c_cxx_common_query_cmd;
  printdebug{'Regenerating C/C++ config: executing: ', $compiler_c_query_cmd};
  my $compiler_c_output = qx{$compiler_c_query_cmd};
  printdebug{'  C output was: ', $compiler_c_output};

  if (!defined $compiler_c_output) {
    die("Cannot invoke $compiler_c_query_cmd to obtain compiler's default include paths");
  }

  my $compiler_cxx_query_cmd = $c_cxx_compiler.' -xc++ -std=c++11 '.$compiler_c_cxx_common_query_cmd;
  printdebug{'Regenerating C/C++ config: executing: ', $compiler_cxx_query_cmd};
  my $compiler_cxx_output = qx{$compiler_cxx_query_cmd};
  printdebug{'  C++ output was: ', $compiler_cxx_output};

  if (!defined $compiler_cxx_output) {
    die("Cannot invoke $compiler_cxx_query_cmd to obtain compiler's default include paths");
  }

  my $compiler_include_paths_re = 
    qr{^ \#\Qinclude <...> search starts here:\E \n
       ((?> \s++ \N++ \n)*+)}oamsx;
  
  my $compiler_defines_re = 
    qr{^ \#define [\ \t]++ (\w++) [\ \t]++ 
       ((?> [^\n/]++ | / [^\*\/])*)
       \N*+ \n}oamsx;
  my $relevant_compiler_define_values_re = 
    qr{\A (?> \d++ | ) \Z}oamsx;

  $default_c_include_paths = [ ];
  $default_cxx_include_paths = [ ];

  if ($compiler_c_output =~ /$compiler_include_paths_re/oamsxg) {
    my ($include_paths) = $1;
    $default_c_include_paths = [ map { remove_leading_space($_) } split(/\n/, $include_paths) ];
  } else {
    warning($Y.$U.'ERROR: Could not find default C include paths in compiler output:'.
              $X.NL.$compiler_c_output.NL.NL);
    die("Unable to find default C include paths in compiler output");
  }
  
  while ($compiler_c_output =~ /$compiler_defines_re/oamsxg) { 
    my ($name, $value) = ($1, $2);
    $c_defines->{$name} = $value if ($value =~ $relevant_compiler_define_values_re);
  }
  
  if ($compiler_cxx_output =~ /$compiler_include_paths_re/oamsxg) {
    my ($include_paths) = $1;
    $default_cxx_include_paths = [ map { remove_leading_space($_) } split(/\n/, $include_paths) ];
  } else {
    warning($Y.$U.'ERROR: Could not find default C++ include paths in compiler output:'.
              $X.NL.$compiler_cxx_output.NL.NL);
    die("Unable to find default C++ include paths in compiler output");
  }

  while ($compiler_cxx_output =~ /$compiler_defines_re/oamsxg) { 
    my ($name, $value) = ($1, $2);
    $cxx_defines->{$name} = $value if ($value =~ $relevant_compiler_define_values_re);
  }
  
  foreach $path (@$default_c_include_paths) 
    { $path = resolve_path($path) // '/INCLUDE_PATH_DOES_NOT_EXIST/'; }

  foreach $path (@$default_cxx_include_paths) 
    { $path = resolve_path($path) // '/INCLUDE_PATH_DOES_NOT_EXIST/'; }
  
  my $cxx_base_include_dir_re = qr{/include/c\+\+/[\d\.]+/? \Z}oamsx;

  $cxx_base_include_dir = undef;

  foreach my $dir (@$default_cxx_include_paths) {
    printdebug{'cxx_base_include_dir = ', $cxx_base_include_dir, ': now checking ', $dir};
    if ((!defined $cxx_base_include_dir) && ($dir =~ /$cxx_base_include_dir_re/oamsx)) 
      { $cxx_base_include_dir = $dir; last; }
  }

  printdebug{'Caching default ', $c_cxx_compiler, ' C/C++ metadata:'};
  printdebug{'  c_cxx_compiler_base_dir = ', $c_cxx_compiler_base_dir};
  printdebug{'  cxx_base_include_dir = ', $cxx_base_include_dir};
  printdebug{'  default_c_include_paths = '.NL.'  '.join(NL.'  ', @$default_c_include_paths)};
  printdebug{'  default_cxx_include_paths = '.NL.'  '.join(NL.'  ', @$default_cxx_include_paths)};

  return 1;
}

sub prepare_to_store_global_data_into_cache_file(++) :method {
  my ($this, $cache) = @_;

  setfields $cache, (
    c_cxx_compiler => $c_cxx_compiler,
    c_cxx_compiler_base_dir => $c_cxx_compiler_base_dir, 
    cxx_base_include_dir => $cxx_base_include_dir,
    default_c_include_paths => $default_c_include_paths,
    default_cxx_include_paths => $default_cxx_include_paths,
    c_defines => $c_defines,
    cxx_defines => $cxx_defines);

  return 1;  
}

INIT {
  printdebug{__PACKAGE__, ' initializing'};

  register_file_type_plugin(
    'C/C++',
    __PACKAGE__,
    $supported_source_types,
    $command_line_options,
    $option_descriptions,
    @options_relevant_to_cache_validity);
};

1;
