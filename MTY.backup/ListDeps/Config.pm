#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::ListDeps::Config
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::ListDeps::Config;
use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($debug $verbose @plugins RECURSIVE_DEPS DIRECT_DEPS $force_color $project_dir
     %dir_aliases INVERSE_DEPS SYMBOLIC_DEPS $show_all_deps %path_prefixes
     @output_formats get_path_prefix $cache_file_name $config_filename
     $enable_warnings $listdeps_banner $wrap_long_lines $one_dep_per_line
     $show_direct_deps @dep_type_to_name $show_inverse_deps
     $disable_deps_cache $output_format_name $output_format_spec
     $show_symbolic_deps %path_prefix_colors determine_file_type
     $find_recursive_deps %output_format_names %source_type_to_spec
     $show_all_files_found %plugin_name_to_class $include_external_deps
     %source_type_to_plugin register_path_prefixes register_output_formats
     $default_cache_file_name %path_prefix_dark_colors
     @dep_type_to_description ALL_SELECTED_SOURCES_KEY
     SYSTEM_PATH_PREFIX_COLOR EXTRA_PATH_PREFIX_COLOR_1
     EXTRA_PATH_PREFIX_COLOR_2 EXTRA_PATH_PREFIX_COLOR_3
     PROJECT_PATH_PREFIX_COLOR register_file_type_plugin
     show_supported_file_types store_all_cached_metadata
     $show_supported_file_types COMPILER_PATH_PREFIX_COLOR
     $show_metadata_cache_status parse_listdeps_command_line
     %plugin_name_to_source_types retrieve_all_cached_metadata
     register_command_line_options $adjust_end_of_includes_pragma
     $show_deps_for_every_file_found format_filename_with_path_prefix
     %path_prefix_branch_color_tree_cmd $user_defined_output_format_template
     STORED_METADATA_CACHE_FORMAT_VERSION configure_global_settings
     format_path_prefix_abbreviation_table
     $strip_project_dir_from_output_filenames
     @output_format_command_line_option_descriptions);

use MTY::Common::Common;
use MTY::Common::Strings;
use MTY::Common::Hashes;
use MTY::Common::CommandLine;

use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;

use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::ANSIColorREs;
use MTY::Display::TextInABox;
use MTY::Display::Tree;
use MTY::Display::Table;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::DataStructures;

use MTY::RegExp::FilesAndPaths;
use MTY::RegExp::PrefixStrings;
use MTY::RegExp::Strings;

use MTY::System::POSIX;
use MTY::System::Misc;

use MTY::Filesystem::SearchableDirList;

use Storable qw(store retrieve store_fd fd_retrieve);
#pragma end_of_includes

#-----------------------------------------------------------------------------#
# Command line options                                                        #
#-----------------------------------------------------------------------------#

our $show_symbolic_deps = 0;
our $show_direct_deps = 0;
our $show_all_deps = 0;
our $show_inverse_deps = 0;

our $show_all_files_found = 0;

our $find_recursive_deps = 0;
our $include_external_deps = 0;
our $show_deps_for_every_file_found = 0;

our $user_defined_output_format_template = undef;
our $output_format_name = undef;
our $strip_project_dir_from_output_filenames = 1;
our $adjust_end_of_includes_pragma = 0;

our $wrap_long_lines = undef;
our $one_dep_per_line = 0;
our $force_color = 0;

our $default_cache_file_name = '/tmp/.lsdeps-cache-'.get_user_name();

our $cache_file_name = $default_cache_file_name;
our $disable_deps_cache = 0;
our $show_metadata_cache_status = 0;

our $project_dir = undef;
our $enable_warnings = 0;
our $verbose = 0;
our $debug = 0;
our $show_supported_file_types = 0;
our $config_filename = undef;

our %dir_aliases = ( );

use constant enum qw(SYMBOLIC_DEPS DIRECT_DEPS RECURSIVE_DEPS INVERSE_DEPS);
our @dep_type_to_name = qw(symdeps deps alldeps invdeps);
our @dep_type_to_description = qw(symbolic direct all inverse);

our @output_formats = ( );
our %output_format_names = ( );

our $output_format_spec = undef;

our %source_type_overrides = ( );

our %override_source_type_of_filename;
our %override_source_type_of_suffix;

