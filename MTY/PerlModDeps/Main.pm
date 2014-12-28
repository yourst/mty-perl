#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::PerlModDeps::Main
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#
# perl-mod-deps is an automatic code generator which automatically manages
# the imports and exports of Perl modules as well as programs. Collections
# of modules and programs can be processed by invoking perl-mod-deps in
# any of the following modes of operation (selected by the command line
# options indicated below):
# 
# -exports:  Automatically generate each module's 'our @EXPORTS = qw(...)'
#            array, along with the code to use Exporter::Lite to export
#            all symbols by default, or only symbols labeled as exported,
#            or various other modes of automatic exporting.
#
# -imports:  Automatically generate a list of "use Module1; use Module2; ..."
#            clauses for each module or program, based on the symbols it uses
#            and the modules which define those symbols (all potentially
#            auto-imported modules must be specified in the perl-mod-deps 
#            command line for this to work).
# 
# -makefile: Generate makefile compatible list of targets (each perl module)
#            and the module dependencies of each of those modules. This 
#            ensures other parts of the makefile (as determined by its
#            developer) will be re-executed whenever modules are changed.
#
# -info:     Print visually formatted list of all modules, declarations
#            and uses of any symbols imported (or which should be 
#            auto-imported) from other modules.
#
# -ppi:      Print the Abstract Syntax Tree (AST) and tokens generated
#            from the input Perl code.
#
# -dump:     Show extensive debugging output
#
# Labels can be manually added to each module's code to convey information
# to our auto-export system. Each special label is inserted immediately 
# before the declaration it affects, using the standard Perl label syntax
# (e.g. "noexport: sub mysub($...) { ... }'). 
#
# This notation is intuitive, convenient and syntactically transparent,
# because these labels are efectively no-ops: they do not alter the 
# program's control flow, since they're never actually used by any
# statements like goto, next, last, etc.
#
# The following label names can be used to control the auto-export system:
#
# 1. noexport:
# 
#    Specifies the variables, subroutines or constants which should
#    *not* be exported by default. Examples:
#
#    noexport: [our|my|local|state] [$|@|%]varname
#    noexport: sub mysub(...) { ... }
#    noexport: use constant { ABC => 123, ... };
#
#    (Technically only variables declared with the scope "our" can
#    be exported anyway, so the noexport label is slighty redundant
#    in this case - it's often easier to simply declare the variable
#    with the "my" scope, and our auto-export generator will also 
#    ignore it, just as if "noexport: our $... = ..." was used).
#
# 2. export:
#
#    Specifies which variables, subroutines or constants to export
#    from the module. This label is not usually necessary since by
#    default every symbol is exported unless labeled with noexport,
#    although this default may be changed using no_export_by_default
#    (see below). The export label syntax is exactly the same as the
#    noexport label's syntax listed above.
#
# 3. export_optional:
#
#    Indicates that the subsequent declaration should be optionally
#    exported only when the importing module or program explicitly
#    requests that symbol using e.g. "use MyModule qw(MyOptionalSym)"
#    This essentially specifies which symbols to place into the
#    @EXPORT_OK array (which will be auto-generated) instead of 
#    the @EXPORT array.
#
# 4. export_tag_TAG_NAME_HERE:
#
#    Indicates that the subsequent declaration will only be exported
#    to consumer modules or programs which use the indicated tag
#    when importing an applicable module. This essentially creates
#    the tags array for the module.
#
# 5. no_export_by_default:  and  export_by_default:
#
#    One of these two labels may appear before the package declaration
#    to determine whether all symbols in the module will be exported
#    by default (except for any declarations labeled with "noexport"),
#    or if declarations will be private to the module by default
#    (except for any declarations labeled with "export: ...").
#
#    Example:
#    no_export_by_default: package MyPackageName;
#
# 6. autoimport:
#
#    This label is *not* added by the module's developer; instead it's
#    inserted before "use PackageName" declarations to help this code
#    keep track of which modules were specifically requested by name,
#    and which modules were automatically determined to be required
#    based on our dependency analysis. Developers should *not* add,
#    remove or alter any "autoimport: use PackageName ...;" clauses
#    which were automatically added to their code.
# 
#    Examples:
#    use Explicitly::Imported::Module;
#    autoimport: use Auto::Imported::Module;
#
# 7. preserve:
#
#    This label should be placed before an @EXPORT and/or @EXPORT_OK
#    clause to instruct perl-mod-deps not to change it in any way
#    (for instance, if it was manually written a certain way on purpose 
#    and should not be automatically maintained by perl-mod-deps).
#
# This system will simply ignore any other label names it doesn't recognize,
# or in cases where label(s) with the names above appear in contexts other
# than immediately before declarations.
#


