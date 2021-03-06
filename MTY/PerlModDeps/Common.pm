# -*- cperl -*-
#
# MTY::PerlModDeps::Common
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::PerlModDeps::Common;

use integer; use warnings; use Exporter qw(import);
# Don't try to update our own module:

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($DEBUG $quiet $dryrun @modlist @modpath $info_mode $no_output $ppi_cache
     LOCAL_ICON $no_warnings PACKAGE_ICON arrow_to_box EXPORTED_ICON
     IMPORTED_ICON $makefile_mode $ppi_tree_mode $raw_deps_mode arrow_from_box
     $ppi_cache_path %scope_to_color $next_decl_label $auto_export_mode
     $auto_import_mode %exprtype_to_icon $export_by_default $remove_modpath_re
     write_updated_file $clear_exports_mode $module_bundle_name
     $default_bundle_name %special_label_names $comma_with_spaces_re
     %alt_exprtype_to_icon @auto_import_prefixes IMPORTED_PACKAGE_ICON
     $max_module_name_length $max_symbol_name_length $module_bundle_filename
     $show_unmodified_modules GEN_EXPORTS_DECL_UPDATED
     GEN_EXPORTS_DECL_PRESERVE %symbol_to_defining_module
     @allowed_module_namespaces GEN_EXPORTS_DECL_UNCHANGED
     $makefile_target_prefix_dir GEN_EXPORTS_DECL_NOT_MODULE
     $auto_import_module_names_re $allowed_module_namespaces_re
     @gen_exports_decl_result_name %bundle_name_to_list_of_modules
     %module_name_or_filename_to_module %symbol_to_list_of_dependent_modules
     GEN_EXPORTS_DECL_MISSING_PLACEHOLDER
     GEN_EXPORTS_DECL_ONLY_GENERATE_NO_UPDATE);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::Tree;
use MTY::Display::Table;
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


use PPI;
use PPI::Document;
use PPI::Token;
use PPI::Statement;
use PPI::Structure;
use PPI::Cache;
use PPI::Dumper;
#pragma end_of_includes


#
# Command line options
#
our $info_mode = 0;
our $auto_import_mode = 0;
our $auto_export_mode = 0;
our $clear_exports_mode = 0;
our $makefile_mode = 0;
our $raw_deps_mode = 0;
our $ppi_tree_mode = 0;
our $quiet = 0;
our $DEBUG = 0;
our $no_warnings = 0;
our $no_output = 0;
our $dryrun = 0;
our $show_unmodified_modules = 0;
our $ppi_cache_path = '/tmp/ppi-cache-'.getuid();
our $ppi_cache = undef;
our @modlist = ( );

our @modpath = ( );
our $remove_modpath_re = qr{\.pm$}oa;

our @allowed_module_namespaces = ( );
our $allowed_module_namespaces_re = qr{^}oa;

our @auto_import_prefixes = ( );
our $auto_import_module_names_re = undef;
#our $use_auto_import_module_names_re = undef;
our $max_module_name_length = 0;
our $makefile_target_prefix_dir = '';
our $module_bundle_name = undef;
our $module_bundle_filename = undef;

our %scope_to_color = (
  'local' => $K,
  'state' => $K,
  'my'    => $K,
  'our'   => $Y,
  'constant' => $M,
  'sub'   => $C);

our $comma_with_spaces_re = qr{\s*+\,\s*+}oamsx;

use constant arrow_to_box => arrow_barbed.double_disc;
use constant arrow_from_box => double_disc.arrow_barbed;

our %alt_exprtype_to_icon = (
  var_decl => arrow_from_box,
  var_decl_list => arrow_from_box,
  sub_decl => arrow_from_box,
  const_decl => arrow_from_box,
  const_decl_list => arrow_from_box,
  var_use => arrow_to_box,
  sub_call => arrow_to_box
);

use constant {
 EXPORTED_ICON => $G . ' ' . x_in_box . arrow_barbed,
 IMPORTED_ICON => $Y . ' ' . arrow_barbed . checkmark_in_box,
 LOCAL_ICON    => $K . ' ' . box_with_shadow . counterclockwise_curved_arrow,
 IMPORTED_PACKAGE_ICON => $M . ' ' . arrow_head . checkmark_in_box,
 PACKAGE_ICON => $C . ' ' . asterisk . checkmark_in_box,
};

our %exprtype_to_icon = (
  'PPI::Statement::Package' => $C.asterisk,
  'PPI::Include' => $R.checkmark,
  'PPI::Statement::Variable' => $G.arrow_tri,
  'PPI::Statement::Sub' => $C.arrow_tri,
  'PPI::Statement::Constant' => $M.arrow_tri,
  'PPI::Token::Symbol' => $Y.left_arrow_open_tri,
  'PPI::Word' => $C.left_arrow_open_tri,
  #'PPI::Token::Symbol' => $K.left_arrow_open_tri,
);

#
# Default bundle name (module name) to be added to the parent namespace
# containing all the modules to be bundled together. For instance, if
# this is set to 'All', bundling 'My/Module/Namespace/*.pm' will yield
# a default bundle name of 'My::Module::Namespace::All'. 
#
# If you want the default bundle's module to be the same as the enclosing 
# namespace itself (i.e. so 'use My::Module::Namespace' imports all modules
# in the 'My::Module::Namespace::*' namespace), this can be set to '' (the
# empty string) instead, although using 'All' is often a clearer practice,
# especially if you intend to define other bundles that are subsets of the
# all-inclusive bundle (since these would typically have to reside within
# the enclosing namespace anyway, e.g. My::Module::Namespace::MostCommon)
#
our $default_bundle_name = 'ALL';

our %symbol_to_defining_module = ( );
our $max_symbol_name_length = 0;

our %symbol_to_list_of_dependent_modules = ( );

our %module_name_or_filename_to_module = ( );

our %bundle_name_to_list_of_modules = ( );

our $next_decl_label = undef;
our $export_by_default = 1;

our %special_label_names = (
  'export' => 1, 
  'noexport' => 1,
  'export_by_default' => 1,
  'noexport_by_default' => 1,
  'export_optional' => 1,
  'export_tag_' => 1,
  'autoimport' => 1,
  'preserve' => 1,
  'nobundle' => 1,
  'bundle' => 1,
);

my $lineout = 0;

use constant {
  GEN_EXPORTS_DECL_UNCHANGED => 0,
  GEN_EXPORTS_DECL_UPDATED => 1,
  GEN_EXPORTS_DECL_ONLY_GENERATE_NO_UPDATE => 2,
  GEN_EXPORTS_DECL_PRESERVE => 3,
  GEN_EXPORTS_DECL_MISSING_PLACEHOLDER => 4,
  GEN_EXPORTS_DECL_NOT_MODULE => 5,
};

our @gen_exports_decl_result_name = (
  $R.'no new changes'.((!$show_unmodified_modules) ? $K.' (unchanged modules are not listed)' : ''),
  $G.'updated',
  $G.'(only generate without update)',
  $Y.'preserved (not updated)',
  $B.'missing @EXPORT placeholder',
  $K.'not a module'
);

#------------------------------------------------------------------------------
# write_updated_file($module)
#------------------------------------------------------------------------------
sub write_updated_file($) {
  my ($m) = @_;

  my $changed_anything = ($m->{code} ne $m->{origcode});
  if ($no_output) { $changed_anything = 0; }

  if ($changed_anything) {
    if ($is_stdio) {
      printfd(STDOUT, $m->{code});
    } elsif (!$dryrun) {
      write_file($m->{filename}, $m->{code});
    }
  }

  return $changed_anything;
}