#
# This is filled in by register_output_formats()
#
my @output_format_command_line_options = ( );

my %command_line_options = (
  META_OPTION_NON_OPTIONS_REQUIRED, 1,
# META_OPTION_MUTUALLY_EXCLUSIVE_REQUIRED, [ qw(direct all inverse found) ],

  # Type of Dependencies to Include
  'symbolic' => [ \$show_symbolic_deps, 0, [ qw(s sym symdeps) ] ],
  'direct' => [ \$show_direct_deps, 0, [ 'd' ] ],
  'all' => [ \$show_all_deps, 0, [ qw(a all-deps) ] ],
  'inverse' => [ \$show_inverse_deps, 0, [ qw(i inv inv-deps reverse rev rev-deps) ] ],
  'found' => [ \$show_all_files_found, 0, [ qw(show-found-files all-files) ] ],

  # Scope of Dependencies to Include
  'recursive' => [ \$find_recursive_deps, 0, [ qw(r recurse follow) ] ],
  'external' => [ \$include_external_deps, 0, 'x' ],
  'complete' => [ \$show_deps_for_every_file_found, 0, [ qw(c show-every-file-found) ] ],

  # Output Format (mutually exclusive)
  include_options(@output_format_command_line_options),
  'endmarker' => [ \$adjust_end_of_includes_pragma, 0, [ qw(eoi adjust-end-of-includes) ] ],

  # Fine Tuning of Output Format
  'strip-project-dir' => [ \$strip_project_dir_from_output_filenames, 0, [ qw(strip-proj-dir projrel rel nodir) ] ],
  'wrap-long-lines' => [ \$wrap_long_lines, OPTION_VALUE_OPTIONAL, [ qw(wrap) ], 78 ],
  'one-dep-per-line' => [ \$one_dep_per_line, 0, [ qw(one-per-line multiline multi-line) ] ],

  # Caching Options
  'cache' => [ \$metadata_cache_filename, OPTION_VALUE_REQUIRED, [ ] ],
  'nocache' => [ \$disable_deps_cache, 0, [ ] ],
  'show-cache-status' => [ \$show_metadata_cache_status, 0, [ ] ],

  # Miscellaneous Options
  'type' => [ \%source_type_overrides, OPTION_HASH, [ qw(. source-type override-type)] ],
  'projectdir' => [ \$project_dir, OPTION_VALUE_REQUIRED, [ qw(p project proj projdir dir sourcedir)] ],
  'dir-alias' => [ \%dir_aliases, OPTION_LIST, [ qw(da diralias) ] ],
  'list-types' => [ \$show_supported_file_types, 0, [ qw(types) ] ],
  'config' => [ \$config_filename, 0, [ qw(conf cfg) ] ],
  'force-color' => [ \$force_color ],
  'nowarnings' => [ \$enable_warnings, OPTION_ASSIGN_BOOL, [ qw(nowarn w) ], 0, 1],
  'verbose' => [ \$verbose, 0, [ qw(v) ] ],
  'debug' => [ \$debug, 0, [ qw(dbg) ] ],
);

our $listdeps_banner = print_banner(
  fg_color_rgb(64, 255, 180).'lsdeps',
  Y.'List dependencies required by C/C++, Perl, shell scripts, Makefiles and more', PURPLE);

our @output_format_command_line_option_descriptions = ( );