package MTY::PerlModDeps::Main;

use integer; use warnings; use Exporter::Lite;

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::CommandLine;
use MTY::Common::Strings;

use MTY::Filesystem::Files;

use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::Tree;
use MTY::Display::PPITreeFormatter;
use MTY::Display::TextInABox;

use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::PerlRegExpParser;
use MTY::RegExp::PerlSyntax;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;

use MTY::System::POSIX;

use MTY::PerlModDeps::Common;
use MTY::PerlModDeps::Module;
use MTY::PerlModDeps::Exports;
use MTY::PerlModDeps::Imports;
use MTY::PerlModDeps::Bundle;
use MTY::PerlModDeps::Deps;

use Data::Dumper;
use Data::Printer;

use PPI;
use PPI::Document;
use PPI::Token;
use PPI::Statement;
use PPI::Structure;
use PPI::Cache;
use PPI::Dumper;

use File::Basename qw(fileparse);

use DateTime;

#pragma end_of_includes

# Don't try to update our own module:

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(main process_command_line show_banner show_help);

if (!is_stderr_color_capable()) { disable_color(); };

my $printed_banner = 0;

sub show_banner {
  my ($subtitle) = @_;
  return if ($printed_banner);
  $printed_banner = 1;

  return print_banner(Y.'perl-mod-deps', 
                      M.'Perl module automatic export generator and dependency tracker', 
                      B, (defined($subtitle) ? ('%{div=long_dashes}'.NL.M.asterisk.'  '.$subtitle.X.NL) : undef));
}

sub show_help {
  printfd(STDERR, show_banner('%G%UHelp and Information'));

  warn_without_stack_trace('Syntax is: '.$0.' [-options...] file1.pm file2.pm ...');
  exit 1;
}

#------------------------------------------------------------------------------
# process_command_line(@ARGV):
#------------------------------------------------------------------------------

my %command_line_options = (
  #
  # Primary Actions and Modes:
  #
  'info' => [ \$info_mode, 0, [ qw(show analyze) ] ],
  'imports' => [ \$auto_import_mode, 0, [ qw(i import) ] ],
  'exports' => [ \$auto_export_mode, 0, [ qw(e export) ] ],
  'clear-exports' => [ \$clear_exports_mode, 0, [ qw(ce clearexp) ] ],
  'bundle' => [ \$module_bundle_name, OPTION_VALUE_REQUIRED, [ 'b' ] ],
  'makefile' => [ \$makefile_mode, 0, [ qw(m mk mf make) ] ],
  'dump' => [ \$raw_deps_mode, 0, [ qw(raw r) ] ],
  'ppi' => [ \$ppi_tree_mode, 0, [ qw(tree) ] ],
  #
  # General Options
  #
  'quiet' => [ \$quiet, 0, 'q' ],
  'debug' => [ \$DEBUG, 0, 'd' ],
  'nowarn' => [ \$no_warnings, 0, [ qw(w nw no-warnings) ] ],
  'no-output' => [ \$no_output, 0, 'noout' ],
  'dry-run' => [ \$dryrun, 0, [ qw(dryrun test) ] ],
  #
  # Module Selection and Processing
  #
  'show-unmodified-modules' => [ \$show_unmodified_modules, 0, 
    [ qw(list-all all a list-unmodified show-unmodified list-unmodified-modules) ] ],
  'modpath' => [ \@modpath, OPTION_VALUE_REQUIRED|OPTION_APPEND_REPEATS|OPTION_COMMA_SEP_LISTS, [ qw(path libpath libs mp p) ] ],
  'namespaces' => [ \@allowed_module_namespaces, OPTION_VALUE_REQUIRED|OPTION_APPEND_REPEATS|OPTION_COMMA_SEP_LISTS, [ qw(namespace ns n) ] ],
  'makefile-target-prefix-dir' => [ \$makefile_target_prefix_dir, OPTION_VALUE_REQUIRED, [ qw(target-prefix-dir prefix tpd) ] ],
  'ppi-cache' => [ \$ppi_cache_path, OPTION_VALUE_REQUIRED, [ qw(cache) ] ],
);