my @command_line_option_descriptions = (
  [ OPTION_HELP_LITERAL ] => $listdeps_banner,

  [ OPTION_HELP_SYNTAX ] => 
    C_3_4.'-'.C.U.'dep-type-option(s)'.UX.C_1_2.elipsis_three_dots.' '.
    G_3_4.'-'.G.U.'scope-option(s)'.UX.G_1_2.elipsis_three_dots.' '.
    Y_3_4.'-'.Y.U.'format-option'.UX.' '.
    M_3_4.'-'.M.U.'misc-option(s)'.UX.M_1_2.elipsis_three_dots.' '.
    LIGHTBLUE.U.'source1'.C.'.c'.UX.LIGHTBLUE.' '.U.'source2'.C.'.cpp'.UX.' '.
    LIGHTBLUE.U.'source3'.C.'.pm'.UX.' '.LIGHTBLUE_3_4.elipsis_three_dots,

  [ OPTION_HELP_CATEGORY, C_2_3 ] => U.C.'Types'.UX.C_3_4.' of Dependencies to Include',
  'symbolic' => 'List original symbolic dependencies before resolving to filenames',
  'direct' => 'List only directly included dependencies',
  'all' => 'List all direct and indirect (recursive) dependencies',
  'inverse' => 'List inverse dependencies (the other files which depend on each file)',
  'found' => 'List the complete set of files located during recursive traversal',

  [ OPTION_HELP_CATEGORY, G_2_3 ] => U.G.'Scope'.UX.G_3_4.' of Dependencies to Include',
  'recursive' => 'Recursively find all dependencies of all included files (implied by -all and -found options)',
  'external' => 'Show external included files (i.e. those provided by the compiler in /usr/include, /usr/lib/perl5/5.x.x/, etc) in addition to included files within the target project',
  'complete' => 'Print dependencies for complete list of sources found recursively (instead of just those on the command line)',

  [ OPTION_HELP_CATEGORY, Y_2_3 ] => U.Y.'Format'.UX.Y_3_4.' of output (mutually exclusive)',
  include_option_descriptions(@output_format_command_line_option_descriptions),
  'endmarker' => 'Insert or move the "#pragma end_of_includes" marker as needed, and print the adjusted source code',

  [ OPTION_HELP_CATEGORY, ORANGE_2_3 ] => ORANGE.U.'Fine Tuning'.UX.ORANGE_3_4.' of Output Formats',
  'strip-project-dir' => 'Remove the project directory path from any output filenames containing it',
  'wrap-long-lines' => 'Wrap long lines to the specified number of columns (wrapped lines will end with a backslash)',
  'one-dep-per-line' => 'If a given source file has multiple dependencies, list the source filename and one of its dependencies each on a separate line',

  [ OPTION_HELP_CATEGORY, M_2_3 ] => M.'Persistent Metadata Caching',
  'cache' => 'Filename for the persistent metadata cache (default is ".depscache" in the project directory)',
  'nocache' => 'Do not persistently cache dependency metadata (compiler configuration data will still be cached)',
  'show-cache-status' => 'Show any files which were newer than the cached data or otherwise could not use the cache',

  [ OPTION_HELP_CATEGORY, M_2_3 ] => M.'Miscellaneous Options',
  'type' => 'Override automatically determined source file type, specified as either ".ext=type" or "*.ext=type" '.
    'to force all files with suffix ".ext" to be processed as type "type" (use -list-types for details), or as '.
    '"filename.ext=type" to override just one file\'s. type. This option may appear multiple times and/or multiple '.
    'suffix=type pairs can be separated by commas.',
  'projectdir' => 'Project directory (to differentiate external vs internal dependencies; default is the current directory when invoked)',
  'dir-alias' => 'Specify a short abbreviation for paths starting with the specified prefix (to extend built-in path abbreviations)',
  'list-types' => 'List all supported file types and their attributes and capabilities',
  'config' => 'Read initial options from specified configuration file (command line options override these); by default will also read '.
    '.lsdeps.conf in each source file\'s directory, the current directory, your home directory and /etc/lsdeps.conf',
  'force-color' => 'Force printing output in color',
  'nowarnings' => 'Do not show any warning messages',
  'verbose' => 'Print additional information for each file processed and as other actions occur',
  'debug' => 'Print numerous debug messages beyond those printed by -verbose',

  [ OPTION_HELP_CATEGORY, G_2_3, ALIGN_CENTER ] => G.'Options specific to each file type',
);

#-----------------------------------------------------------------------------#
# Source Type Plugin Registry:                                                #
#-----------------------------------------------------------------------------#

our @plugins = ( );
our %plugin_name_to_class = ( );
our %plugin_name_to_source_types = ( );
our %source_type_to_spec = ( );
our %source_type_to_plugin = ( );

my @interps_to_add = ( );
my %suffix_to_source_type = ( );
my %interp_to_source_type = ( );
my %emacs_mode_to_source_type = ( );

my @global_options_relevant_to_cache_validity = 
  qw(symbolic direct all inverse recursive external complete projectdir);

my %options_relevant_to_cache_validity = 
  (map { $_ => 1 } @global_options_relevant_to_cache_validity);

#-----------------------------------------------------------------------------#
# Register a source file type handler plugin:                                 #
#-----------------------------------------------------------------------------#

export:; sub register_file_type_plugin($$+;+++) {
  my ($plugin, $class, $source_types, 
      $plugin_command_line_options, $plugin_option_descriptions,
      $plugin_options_relevant_to_cache_validity) = @_;

  push @plugins, $class;
  $plugin_name_to_class{$plugin} = $class;
  $plugin_name_to_source_types{$plugin} = $source_types;
  
  while (my ($type, $typespec) = each %$source_types) {
    my ($description, $flags, $suffixes, $interps, $emacs_modes, $tree_node_symbol) =
      getfields $typespec, qw(description flags suffixes interps emacs_modes tree_node_symbol);

    if (exists $source_type_to_spec{$type}) { 
      warning("Source type $type is already defined; not redefining to plugin $plugin");
      next;
    }

    $typespec->{type} = $type;
    $typespec->{plugin} = $class;
    $source_type_to_spec{$type} = $typespec;
    $source_type_to_plugin{$type} = $plugin;

    foreach my $suffix (@$suffixes) { $suffix_to_source_type{$suffix} = $typespec; }

    #
    # Defer the wildcard expansion of interpreters until after we've loaded 
    # the cache state, since this is slow (it can require many filesystem 
    # accesses) and pointless (since the resolution of system wide wildcards
    # like "/usr/bin/perl*", "/bin/cpp*", etc. rarely if ever changes).
    #
    push @interps_to_add, (map { ($_ => $typespec) } @$interps);

    foreach my $emacs_mode (@$emacs_modes) { $emacs_mode_to_source_type{$emacs_mode} = $typespec; }

    $typespec->{tree_node_symbol_cmd} = [ TREE_CMD_SYMBOL, G.$tree_node_symbol ];
    $typespec->{tree_node_symbol_dark_cmd} = [ TREE_CMD_SYMBOL, 
      G_1_2.scale_rgb_fg_in_string($tree_node_symbol, RATIO_1_2) ];
  }

  if (defined $plugin_options_relevant_to_cache_validity) {
    foreach my $option (@$plugin_options_relevant_to_cache_validity)
      { $options_relevant_to_cache_validity{$option} = $class; }
  }

  register_command_line_options($plugin_command_line_options, $plugin_option_descriptions, $plugin);

  return 1;
}

noexport:; sub expand_interp_wildcards(+) {
  my ($cache) = @_;

  my $cached_interp_to_source_type = $cache->{interp_to_source_type};
  
  if (defined $cached_interp_to_source_type) {
    %interp_to_source_type = pairmap { 
      ($a => $source_type_to_spec{$b}) 
    } @$cached_interp_to_source_type;
  } else {
    %interp_to_source_type = pairmap {
      ($a !~ /$wildcard_re/oax) ? ($a => $b) : (map { $_ => $b } (glob $a));
    } @interps_to_add;
  }

  if (is_debug) {
    printdebug{'expand_interp_wildcards: interp_to_source_type = '};
    pairmap { printdebug{'  ', padstring($a, 40), ' => ', $b->{type}}; } %interp_to_source_type;
  }

  return 1;
}