my $command_line_option_names_and_categories = [
  [ OPTION_HELP_CATEGORY, 'Actions and Modes of Operation' ],
  qw(info imports exports clear-exports bundle makefile dump ppi),
  [ OPTION_HELP_CATEGORY, 'General Options' ],
  qw(quiet debug nowarn no-output dry-run),
  [ OPTION_HELP_CATEGORY, 'Module and Package Selection and Processing' ],
  qw(show-unmodified-modules modpath namespaces makefile-target-prefix-dir ppi-cache)
];

my @command_line_options_help = (
  show_banner() => [ OPTION_HELP_LITERAL ],
  'Syntax' => [ OPTION_HELP_SYNTAX ],
  'Actions and Modes of Operation' => [ OPTION_HELP_CATEGORY ],
  'info' => '',
  'imports' => '',
  'exports' => '',
  'clear-exports' => '',
  'bundle' => '',
  'makefile' => '',
  'dump' => '',
  'ppi' => '',
  'General Options' => [ OPTION_HELP_CATEGORY ],
  'quiet' => '',
  'debug' => '',
  'nowarn' => '',
  'no-output' => '',
  'dry-run' => '',
  'Selection and Processing Options' => [ OPTION_HELP_CATEGORY ],
  'show-unmodified-modules' => '',
  'modpath' => '',
  'namespaces' => '',
  'makefile-target-prefix-dir' => '',
  'ppi-cache' => '',
);

sub process_command_line {
  my ($filenames, $invalid_args) = parse_and_check_command_line(%command_line_options, @_, @command_line_options_help);

  $remove_modpath_re = '(?:\.pm$)|^/?(?:'.join('|', map(quotemeta, @modpath)).')/?';
  $remove_modpath_re = qr{$remove_modpath_re}oa;
  # Generate reasonable list of auto-import prefixes based on names of
  # subdirectories and .pm module files found within each path component:
  push @auto_import_prefixes, create_auto_import_prefixes_from_mod_path(@modpath);

  foreach my $ns (@allowed_module_namespaces) 
    { $ns .= '::' if ($ns !~ /::$/oax); }

  $allowed_module_namespaces_re = 
    '^(?:'.join('|', map(quotemeta, @allowed_module_namespaces)).')';
  
  $allowed_module_namespaces_re = qr{$allowed_module_namespaces_re}oa;

  $ppi_cache_path //= '/tmp/ppi-cache-'.getuid();

  #
  # Process specified filenames now that we know about any options 
  # which could affect the set of files we will actually be using:
  #
  if (defined $module_bundle_name) {
    $module_bundle_filename = ($module_bundle_name =~ s{::}{/}roaxg);
    if ($module_bundle_filename !~ /\.pm$/) { $module_bundle_filename .= '.pm'; }
    $module_bundle_filename = resolve_path($module_bundle_filename) // $module_bundle_filename;
  };

  foreach my $filename (@$filenames) {
    my $argpath = resolve_path($filename);
    next if (defined $module_bundle_filename) && ($argpath eq $module_bundle_filename);
    add_module_or_program($filename);
  }

  if (!scalar(@modlist)) { 
    if (!(-f STDIN || -p STDIN)) {
      print_command_line_options_help(%command_line_options, @command_line_options_help);
      exit 1;
    }

    add_module_or_program('/dev/stdin'); 
    $is_stdio = 1; 
  }

  return 1;
}