my $shebang_interp_and_args_re = 
  qr{\A \#\! \s*+ (\S++) \s*+ (\N*+) \n}oamsx;

my $emacs_mode_decl_re =  
  qr{^ \s*+
     (?> [\#\;] | \/ [\*\/]) 
     \N*?
     \-\*\- \s++ (\S++) \s++ \-\*\-}oamsx;

sub determine_file_type($$) {
  my ($code, $filename) = @_;
  my $typespec = undef;

  my $suffix = final_suffix_without_dot_of($filename) // '';
  my ($interp, $interp_args) = ($code =~ /$shebang_interp_and_args_re/oamsx);
  my ($emacs_mode) = ($code =~ /$emacs_mode_decl_re/oamsx);
  my @results = ($suffix, $interp, $emacs_mode);

  my $override_type = 
    $override_source_type_of_filename{$filename} //
    $override_source_type_of_suffix{$suffix};

  if (defined $override_type) { return ($override_type, @results); }

  # 
  # First use the #!/path/to/interpreter within the code as the most reliable
  # indication of which plugin can handle this file, since obviously a program
  # isn't going to contain e.g. "#!/usr/bin/perl" (the so-called "shebang"
  # header on its first line) unless it's an actual Perl program.
  #
  # Unfortunately this doesn't work for libraries like Perl modules, etc.,
  # which generally aren't executable and thus don't need a shebang.
  #
  # We also need to employ more sophisticated heuristics to identify statically
  # compiled sources like C/C++. This is especially important in the case of
  # like C/C++ *.h header files, since C and C++ use different sets of include
  # paths and search semantics, yet it's quite hard to distinguish C vs C++ 
  # code when the .h suffix is often used for both languages. 
  #
  # To handle situations like this, the appropriate plugin (which generally
  # needs to handle all of the closely related languages that a given file
  # could be written in, as determined initially by its suffix and a few
  # other generic tests below) will need to actually match the code against
  # various regexps for e.g. keywords found in only one of the languages,
  # although those keywords should ideally be mandatory in any properly 
  # structured source code so as to avoid ambiguities.
  #

  if (is_there($interp)) {
    $typespec = $interp_to_source_type{$interp};
    return ($typespec, @results) if (defined $typespec);
  }

  #
  # If the source code contains an explicit '-*- emacs-mode-here -*-' specifier
  # for Emacs to use while editing it, use this as the next most reliable type,
  #

  if (is_there($emacs_mode)) {
    $typespec = $emacs_mode_to_source_type{$emacs_mode};
    return ($typespec, @results) if (defined $typespec);
  }

  #
  # Use the filename suffix to find which plugin handles this file type:
  #

  if (is_there($suffix)) {
    $typespec = $suffix_to_source_type{$suffix};
    return ($typespec, @results) if (defined $typespec);
  }

  warning('Cannot find any file type plugin to process the file "', $filename, '"');

  return;
}

#-----------------------------------------------------------------------------#
# Show a listing of all plugins and their supported source file types:        #
#-----------------------------------------------------------------------------#

export:; sub show_supported_file_types() {
  my $tree_root = [ [ C.U.'Supported File Types'.X ] ];

  foreach my $plugin (sort keys %plugin_name_to_source_types) {
    my $class = $plugin_name_to_class{$plugin};
    my $source_types = $plugin_name_to_source_types{$plugin};
    
    my $plugin_node = [ 
      [
        [ TREE_CMD_SYMBOL, G.p_in_circle ],
        G.$plugin.' '.G_2_3.'('.$class.')',
      ]
    ];
    push @$tree_root, $plugin_node;

    foreach my $type (sort keys %$source_types) {
      my $spec = $source_types->{$type};

      my $spec_node = [
        [
          [ TREE_CMD_SYMBOL, arrow_tri, arrow_open_tri ],
          C.$spec->{type}
        ],
        $spec->{description},
        format_source_flags($spec->{flags}),
        join(' ', @{$spec->{suffixes} // [ ]}),
        join(' ', @{$spec->{interps} // [ ]}),
        join(' ', @{$spec->{emacs_mode} // [ ]}),
      ];
      push @$plugin_node, $spec_node;
    }
  }

  print_tree($tree_root);
}

sub register_command_line_options(+;+$) {
  my ($plugin_command_line_options, $plugin_option_descriptions, $plugin) = @_;
  $plugin_option_descriptions //= [ ];
  my ($caller_package_without_prefixes) = (caller =~ /([^:]+)$/oax);
  $plugin //= $caller_package_without_prefixes;

  while (my ($option, $typespec) = each %$plugin_command_line_options) {
    if (exists $command_line_options{$option}) 
      { die('Plugin '.$plugin.' tried to override pre-existing command line option '.$option); }
    $command_line_options{$option} = $typespec;
  }

  if (defined $plugin) {
    push @command_line_option_descriptions, 
      [ OPTION_HELP_CATEGORY, G_2_3 ] => G_2_3.'Options for '.G.$plugin,
  }

  push @command_line_option_descriptions, @$plugin_option_descriptions;
}

use constant {
  PROJECT_PATH_PREFIX_COLOR  => fg_color_rgb(216, 128,  255),
  SYSTEM_PATH_PREFIX_COLOR   => fg_color_rgb(255,  64,  160),
  COMPILER_PATH_PREFIX_COLOR => fg_color_rgb(64,  160,  255),
  EXTRA_PATH_PREFIX_COLOR_1  => fg_color_rgb(255,  160,  64),
  EXTRA_PATH_PREFIX_COLOR_2  => fg_color_rgb(160, 224,   64),
  EXTRA_PATH_PREFIX_COLOR_3  => fg_color_rgb(64,  224,  160),
};

our %path_prefixes = ( );
our %path_prefix_colors = ( );
our %path_prefix_dark_colors = ( );
our %path_prefix_branch_color_tree_cmd = ( );

my $path_prefixes_re = undef;

sub register_path_prefixes(+;@) {
  my ($prefixes) = @_;
  if (is_string $prefixes) { $prefixes = \@_; }
  elsif (is_hash_ref $prefixes) { $prefixes = [ %$prefixes ]; }

  pairmap {
    my $path = normalize_and_add_trailing_slash($a);

    if (is_file_type($path, FILE_TYPE_DIR) && (!exists $path_prefixes{$path})) {
      my ($color_codes, $abbrev) = 
        separate_leading_ansi_console_escape_codes($b);

      my $color = (if_there $color_codes) // SYSTEM_PATH_PREFIX_COLOR;
      my $dark = scale_rgb_fg($color, RATIO_2_3);

      $path_prefixes{$path} = 
        $dark.double_left_angle_bracket.
        $color.$b.$dark.double_right_angle_bracket.
        large_right_slash.X;

      $path_prefix_colors{$path} = $color;
      $path_prefix_dark_colors{$path} = $dark;
      $path_prefix_branch_color_tree_cmd{$path} = [
        TREE_CMD_BRANCH_COLOR,
        $dark,
      ];
    }
  } @$prefixes;

  # Clear the regexp so it will be regenerated the next time we need to use it:
  $path_prefixes_re = undef;
}

sub get_path_prefix($) {
  my ($filename) = @_;

  $path_prefixes_re //= prepare_prefix_string_subst_regexp((sort keys %path_prefixes));
  return ($filename =~ /$path_prefixes_re/oamsx) ? $1 : undef;
}

sub format_filename_with_path_prefix($) {
  my ($filename) = @_;

  $path_prefixes_re //= prepare_prefix_string_subst_regexp((sort keys %path_prefixes));
  return format_filesystem_path($filename, %path_prefixes, $path_prefixes_re);
}

sub format_path_prefix_abbreviation_table() {
  return NL.print_folder_tab(Y.U.'Path Prefix Abbreviations:'.X).
    format_table(
      [ pairmap { [ (format_filesystem_path(strip_trailing_slash($a), undef, undef, 1).X, $b) ] }
          hash_sorted_by_keys_as_pair_array(%path_prefixes) ],
      row_prefix => '    ', 
      colseps => B.'  '.arrow_barbed.'  '.X,
      padding => K_1_2.dot_small,
    ).NL;
}

#-----------------------------------------------------------------------------#
# Output Format Plugin Registry                                               #
#-----------------------------------------------------------------------------#

use constant ALL_SELECTED_SOURCES_KEY => '';

sub register_output_formats {
  foreach my $spec (@_) {
    push @output_formats, $spec;
    my ($name, $aliases) = getfields $spec, qw(name aliases);
    foreach my $alias ($name, @$aliases) { $output_format_names{$alias} = $spec; }

    my $custom_options = $spec->{command_line_options};
    my $custom_option_descriptions = $spec->{command_line_option_descriptions};
    if (defined $custom_options) {
      push @output_format_command_line_options, 
        (flatten $custom_options);
      if (defined $custom_option_descriptions) {
        push @output_format_command_line_option_descriptions,
          @$custom_option_descriptions;
      }
    } else {
      push @output_format_command_line_options, 
        ($name => [ 
          \$output_format_name, 
          OPTION_ASSIGN_BOOL, 
          $spec->{aliases}, 
          $name 
        ]);
      push @output_format_command_line_option_descriptions,
        ($name => $spec->{description});
    }
  }
}

#-----------------------------------------------------------------------------#
# Persistent Metadata Caching                                                 #
#-----------------------------------------------------------------------------#

sub check_options_relevant_to_cache_validity(+) {
  my ($cache) = @_;

  my $saved_options = $cache->{options_relevant_to_cache_validity};

  return 1 if (!defined $saved_options);

  while (my ($option, $saved_value) = each %$saved_options) {
    my $option_spec = $command_line_options{$option};
    if (!is_array_ref $option_spec) { $option_spec = [ $option_spec ]; };
    my $new_value_ref = $option_spec->[0];
    my $type = typeof($new_value_ref);
    printdebug { 'option ', $option, ': new_value_ref ', $new_value_ref, ' vs saved ', $saved_value };
    my $match = 0;
    if ($type == SCALAR_REF) {
      my $new_value = ${$new_value_ref};
      $match = ($new_value == $saved_value);
    } elsif (($type == STRING_REF) || ($type == DUAL_REF)) {
      my $new_value = ${$new_value_ref};
      $match = ($new_value eq $saved_value);
    } elsif ($type == ARRAY_REF) {
      $match = arrays_identical($new_value_ref, $saved_value);
    } elsif ($type == HASH_REF) {
      $match = hashes_identical($new_value_ref, $saved_value);
    } else {
      die('Unsupported data type ', $typeid_to_string[$type], ' of ', $new_value_ref);
    }

    printdebug { 'option ', $option, ': match? ', $match };
    return 0 if (!$match);
  }
  
  printdebug { 'All options matched!' };
  
  return 1;
}

sub configure_global_settings(+) {
  my ($cache) = @_;

  printdebug{'configure_global_settings: configuring ', 
             ((defined $cache) ? 'using cache' : 'from scratch')};

  expand_interp_wildcards($cache);

  printdebug{'Loaded plugin classes:  ', @plugins};
  printdebug{'Loaded plugin names:    ', [ sort keys %plugin_name_to_source_types ]};
  printdebug{'Available source types: ', [ sort keys %source_type_to_spec ]};

  foreach my $plugin (@plugins) {
    printdebug{'Configuring plugin class ', $plugin};
    if (!$plugin->configure($command_line_option_values, $filenames, $cache))
      { die("Plugin class $plugin failed to initialize"); }
  }

  if (!check_options_relevant_to_cache_validity($cache)) {
    warning('Configuration has changed since cache was created; all files will be re-checked');
    delete $cache->{sources};
  }

  printdebug{'Configuring generic source base class'};
  MTY::ListDeps::Source->configure($command_line_option_values, $filenames, $cache);
}

noexport:; use constant {
  STORED_METADATA_CACHE_FORMAT_VERSION => 201502270001,
};

sub retrieve_all_cached_metadata() {
  return undef if (is_empty($cache_file_name));

  my $cache_fd = sys_open($cache_file_name, O_RDONLY); 

  if (!defined $cache_fd) {
    # Cache file doesn't exist - this is usually normal the first time
    # after we enable the metadata cache, so just silently return undef.
    return undef;
  }

  my $cache_fd_stats = get_file_stats_of_fd($cache_fd);
  my $perms = $cache_fd_stats->[STAT_MODE];

  if ($perms & (PERM_GROUP_W | PERM_OTHER_W)) {
    warning('Cache file ', $cache_file_name, ' is writable by your group '.
            'and/or everyone; this is insecure and will invalidate the cache.');
    sys_close($cache_fd); # close the file handle and underlying fd
    return undef;
  }

  my $handle = IO::File->new_from_fd($cache_fd, 'r');

  my $cache = Storable::fd_retrieve($handle);

  if (!defined $cache) {
    warning("Cannot retrieve metadata from cache file '$filename'");
    return undef;
  }

  my ($version, $timestamp) = getfields $cache, qw(version timestamp);

  if ($version != STORED_METADATA_CACHE_FORMAT_VERSION) {
    warning("Cached metadata in '$filename' was from incompatible version $version ".
            "(this is version ".STORED_METADATA_CACHE_FORMAT_VERSION.")");
    return undef;
  }

  $handle = undef; # close the handle and the underlying file

  # if (is_debug) { pp $cache; }

  return $cache;
}

sub store_all_cached_metadata(+) {
  my ($cache) = @_;

  return undef if (is_empty($cache_file_name));

  # if (is_debug) { pp $cache; }
  $cache->{interp_to_source_type} = 
    [ (pairmap { ($a => $b->{type}) } (flatten %interp_to_source_type)) ];

  my $captured_options_relevant_to_cache_validity = { 
    map {
      my $option = $_;
      my $option_spec = $command_line_options{$option};
      if (!is_array_ref $option_spec) { $option_spec = [ $option_spec ]; };
      my $valueref = $option_spec->[0];
      ($option => ((is_scalar_ref $valueref) ? ${$valueref} : $valueref));
    } (keys %options_relevant_to_cache_validity)
  };
  
  $cache->{options_relevant_to_cache_validity} = 
    $captured_options_relevant_to_cache_validity;

  $cache->{version} = STORED_METADATA_CACHE_FORMAT_VERSION;
  $cache->{filename} = $filename;

  $cache->{config} = save_current_option_settings(%command_line_options, $command_line_option_values);

  my $timestamp = clock_gettime_nsec();
  $cache->{timestamp} = $timestamp;

  my $cache_fd = sys_open($cache_file_name, O_WRONLY|O_CREAT|O_TRUNC, 0600); 

  if (!defined $cache_fd) {
    warning('Cannot open cache file ', $cache_file_name, ' for writing (', $!, ')');
    $cache_file_name = undef;
    return undef;
  }

  my $handle = IO::File->new_from_fd($cache_fd, 'w');

  if (!Storable::store_fd($cache, $handle)) {
    warning("Cannot store metadata into cache file '$filename'");
    # Make sure we eliminate any possibly partially written file:
    $handle = undef; # close the file handle and the underlying stream
    sys_unlink($filename);
    return undef;
  }

  $handle = undef; # close the file handle and the underlying stream

  return $cache;
}

#-----------------------------------------------------------------------------#
# Parse options from command line and config files                            #
#-----------------------------------------------------------------------------#
sub parse_listdeps_command_line {
  @args_from_config_file = read_options_from_config_file();
  my @args = (@args_from_config_file, @_);

  my ($filenames, $invalid_option_indexes, $command_line_option_values) = 
    parse_and_check_command_line(%command_line_options, @args, @command_line_option_descriptions);

  $filenames = [ map { (resolve_path($_) // '(missing):'.$_) } @$filenames ];

  if (!is_stdout_color_capable() && (!$force_color)) { $machine_readable = 1; }

  my $show_symbolic_direct_inverse_deps = 
    $show_symbolic_deps || $show_direct_deps || $show_inverse_deps;

  $output_format_name //= (defined $user_defined_output_format_template) 
    ? 'format' : 'makerules';

  $output_format_spec = $output_format_names{$output_format_name};

  if (!defined $output_format_spec) {
    die('Unsupported output format "'.$output_format_name.'"; '.
          'run "lsdeps -help" for supported formats.');
  }

  if ($show_all_deps || $show_all_files_found) { $find_recursive_deps = 1; }

  if ($find_recursive_deps && (!$show_symbolic_direct_inverse_deps)) { $show_all_deps = 1; }

  if (!($show_symbolic_direct_inverse_deps || $show_all_deps || $show_all_files_found)) 
    { $show_direct_deps = 1; }

  $project_dir //= longest_common_path_prefix($filenames);
  $project_dir = normalize_and_add_trailing_slash($project_dir);

  if (stdout_is_terminal()) 
    { $wrap_long_lines //= get_terminal_width_in_columns() - 2; }

  if (!length $metadata_cache_filename) { $metadata_cache_filename = undef; }

  while (my ($pattern, $typename) = each %source_type_overrides) {
    my $typespec = $source_type_to_spec{$typename};
    if (!defined $typespec) {
      warning('Cannot override source type of "', $pattern, '": source type "', $typename, '" is invalid.');
      next;
    }

    if ($pattern =~ /\A \*? \. ([^\.]++) \Z/oamsx) {
      $override_source_type_of_suffix = $typespec;
    } else {
      my $filename = resolve_path($pattern);
      if (!defined $filename) {
        warning('Cannot override source type of missing file "', $pattern, '"') if ($enable_warnings);
        next;
      }
      $override_source_type_of_filename{$filename} = $typespec;
    }
  }

  register_path_prefixes(getcwd() => PROJECT_PATH_PREFIX_COLOR.'cwd');
  my %colored_dir_aliases = pairmap { $a => PROJECT_PATH_PREFIX_COLOR.$b } %dir_aliases;
  register_path_prefixes(%colored_dir_aliases);
  register_path_prefixes($project_dir => PROJECT_PATH_PREFIX_COLOR.'proj');

  return ($filenames, $invalid_option_indexes, $command_line_option_values);
}

1;