sub main {
  if (!process_command_line(@_)) { exit 1; }

  create_auto_import_module_names_re(@auto_import_prefixes);
  if ($DEBUG) { show_auto_import_prefixes(); }

  if (!$quiet) {
    my $message = 
      ($info_mode) ? 'Showing all information on module imports, exports and local symbols in' :
      ($auto_import_mode) ? 'Automatically updating "use module" imported module lists for' :
      ($auto_export_mode) ? 'Automatically updating @EXPORT symbol lists for' :
      (defined $module_bundle_name) ? 'Automatically generating module bundle with package name '.$module_bundle_name.' for ' :
      ($makefile_mode) ? 'Generating Makefile targets and dependencies for' :
      ($raw_deps_mode) ? 'Printing raw symbol definition and usage information for' :
      ($ppi_tree_mode) ? 'Printing formatted PPI Abstract Syntax Tree for' :
      '??? for';

    $message = M.asterisk.'  '.Y.$message.' '.C.scalar(@modlist).Y.' Perl source files:'.X.NL;
    if ($is_stdio) { $message .= B.'(Processing stdin -> stdout instead of updating files)'.NL; }
    printfd(STDERR, show_banner());
    print(STDERR text_in_a_box($message, 0, R, 'rounded', 'single'));
    print(STDERR NL);
  }

  if (defined $ppi_cache_path) {  
    if (! -d $ppi_cache_path) { 
      mkdir($ppi_cache_path, DEFAULT_DIR_PERMS) || 
        simple_warning("Cannot create PPI cache directory $ppi_cache_path");
    }
    $ppi_cache = PPI::Cache->new(path => $ppi_cache_path)
      || simple_warning("Cannot create PPI cache in $ppi_cache_path");
    PPI::Document->set_cache($ppi_cache);
  }
  
  foreach $m (@modlist) {
    my $filename = $m->{filename};
    my $warning_prefix = '  '.$K.padstring($filename, $max_module_name_length).$R.'  '.x_symbol.
      '     '.$Y.$U.'skipped'.$X.$R.' because it\'s ';

    #
    # (non-obvious perlism): assignment to a loop iteration variable (i.e. $m)
    # in perl is equivalent to assigning to that slot within the array itself,
    # in this case to annul the ref to the bogus file data structures:
    #
    $m = read_and_check_file($m, $warning_prefix);
    next if (!(defined $m));
  }

  $max_module_name_length = 0;

  foreach $m (@modlist) {
    next if (!defined($m));
    parse_module($m);
  }

  my @symbol_name_list = sort (keys %symbol_to_defining_module);

  resolve_symbol_and_module_dependency_graphs(@symbol_name_list, @modlist);

  if ($info_mode) {
    print_symbol_dependencies(@symbol_name_list);
    print_module_dependencies(@modlist);
  }

  if ($makefile_mode) {
    my $makedeps = generate_makefile_deps(@modlist, $makefile_target_prefix_dir);
    print(STDOUT $makedeps);
  } elsif (defined $module_bundle_name) {
    my $bundle = generate_module_bundle(@modlist, $module_bundle_name);
    $bundle->{filename} = $module_bundle_filename;
    write_updated_file($bundle);
  } elsif ($auto_import_mode) {
    foreach $m (@modlist) {
      next if (!defined $m);
      update_auto_imports($m);
      write_updated_file($m);
    }
  } elsif ($auto_export_mode) {
    my @result_histogram = ( );

    foreach $m (@modlist) {
      next if (!defined($m));
      my $result = generate_exports_decl($m);
      $result_histogram[$result]++;
      write_updated_file($m);
    }

    my $message = '';

    my $mod_count_max = max_in_list(@result_histogram);
    my $mod_count_field_width = length("$mod_count_max");

    for ($i = 0; $i < sizeof(@result_histogram); $i++) {
      my $n = $result_histogram[$i];
      next if (!$n);
      $message .= $K.' '.dot.' '.$Y.padstring($gen_exports_decl_result_name[$i].
        fg_gray(80), 55, ALIGN_LEFT, dot_small).' '.$G.
        padstring($n, -$mod_count_field_width).$K.' modules'.$X.NL;
    }

    print(STDERR NL.text_in_a_box('%{tab}%C%USummary%X'.NL.$message, ALIGN_LEFT, $B, 'rounded').NL);
  } elsif ($ppi_tree_mode) {
    foreach $m (@modlist) {
      next if (!defined($m));
      my $printable_tree = convert_ppi_tree_to_printable_tree($m->{tree});
      print_tree($printable_tree, STDERR);
    }
  }

  print(STDERR NL.$M.'Done!'.$X.NL.NL) if (!$quiet);

  return 0;
}

1;
