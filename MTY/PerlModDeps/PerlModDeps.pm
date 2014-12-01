# -*- cperl -*-
#
# MTY::PerlModDeps::PerlModDeps
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


package MTY::PerlModDeps::PerlModDeps;

use integer; use warnings; use Exporter::Lite;
# Don't try to update our own module:
nobundle:; preserve:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($DEBUG $allowed_module_namespaces_re $auto_export_mode $auto_import_mode
     $auto_import_module_names_re $dryrun $info_mode $makefile_mode
     $makefile_target_prefix_dir $max_module_name_length
     $module_bundle_filename $module_bundle_name $no_output $no_warnings
     $perl_exports_exports_ok_export_tags_clauses_re $ppi_cache
     $ppi_cache_path $ppi_tree_mode $quiet $raw_deps_mode $remove_modpath_re
     $show_unmodified_modules @allowed_module_namespaces
     @auto_import_prefixes @modlist @modpath EXPORTED_ICON
     GEN_EXPORTS_DECL_MISSING_PLACEHOLDER GEN_EXPORTS_DECL_NOT_MODULE
     GEN_EXPORTS_DECL_ONLY_GENERATE_NO_UPDATE GEN_EXPORTS_DECL_PRESERVE
     GEN_EXPORTS_DECL_UNCHANGED GEN_EXPORTS_DECL_UPDATED IMPORTED_ICON
     IMPORTED_PACKAGE_ICON LOCAL_ICON PACKAGE_ICON add_module_or_program
     add_module_to_bundle analyze_ppi_subtree arrow_from_box arrow_to_box
     check_for_same_export_name_in_other_modules_and_add
     create_auto_import_module_names_re
     create_auto_import_prefixes_from_mod_path extract_constants
     format_module_name generate_exports_decl generate_makefile_deps
     generate_module_bundle main parent_module_name parse_module
     print_module_dependencies print_symbol_dependencies process_command_line
     read_and_check_file resolve_symbol_and_module_dependency_graphs
     show_auto_import_prefixes show_banner show_help update_auto_imports
     write_updated_file);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Filesystem::Files;
use MTY::Common::Strings;
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
use MTY::RegExp::CxxParser;
use MTY::RegExp::CxxREs;
use MTY::RegExp::PerlRegExpParser;
use MTY::RegExp::Analyzer;
use MTY::RegExp::PerlSyntax;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
use MTY::System::POSIX;

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

if (!is_stderr_color_capable()) { disable_color(); };

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

my %scope_to_color = (
  'local' => $K,
  'state' => $K,
  'my'    => $K,
  'our'   => $Y,
  'constant' => $M,
  'sub'   => $C);

my $comma_with_spaces_re = qr{\s*+\,\s*+}oamsx;

#use constant long_heavy_arrow => heavy_horiz_bar.arrow_tri;
#use constant arrow_to_box => long_heavy_arrow.' '.empty_box;
#use constant arrow_from_box => checkmark_in_box.' '.long_heavy_arrow;

#use constant long_heavy_arrow => heavy_horiz_bar.arrow_tri;
#use constant arrow_to_box => long_heavy_arrow.' '.empty_box;
#use constant arrow_from_box => checkmark_in_box.' '.long_heavy_arrow;

use constant arrow_to_box => arrow_barbed.double_disc;
use constant arrow_from_box => double_disc.arrow_barbed;

my %alt_exprtype_to_icon = (
  var_decl => arrow_from_box,
  var_decl_list => arrow_from_box,
  sub_decl => arrow_from_box,
  const_decl => arrow_from_box,
  const_decl_list => arrow_from_box,
  var_use => arrow_to_box,
  sub_call => arrow_to_box
);

use constant {
# EXPORTED_ICON => $G . double_disc . arrow_barbed,
# IMPORTED_ICON => $Y . arrow_barbed . double_disc,
# LOCAL_ICON    => $K . bold_left_brace . counterclockwise_curved_arrow . bold_right_brace,
# IMPORTED_PACKAGE_ICON => $M . single_disc . arrow_barbed . single_disc,
# PACKAGE_ICON => $C.round_bold_left_paren.asterisk.round_bold_right_paren,

 EXPORTED_ICON => $G . ' ' . x_in_box . arrow_barbed,
 IMPORTED_ICON => $Y . ' ' . arrow_barbed . checkmark_in_box,
 LOCAL_ICON    => $K . ' ' . box_with_shadow . counterclockwise_curved_arrow,
 IMPORTED_PACKAGE_ICON => $M . ' ' . arrow_head . checkmark_in_box,
 PACKAGE_ICON => $C . ' ' . asterisk . checkmark_in_box,
};

my %exprtype_to_icon = (
  'PPI::Statement::Package' => $C.asterisk,
  'PPI::Include' => $R.checkmark,
  'PPI::Statement::Variable' => $G.arrow_tri,
  'PPI::Statement::Sub' => $C.arrow_tri,
  'PPI::Statement::Constant' => $M.arrow_tri,
  'PPI::Token::Symbol' => $Y.left_arrow_open_tri,
  'PPI::Word' => $C.left_arrow_open_tri,
  #'PPI::Token::Symbol' => $K.left_arrow_open_tri,
);

my $double_colon_re = qr{\:\:}oax;

sub format_module_name($;$) {
  my ($name, $color) = @_;
  # local (*name, *color) = \ (@_);

  $color //= $X;

  return '' if (!defined $_[0]);
  my $double_colon = $K.double_colon.$color;
  return ($_[0] =~ s{$double_colon_re}{$double_colon}roaxg);
}

#
# Returns the enclosing parent namespace one level above the specified module,
# i.e. "A::B::C::D" returns A::B::C, or only "A" returns "".
#
sub parent_module_name($) {
  my ($package) = @_;
  if (!defined $package) { return ''; }

  my $removed_level = ($package =~ s{::\w*$}{}oax);
  return ($removed_level) ? $package : '';
}

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
my $default_bundle_name = 'ALL';

#
# Instantiate a container for this module or perl program file:
# Make sure we initialize the correct data types for each field:
#

sub add_module_or_program($) {
  my $filename = $_[0];

  if (!((-f $filename) || (-l $filename) || (-p $filename))) {
    # Don't try to process directories here - let the caller use wildcards:
    return undef;
  }

  # We add an extra possible space for every directory component (/), since these
  # slashes will most likely become '::' once we know the real perl module name:
  my $guessed_module_name = $filename
    =~ s{$remove_modpath_re}{}roag
    =~ s{/}{::}roag;

  my $n = length($guessed_module_name);
  $max_module_name_length = max($max_module_name_length, length($guessed_module_name));

  my %modinfo = (
    index => scalar(@modlist),
    filename => $filename,
    module_name => undef,
    code => undef,
    origcode => undef,
    preserve => 0,
    # ref to hash of symbol name => ref to PPI::Node of declaration:
    # for constants, keys (names) are prefixed with '=':
    exports => { },
    # ref to hash of symbol name => 
    #   tag string (if a tagged export), or undef (if an optional export):
    # for constants, keys (names) are prefixed with '=':
    optional_or_tagged_exports => { },
    # ref to hash (symbol_name => (number of refs to that symbol))
    imported_symbols => { },
    # ref to hash (explicitly imported module name => 1)
    explicitly_imported_modules => { },
    # ref to hash (module_name => ($ref -> %module))
    imported_modules => { },
    # ref to hash (module_name => ($ref -> $module))
    dependent_modules => { },
    # ref to hash (symbol name => 1)
    known_local_symbol_names => { },
    # ref to hash of (fully qualified bundle name => 
    #                 ref to array of all modules in that bundle)
    # (unless 'nobundle' attribute is set)
    bundle_name => { },
  );
  
  push @modlist, \%modinfo;
  return \%modinfo;
}

sub create_auto_import_prefixes_from_mod_path(+) {
  my ($list) = @_;
  # local (*list) = \ (@_);

  my @out = ( );
  my $DEBUG = 0;
  foreach $p (@$list) {
    $p = realpath($p);
    opendir(my $dirfd, $p) || die "Cannot open module path directory '$p' ($!)";
    my @files_and_subdirs = readdir($dirfd);
    closedir $dirfd;
    if ($DEBUG) {
      print(STDERR $B.' '.arrow_head.' '.$Y.$U.'Module path directory '.
              $K.left_quote.$C.$p.$K.right_quote.$Y.' has '.$C.
                scalar(@files_and_subdirs).$Y.' entries:'.$X.NL);
    }

    foreach $f (@files_and_subdirs) {
      next if ($f =~ /^\./oamsx); # skip dot files + . and .. dirs
      $f = realpath($p.'/'.$f);
      my ($basename, $dir, $suffix) = fileparse($f);
      $dir //= ''; $suffix //= '';
      if ($DEBUG) {
        print(STDERR $G.'   '.checkmark.' '.$K.'dir '.$Y.$dir.$K.' name '.$C.$basename.$K);
        if (is_there($suffix)) { print(STDERR .' suffix '.$G.$suffix.$K); }
        print(STDERR $B.' '.large_arrow_barbed.' ');
      }
      
      # only consider link target to get file type; ignore its name, since the user
      # may have intentionally symlinked certain packages to different names:
      if (-l $f) { $f = realpath(readlink($f)); }
      # ignore files and dirs that aren't valid package names
      if ($basename !~ /^\w+$/) {
        if ($DEBUG) { print(STDERR $K.' (skipped - not a valid package name)'.$X.NL); }
        next;
      }
      if ((-f $f) && ($suffix eq '.pm')) {
        if ($DEBUG) { print(STDERR $C.$basename.$K.' (module)'.$X.NL); }
        push @out,$basename;
      } elsif ((-d $f) && (length($suffix) == 0)) {
        if ($DEBUG) { print(STDERR $Y.$basename.$G.'::'.$K.' (package hierarchy)'.$X.NL); }
        push @out,($basename.'::');
      }
    }
  }
  return (wantarray ? @out : \@out);
}

sub show_auto_import_prefixes {
  print(STDOUT $B.' '.arrow_head.' '.$C.$U.'Package name prefixes of modules to automatically import:'.$X.NL);
  my $n = maxlength(@auto_import_prefixes);
  foreach $p (@auto_import_prefixes) {
    my $s = $p;
    $s = padstring($s, $n);
    #my ($hierarchy, $module) = ($s =~ /^([\w\:]+?) :: ([^\:]*)$/oamsxg);
    #$hierarchy //= '';
    #$module //= ''; 
    #$hierarchy =~ s/::/${B}::${Y}/oamsxg;

    print(STDOUT ' '.$G.checkmark.' '.$Y.$s.$X.NL);
  }

  #show_compiled_regexp('auto_import_module_names', \$auto_import_module_names_re);
}

sub create_auto_import_module_names_re(+) {
  my ($list) = @_;
  # local (*list) = \ (@_);

  my $re = '';
  my $first = 1;
  foreach $p (@$list) {
    $re .= (!$first ? ' | ' : '') . $p . 
      (($p =~ /\:\:\*?$/) ? '[\w\:]*+' : '');
    $first = 0;
  }
  $auto_import_module_names_re = compile_regexp(qr{$re}oamsx, 'auto_import_module_names');
  
  #$re = '\b use \s++ (?: '.$re.') [^\;]*+ ; \s*+ #!autoimport \s*+ \n';
  #$use_auto_import_module_names_re = compile_regexp(qr{$re}oamsx, 'use_auto_import_module_names');
}

my $printed_banner = 0;

sub show_banner {
  return if ($printed_banner);
  $printed_banner = 1;

  print(STDERR print_banner($Y.'perl-mod-deps', 
    $M.'Perl module automatic export generator and dependency tracker', 
    $B, (defined($_[0]) ? ('%{div=long_dashes}'.NL.'%M%{sym=asterisk}  '.$_[0].'%X'.NL) : undef)));
}

sub show_help {
  show_banner('%G%UHelp and Information');

  warn_without_stack_trace('Syntax is: '.$0.' [-options...] file1.pm file2.pm ...');
  exit 1;
}

my %symbol_to_defining_module = ( );
my $max_symbol_name_length = 0;

my %symbol_to_list_of_dependent_modules = ( );

my %module_name_or_filename_to_module = ( );

my %bundle_name_to_list_of_modules = ( );

sub read_and_check_file($$) {
  my ($m, $warning_prefix) = @_;
  # local (*m, *warning_prefix) = \ (@_);

  my $filename = $m->{filename};

  my $warning = undef;

  if ($filename =~ /^\.\#/) {
    $warning = 'an Emacs autosave file';
  } elsif ($filename =~ /\~$/) {
    $warning = 'an Emacs backup file';
  } elsif ((!$is_stdio) && (!((-f $filename) || (-p $filename)))) {
    $warning = 'neither a file, nor a pipe, nor a terminal';
  } elsif (! -r $filename) {
    $warning = 'not readable (check permissions and/or ACLs)';
  }

  if (defined $warning) { goto invalid_file; }

  my $origcode = read_file($filename);

  if (!defined $origcode) { 
    $warning = 'not readable (errno '.($!).', extended error '.($^E).')'; 
    goto invalid_file;
  }

  $m->{origcode} = $origcode;

  my $code = $origcode;
  $m->{code} = $code;

  my ($scope, $module_name) = ($code =~ /$perl_package_decl_re/oamsx);

  $m->{module_name} = $module_name;
  my $is_module = (defined $module_name) ? 1 : 0;

  if (is_empty($module_name) && (!($filename =~ /\.p[lmh]$/oaxi))) {
    if (!($origcode =~ /$perl_program_first_line_shebang_re/oamsx)) {
      $warning = ($DEBUG) ? 'neither a Perl package (missing a package name declaration) '.
        'nor a Perl program (missing #!/usr/bin/perl)' : undef;
      goto invalid_file;
    }
  }
  
  my $effective_filename = 
    ($is_module) ? (($module_name =~ s{::}{/}roamsxg).'.pm') : $filename;

  $m->{effective_filename} = $effective_filename;

  $module_name_or_filename_to_module{$module_name} = $m if (defined $module_name);
  $module_name_or_filename_to_module{$effective_filename} = $m;
  $module_name_or_filename_to_module{$filename} = $m;

  # File appears to be OK:
  return $m;
  
invalid_file:
  print(STDERR $warning_prefix.$warning.$X.NL) if (defined $warning);
  return undef;
}

my $next_decl_label = undef;
my $export_by_default = 1;

my %special_label_names = (
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

sub extract_constants($;+) {
  my ($node, $constants) = @_;
  # local (*node, *constants) = \ (@_);

  $constants //= [ ];

  my $const_constructor = $node->find_first('PPI::Structure::Constructor');
  my $exprlist = undef;

  if ((defined $const_constructor) && (!!$const_constructor)) {
    # List of constants, i.e. "use constant { A => 123, B => 456, ... };" 
    # where the part inside the { ... } is a PPI::Statement::Expression
    # nested within a PPI::Structure::Constructor in this node's list:
    $exprlist = $const_constructor->find_first('PPI::Statement::Expression');
    # Notice we use schildren here instead of children, since "s" means 
    # (s)ignificant, i.e. excluding any whitespace or comment tokens:
    $exprlist = (defined $exprlist) ? $exprlist->{children} : undef;
  } else {
    # Simple one-liner "use constant XYZ => abc;" form: we handle this exactly
    # like the multi-constant expression list above, but the list is simply the
    # original PPI::Statement::Include node's list of children, and it only has
    # one constant to the left of the '=>' operator.
    $exprlist = $node->{children};
  }

  # Only examine a non-null expression list (it could be null if the code 
  # contains some valid but pointless construct like "use constant { };"):
  if (defined $exprlist) {
    foreach my $obj (@$exprlist) {
      if (((ref $obj) eq 'PPI::Token::Operator') && ($obj->content eq '=>')) {
        # the previous (significant) Word token is always the constant's name:
        my $const_name = $obj->sprevious_sibling();
        # check for a major syntax error, i.e. "use constant { <= 0; }"
        # with no constant name before the value mapping operator:
        die if (!defined $const_name); 
        push @$constants,$const_name;
      }
    }
  }

  return (wantarray ? @{$constants} : $constants);
}

my $equals_prefixed_constant_flag_re = qr{^\=(\w+)$}oax;

sub check_for_same_export_name_in_other_modules_and_add($$$$;$) {
  my ($name, $export_optional, $export_tag_label, $m, $node) = @_;
  # local (*name, *export_optional, *export_tag_label, *m, *node) = \ (@_);


  my $name_prefix = '';
  if ($name =~ /$equals_prefixed_constant_flag_re/oax) 
    { $name = $1; $name_prefix = '='; }

  my $existing_def_mod = $symbol_to_defining_module{$name};
  
  if ((defined $existing_def_mod) && ($existing_def_mod->{module_name} ne $m->{module_name})) {
    simple_warning('Symbol '.$G.$name.$R.' was already '.
      $R.'exported by module '.$Y.$existing_def_mod->{module_name}.$R.'; '.
      $R.'overriding with new definition in module '.$Y.$m->{module_name}.$R) unless $no_warnings;
  }
  
  $symbol_to_defining_module{$name} = $m;
  $m->{exports}->{$name_prefix.$name} = $node;
  if ($export_optional || defined($export_tag_label)) {
    my $v = 
    $m->{optional_or_tagged_exports}->{$name_prefix.$name} =
      (defined $export_tag_label) ? $export_tag_label :
        ($export_optional ? undef : undef);
  }

  return (defined $existing_def_mod) ? 1 : 0;
}

my $lineout = 0;

sub add_module_to_bundle($$) {
  my ($m, $bundle_name) = @_;

  my $parent_namespace = parent_module_name($m->{module_name});
  $bundle_name = $parent_namespace.(($bundle_name ne '') ? '::'.$bundle_name : '');
  my $other_mods_in_bundle = append_to_hash_of_arrays(%bundle_name_to_list_of_modules, $bundle_name, $m);
  $m->{bundle_name}->{$bundle_name} = $other_mods_in_bundle;
  return $other_mods_in_bundle;
}

sub analyze_ppi_subtree {
	my ($node, $parent, $m, $level) = @_;

  $level //= 0;

  my $nodetype = ref($node);

  return undef if ($nodetype eq 'PPI::Token::Whitespace' ||
                    $nodetype eq 'PPI::Token::Comment');

  my $subnodes = $node->{children} // [ ];

  my $is_module = (defined ($m->{module_name})) ? 1 : 0;

  #
  # Should we skip recursively descending into subnodes 
  # (e.g. if we already have what we needed?)
  #
  my $skip_descent = 0;
  my $skip_message = 0;
  my $always_skip_message = 0;
  my $line = 0;
  my $column = 0;

  my $message = '';

  $next_decl_label //= '';
  my $export_label = ($next_decl_label eq 'export') ? 1 : 0;
  my $noexport_label = ($next_decl_label eq 'noexport') ? 1 : 0;
  my $export_optional_label = ($next_decl_label eq 'export_optional') ? 1 : 0;
  my $preserve_exports_label = ($next_decl_label eq 'preserve') ? 1 : 0;
  my $export_tag_label = undef;
  if ($next_decl_label =~ /^export_tag_(\w+)$/oax) { $export_tag_label = $1; }

  my $export_requested = $export_by_default ? (!$noexport_label) : 
    ($export_label || $export_optional_label || defined($export_tag_label));

  my $export_status_override = ($export_requested != $export_by_default);

  my $autoimport_label = ($next_decl_label eq 'autoimport') ? 1 : 0;

  my $optional_or_tagged_desc = ($export_tag_label || $export_optional_label) ?
    ($M.' ('.$U.(defined($export_tagged_label) ? 'tag '.$G.$export_tagged_label : 'optional').$M.$UX.')'.$X) : '';

  $next_decl_label = undef;
  
  my $is_import = ($nodetype eq 'PPI::Statement::Include');
  my $is_const_decl = ($is_import && ($node->type eq 'use') && ($node->module eq 'constant'));
  my $is_symbol = ($nodetype eq 'PPI::Token::Symbol');
  my $is_generic_word = ($nodetype eq 'PPI::Token::Word');
  my $is_keyword = ($is_generic_word && (exists $perl_keywords_and_built_in_functions{$node->content // ''}));
  my $is_word = ($is_generic_word && (!$is_keyword));

  if ($is_keyword) { $nodetype = 'PPI::Token::Keyword'; }
  elsif ($is_const_decl) { $nodetype = 'PPI::Statement::Constant'; }

  my $type_icon = '   ';

  if ($nodetype eq 'PPI::Statement::Package') {
    #-------------------------------------------------------------------------
    # Package declaration:
    #   package My::Package::Name;
    #
    # (sets $m->{module_name})
    #
    $skip_descent = 1;
    $m->{module_name} = $node->namespace;
    if ($raw_deps_mode) { 
      $message .= $C.$U.'PACKAGE'.$UX.' '.'mod  '.$Y.format_module_name($m->{module_name}, $Y); 
      $type_icon = PACKAGE_ICON;
    }
  } elsif ($is_const_decl) {
    #-------------------------------------------------------------------------
    # Constant declaration:
    #   use constant { A => 123, B => 456, ... };
    #   ...or...
    #   use constant A => 123;
    #
    # (both may optionally be preceeded by "noexport: use constant ...")
    #
    $skip_descent = 1;
    my @constants = extract_constants($node);
    my $exported = ($is_module && $export_requested);
    my $color = ($exported ? $M : $export_status_override ? $R : $K);

    if ($raw_deps_mode) {
      $message .= $color.($exported ? ($U.'EXPORT'.$UX.' ') : 'NOxport').
        ' '.$M.'cst'.'  ';
      $type_icon = ($exported) ? EXPORTED_ICON : LOCAL_ICON;
      $skip_message |= (!$exported);
    }

    foreach $name (@constants) {
      if ($raw_deps_mode) 
        { $message .= $color.$name.$B.' '.dashed_vert_bar_3_dashes.' '.$K; }
      if ($exported) { 
        check_for_same_export_name_in_other_modules_and_add
          ('='.$name, $export_optional_label, $export_tag_label, $m, $node); 
      }
      $m->{known_local_symbol_names}->{$name} = 1;
    }

    if ($raw_deps_mode) { $message .= $optional_or_tagged_desc; }
  } elsif ($is_import) {
    #-------------------------------------------------------------------------
    # Package import:
    #   use My::Package::Name;                (explicitly imported)
    #   ...or...
    #   autoimport: use My::Package::Name;    (marker added if auto-imported)
    #
    if (($node->type eq 'use') && (!$node->pragma)) {
      $skip_descent = 1;
      $max_module_name_length = max($max_module_name_length, length($node->module));
      if ($autoimport_label) {
        # Just ignore this imported package, since we'll find it automatically
        if ($raw_deps_mode) { $message .= $R.'import  '.'auto '.$R.$node->module; }
      } else {
        $m->{explicitly_imported_modules}->{$node->module} = 1;
        if ($raw_deps_mode) { $message .= $M.'import  '.'expl '.$M.format_module_name($node->module, $M); }
      }
    } else {
      if ($DEBUG) {
        $message .= $R.'import  '.$M.padstring($node->type, 4).' '.
          format_module_name($node->module, $M);
      } else {
        $skip_message = 1;
      }
    }
    $type_icon = IMPORTED_PACKAGE_ICON;
  } elsif ($nodetype eq 'PPI::Statement::Variable') {
    #-------------------------------------------------------------------------
    # Variable declaration:
    #   [our|my|local|state] [$|@|%]varname ... ;
    #   ...or...
    #   [our|my|local|state] ([$|@|%]var1, [$|@|%]var2, ...)
    #
    # (either form may optionally be preceeded by "noexport: our ..."
    #

    #
    # Note that we skip descending into PPI::Statement::Variable nodes, so we'll
    # never directly encounter their PPI::Token::Symbol declarations. Therefore,
    # if we do see a PPI::Token::Symbol node here, it genuinely uses the variable:
    #

    my $scope = $node->type;
    my @symbol_def_list = $node->symbols;

    my $exported = ($is_module && ($scope eq 'our') && $export_requested);
    my $color = ($exported ? $G : $export_status_override ? $R : $K);

    if ($raw_deps_mode) {
      $message .= $color.($exported ? ($U.'EXPORT'.$UX.'  ') :
                  ($export_status_override ? ('NOxport ') : ('declare '))).
                  sprintf('%-3s', substr($scope, 0, 3)).'  ';
      $skip_message |= (!$exported);
      $type_icon = ($exported) ? EXPORTED_ICON : LOCAL_ICON;
    }

    foreach my $name (@symbol_def_list) {
      my $is_export_clause = (($name eq '@EXPORT') || ($name eq '@EXPORT_OK'));
      my $existing = (exists $m->{known_local_symbol_names}->{$name}) ? 1 : 0;

      if ($raw_deps_mode) {
        $message .= $color.$name.$K.($existing ? ' (redeclared)' : '').
          $B.' '.dashed_vert_bar_3_dashes.' '; 
      }

      if ($exported && (!$is_export_clause)) {
        check_for_same_export_name_in_other_modules_and_add
          ($name, $export_optional_label, $export_tag_label, $m, $node); 
      }

      $m->{known_local_symbol_names}->{$name} = 1;
    }

    if ($raw_deps_mode) { $message .= $optional_or_tagged_desc; }
  } elsif ($nodetype eq 'PPI::Statement::Sub') {
    #-------------------------------------------------------------------------
    # Subroutine declaration:
    #   sub mysub { ... }
    #   ...or...
    #   sub mysub($%@+prototype) { ... }
    #   ...or...
    #   sub mysub(...) ;        # (forward declaration)
    #
    # Any of these forms may optionally be preceeded by "noexport: sub ..."
    #
    my $name = $node->name;

    my $exported = ($is_module && $export_requested);
    $skip_message |= (!$exported);

    if ($raw_deps_mode) {
      my $color = ($exported ? $C : $export_status_override ? $R : $K);
      my $prototype = $node->prototype;
      $message .= $color.($exported ? ($U.'EXPORT'.$UX.'  ') : 
                   ($export_status_override ? ('NOxport ') : ('declare '))).
                   'sub'.'  '.$name.($prototype ? ' '.$B.$prototype : '').
                   $optional_or_tagged_desc;
      $type_icon = ($exported) ? EXPORTED_ICON : LOCAL_ICON;
    }
    
    if ($exported) {
      check_for_same_export_name_in_other_modules_and_add
        ($name, $export_optional_label, $export_tag_label, $m, $node); 
    }

    $m->{known_local_symbol_names}->{$name} = 1;
  } elsif ($is_symbol || $is_word) {
    #-------------------------------------------------------------------------
    # Use of variable, subroutine call or constant:
    #   [$|@|%]varname
    #   ...or...
    #   mysub(...)
    #   ...or...
    #   possibly_mysub_or_const
    #
    # Note that it is inherently ambiguous whether or not the given word
    # really refers to a symbol exported by another module - we'll only 
    # know for sure once we work backwards from the export lists.
    #

    my $name = ($is_symbol) ? $node->symbol : $node->content;
    my $sigil = ($is_symbol) ? $node->symbol_type : '';
    my $known_local = (exists $m->{known_local_symbol_names}->{$name});
    my $existing_import = (exists $m->{imported_symbols}->{$name});

    if ($known_local) {
      if ($raw_deps_mode) { 
        $message .= $K.'use-loc '.($is_word ? 'sub' : 'var').'  '.$name;
        $type_icon = LOCAL_ICON;
        $skip_message = 1;
      }
    } else {
      if ($raw_deps_mode) { 
        $message .= $Y.$U.'IMPORT'.$UX.'  '.($is_word ? $C.'sub' : $Y.'var').'  '.
          $name.$K.($existing_import ? ' (reused)' : '');
        $skip_message |= $existing_import;
      }
      
      $type_icon = IMPORTED_ICON;
      if ($existing_import) {
        $m->{imported_symbols}->{$name}++;
      } else { # ! $existing-import
        $m->{imported_symbols}->{$name} = 1;
        my $deplist = $symbol_to_list_of_dependent_modules{$name};
        if (!defined $deplist) {
          $deplist = [ $m ];
          $symbol_to_list_of_dependent_modules{$name} = $deplist;
        } else {
          if ($DEBUG) {
            $message .= $K.'; '.$B.'add to dep list'. #.$deplist.
                  ' (#'.(scalar(@$deplist)+1).')'; 
          }
          push @$deplist, $m;
        }
      }
    }
  } elsif ($is_keyword) {
    #-------------------------------------------------------------------------
    # Keywords (ignored as a no-op)
    #
    if ($DEBUG) {
      $message .= $R.'keyword '.$R.'   '.'  '.$M.$node->content;
    }
    $always_skip_message = 1;
    $skip_descent = 1; # no-op
  } elsif ($nodetype eq 'PPI::Token::Label') {
    #-------------------------------------------------------------------------
    # Labels controlling perl-mod-deps (see documentation for details):
    #
    $skip_descent = 1;
    my $label = ($node->content =~ s/:$//roamsx);

    $next_decl_label =
      ((exists $special_label_names{$label}) || 
         ($label =~ /^ (?: export_tag_ | bundle _?) \w++ $/oax)) ? $label : undef;

    if (is_there($next_decl_label)) {
      if (($next_decl_label eq 'preserve') || ($next_decl_label eq 'nobundle')) {
        $m->{$next_decl_label} = 1;
      } elsif ($next_decl_label =~ /(no)?export_by_default/oax) {
        $export_by_default = ($1 ne 'no'); 
      } elsif ($next_decl_label =~ /^bundle(?: _ (\w*+))?/oax) {
        add_module_to_bundle($m, $1 // $default_bundle_name);
      }
    }

    if ($raw_deps_mode) {
      $message .= $B.$U.'LABEL'.$UX.'   '.'     '.
        $Y.$label.(is_there($next_decl_label) ? $G.' (handled by perl-mod-deps)' : '').$X;
    }
  } else {
    #-------------------------------------------------------------------------
    # Other PPI tokens, statements and structures we don't need to handle:
    #
    if ($DEBUG) {
      $message .= $R.'UNKNOWN '.$R.'   '.'  '.$C.
        ref($node).$K.' = '.$Y.format_chunk($node->content, 120);
    }
    $always_skip_message = 1;
  }

  if ($raw_deps_mode) { 
    $message = line_and_column_header($line, $column, $lineout % 2).$G.' '.
      $type_icon.'  '.$X.
      #($exprtype_to_icon{$nodetype} // checkmark).
      ' '.$X.$message.$X.NL;
  }

  if ($DEBUG) { $skip_message = 0; }
  $skip_message |= $always_skip_message;
  if ($raw_deps_mode && (!$skip_message)) { print(STDERR $message); $lineout++; }

  if (!$skip_descent) {
    foreach $subnode (@$subnodes) {
      my $subtype = ref($subnode);
      next if ($subtype eq 'PPI::Token::Whitespace' || 
               $subtype eq 'PPI::Token::Comment');
      analyze_ppi_subtree($subnode, $node, $m, $level+1);
    }
  }

  return $m;
}

#------------------------------------------------------------------------------
# parse_module($module)
#------------------------------------------------------------------------------
sub parse_module($) {
  my ($m) = @_;
  # local (*m) = \ (@_);


  my $tree = PPI::Document->new($m->{filename}, readonly => 1, tab_width => 2);
  die if (!defined $tree);

  $m->{tree} = $tree;

  $lineout = 0;
  $next_decl_label = undef;
  $export_by_default = 1;

  analyze_ppi_subtree($tree, undef, $m, 0);

  my $filename = $m->{filename};
  my $module_name = $m->{module_name};
  my $is_module = (defined $module_name) ? 1 : 0;
  my $module_or_file_name = $module_name // $filename;
  my $code = \($m->{code});

  $max_module_name_length = max($max_module_name_length, length($module_or_file_name));

  if ($DEBUG) {
    my $message = $K.($is_module ? 'module ' : 'program ').$Y.$U.
      ($module_or_file_name).$X.NL;

    print(STDERR text_in_a_box($message, 0, $Y, 'double'));
  }

  if ($is_module) {
    my $expected_filename_of_module_name = ($module_name =~ s{::}{/}roamsxg).'.pm';
    my $n = length($expected_filename_of_module_name);
    my $actual_filename_stem = substr($filename, length($filename)-$n, $n);
    
    if ($actual_filename_stem ne $expected_filename_of_module_name) {
      simple_warning('Module source file '.$Y.$filename.$R.' specifies inconsistent package name '.$C.$module_name.$R) unless $no_warnings;
    }
  }

  #
  # Remove any automatic imports so we can update them
  #
  #$m->{code} =~ s/($use_auto_import_module_names_re)//oamsxg;

  return $m;
}

#------------------------------------------------------------------------------
# resolve_symbol_and_module_dependency_graphs(@symbol_names, @module_refs);
#
# Our dependency graph resolution algorithm works backwards from each symbol
# exported by each module, since these are easier to positively identify
# without more extensive semantic aware parsing of the perl code of other
# modules and programs which ultimately may use those symbols.
#
# Note that this must be done in a separate pass *after* collecting the
# symbols and module names of *all* relevant source files, since this
# ensures each symbol is correctly mapped to the module that exports it
# regardless of the order in which the input source files were processed.
#
# This function's outputs are added to each module by updating these fields:
#    %dependent_modules
#    %imported_modules
#    @imported_module_names
#    @dependent_module_names
#    @dependent_program_filenames
#------------------------------------------------------------------------------
sub resolve_symbol_and_module_dependency_graphs(++) {
  my ($all_exported_symbol_names, $all_modules) = @_;
  # local (*all_exported_symbol_names, *all_modules) = \ (@_);

  $max_symbol_name_length = maxlength(@$all_exported_symbol_names);
  
  #
  # For each exported symbol name, look up the module where it's defined and
  # the module(s) which use it, then create links in both directions to map:
  #
  # - each module -> all modules or programs that depend on that module 
  # - each module or program -> all modules required by that module or program
  #
  foreach my $symname (@$all_exported_symbol_names) {
    my $m = $symbol_to_defining_module{$symname};
    my $module_name = $m->{module_name};
    my $deplist = $symbol_to_list_of_dependent_modules{$symname} // [ ];
    
    foreach my $depmod (@$deplist) {
      my $dep_module_or_file_name = $depmod->{module_name} // $depmod->{filename};
      $m->{dependent_modules}->{$dep_module_or_file_name} = $depmod;
      $depmod->{imported_modules}->{$module_name} = $m;   
    }
  }

  #
  # In this third and final pass, for each module or program, collect the list
  # of actual names of the modules it requires, and (for modules only) the list
  # of the module names or program filenames which depend on symbols defined by
  # that module. (This makes it trivial to quickly generate the final output
  # in various formats, including Makefile prerequisite lists or graphs):
  #
  foreach my $m (@$all_modules) {
    next if (!defined $m);
    my $module_name = $m->{module_name} // $m->{filename};

    # Fix modules which use their own symbols and thus appear
    # to depend on themselves:
    delete $m->{imported_modules}->{$module_name};
    delete $m->{dependent_modules}->{$module_name};

    my @imported_from_module_names_list;
    foreach $im (values %{ $m->{imported_modules} })
      { push @imported_from_module_names_list, $im->{module_name}; }

    foreach $xim (keys %{$m->{explicitly_imported_modules}}) { 
      next if (exists $m->{imported_modules}->{$xim}); 
      push @imported_from_module_names_list, $xim;
    }

    $m->{imported_module_names} = [ sort @imported_from_module_names_list ];
    
    my @exported_to_dependent_module_names_list;
    my @exported_to_dependent_program_filenames_list;
    
    foreach $em (values %{ $m->{dependent_modules} }) {
      if (defined $em->{module_name}) { 
        push @exported_to_dependent_module_names_list, $em->{module_name};
      } else {
        push @exported_to_dependent_program_filenames_list, $em->{filename};
      }
    }
    
    $m->{dependent_module_names} = [ sort @exported_to_dependent_module_names_list ];
    $m->{dependent_program_filenames} = [ sort @exported_to_dependent_program_filenames_list ];
  }
}

#------------------------------------------------------------------------------
# print_symbol_dependencies(\@symbol_names, $fd = STDERR, $fancy_format = 1)
#------------------------------------------------------------------------------
sub print_symbol_dependencies(+;$$) {
  my ($symbol_names, $fd, $fancy_format) = @_;
  # local (*symbol_names, *fd, *fancy_format) = \ (@_);

  $fd //= STDERR;
  $fancy_format //= is_stderr_color_capable();

  $format = $B.' '.$G.'%-'.$max_symbol_name_length.'s  '.$Y.'%-'.$max_module_name_length.'s'.$K.'  '.$C.'%-30s'.$X.NL;
  printf($fd NL.bg_color_rgb(40, 64, 80).$U.$format.$X, 'Symbol Name', 'Exported by Module', 'Used by Modules'.(' ' x 20));

  my $i = 0;
  foreach my $symname (@$symbol_names) {
    my $m = $symbol_to_defining_module{$symname};
    my $module_name = $m->{module_name};
    my $deplist = $symbol_to_list_of_dependent_modules{$symname} // [ ];
    my $used_by = '';
    foreach my $depmod (@$deplist) 
      { $used_by .= ' '.($depmod->{module_name} // $depmod->{filename}); }
    my $bg = (($i++ % 2) == 1) ? bg_color_rgb(48, 48, 48) : '';
    my $tag = $m->{optional_or_tagged_exports}->{$symname};
    my $namestr = $symname . 
      (exists($m->{optional_or_tagged_exports}->{$symname}) ? 
         ($M.' ('.$U.(defined($tag) ? 'tag '.$G.$tag : 'optional').$M.$UX.')'.$X) : '');
    printf($fd $bg.$format.$X, $symname, $module_name, $used_by);
  }
  print($fd NL);
}

#------------------------------------------------------------------------------
# print_module_dependencies(\@modlist, $fd = STDERR, $fancy_format = 1)
#------------------------------------------------------------------------------
sub print_module_dependencies(+;$$) {
  my ($module_refs, $fd, $fancy_format) = @_;
  # local (*module_refs, *fd, *fancy_format) = \ (@_);

  $fd //= STDERR;
  $fancy_format //= is_stderr_color_capable();

  $format = $B.' '.
    $B.'%-1s'.'  '.
    $C.'%-'.$max_module_name_length.'s'.$B.' '.dashed_vert_bar_3_dashes.' '.
    '%s'.'%-'.$max_module_name_length.'s'.$B.' '.dashed_vert_bar_3_dashes.' '.
    $G.'%-'.$max_module_name_length.'s'.$B.' '.dashed_vert_bar_3_dashes.' '.
    $M.'%-'.$max_module_name_length.'s'.$B.' '.$X.NL;

  printf(STDERR NL.bg_color_rgb(40, 64, 80).$U.$format.$X, 'M',
         'Module name', $Y, 'Requires Mods', 
         'Req by Mods', 'Req by Programs');

  my $heading_bg = bg_color_rgb(64, 64, 96);

  foreach my $m (@$module_refs) {
    next if (!defined $m);
    #$longest_import_mod_name = max($longest_import_mod_name, maxlength($m->{imported_module_names});
    my $module_name = $m->{module_name} // $m->{filename};
    my $imports = $m->{imported_module_names};
    my $depmods = $m->{dependent_module_names};
    my $depprogs = $m->{dependent_program_filenames};

    my $n = max_in_list(scalar(@$imports), scalar(@$depmods), scalar(@$depprogs));

    printf(STDERR $heading_bg.$format.$X, 
      (($m->{module_name}) ? 'M' : ' '),
      format_module_name($module_name, $C), $Y,
      scalar(@$imports).' modules',
      scalar(@$depmods).' modules',
      scalar(@$depprogs).' modules');
  
    for (my $i = 0; $i < $n; $i++) {
      my $bg = (($i % 2) == 1) ? bg_color_rgb(48, 48, 48) : '';
      #if ($i == $n-1) { print(STDERR $U); }
      my $import = $imports->[$i] // '';
      my $is_auto_import = ($import =~ /$auto_import_module_names_re/oamsx);

      my $is_outside_namespace = 
        ($import !~ /$allowed_module_namespaces_re/oa) ? 1 : 0;
      my $color = (($is_auto_import) ? ($is_outside_namespace ? $R : $Y) : $M);
      printf(STDERR $bg.$format.$X,
             ' ', ' ',
             $color,
             format_module_name($import, $color),
             format_module_name($depmods->[$i] // ' ', $G),
             $depprogs->[$i] // ' ');
    }
  }
}

#------------------------------------------------------------------------------
# generate_exports_decl($module)
#------------------------------------------------------------------------------

#
# It's quicker and easier to update the @EXPORT clause using a regexp 
# substitution rather than using PPI to do this, since we can replace
# several elements all at once while precisely specifying the syntax
# of the output code.
#
our $perl_exports_exports_ok_export_tags_clauses_before_re =
  qr{^ \s*+ (?> (?! our) \w+ : ;? \s*+)*+ our \s*}oamsx;

our $perl_exports_exports_ok_export_tags_clauses_after_re =
  qr{\s*+ = \s*+ (?> \# [^\n]++ \n)? 
     \s*+ (?> qw)? \s*+ $parens_re \s*+ \;}oamsx;

our $perl_exports_exports_ok_export_tags_clauses_re =
  qr{(?: 
       $perl_exports_exports_ok_export_tags_clauses_before_re
       @ EXPORT
       $perl_exports_exports_ok_export_tags_clauses_after_re
     )
     (?: 
       \s*+
       $perl_exports_exports_ok_export_tags_clauses_before_re
       @ EXPORT_OK
       $perl_exports_exports_ok_export_tags_clauses_after_re
     )?
     (?: 
       \s*+
       $perl_exports_exports_ok_export_tags_clauses_before_re
       % EXPORT_TAGS
       $perl_exports_exports_ok_export_tags_clauses_after_re
     )?
    }oamsx;

use constant {
  GEN_EXPORTS_DECL_UNCHANGED => 0,
  GEN_EXPORTS_DECL_UPDATED => 1,
  GEN_EXPORTS_DECL_ONLY_GENERATE_NO_UPDATE => 2,
  GEN_EXPORTS_DECL_PRESERVE => 3,
  GEN_EXPORTS_DECL_MISSING_PLACEHOLDER => 4,
  GEN_EXPORTS_DECL_NOT_MODULE => 5,
};

my @gen_exports_decl_result_name = (
  $R.'no new changes'.((!$show_unmodified_modules) ? $K.' (unchanged modules are not listed)' : ''),
  $G.'updated',
  $G.'(only generate without update)',
  $Y.'preserved (not updated)',
  $B.'missing @EXPORT placeholder',
  $K.'not a module'
);
  
sub generate_exports_decl($;$) {
  my ($m, $do_not_update_placeholder) = @_;
  $do_not_update_placeholder //= 0;

  my $result = undef;

  my $filename = $m->{filename};
  my $module_name = $m->{module_name};
  my $is_module = (defined $module_name) ? 1 : 0;
  my $module_or_file_name = $module_name // $filename;

  if (!$m->{module_name}) {
    $m->{code} = $m->{origcode};
    print(STDERR '  '.$K.padstring($filename, $max_module_name_length).
            $Y.'  '.arrow_head.'     '.$Y.'program'.$K.' had no exports, '.
            'but still processed imports'.$X.NL);
    return (wantarray ? (GEN_EXPORTS_DECL_NOT_MODULE, undef) : GEN_EXPORTS_DECL_NOT_MODULE);
  }
    
  my $exported_sub_count = 0;
  my $exported_scalar_count = 0;
  my $exported_array_count = 0;
  my $exported_hash_count = 0;
  my $exported_const_count = 0;

  my @exports = ( );

  my $optional_or_tagged_exports = $m->{optional_or_tagged_exports};
  my $optional_export_count = 0;
  my $tagged_export_count = 0;
  my @optional_exports = ( );
  my %tag_to_sym_list = ( );

  foreach my $name (keys %{$optional_or_tagged_exports}) {
    my $tag = $optional_or_tagged_exports->{$name};
    $tagged_export_count += (defined($tag)) ? 1 : 0;
    $optional_export_count += (!defined($tag)) ? 1 : 0;

    if (defined $tag) { 
      my $taglist = $tag_to_sym_list{$tag};
      if (defined $taglist) {
        push @{$taglist},$name;
      } else {
        $taglist = [ $name ];
        $tag_to_sym_list{$tag} = $taglist;
      }

      $tagged_export_count++;
    }

    # Names in EXPORT_TAGS must also appear in @EXPORT or @EXPORT_OK:
    push @optional_exports,($name =~ s/^\=//roax);
    $optional_export_count++;
  }

  foreach $name (keys %{$m->{exports}}) {
    next if ($name =~ /^\@(EXPORT|ISA|ALL)/oax);
    my $origname = $name;
    my ($symbol, $type, $basename) = ($name =~ /$perl_identifier_sigil_and_symbol_re/oax);

    my $is_const = ($type eq '=') ? 1 : 0;

    $exported_scalar_count += ($type eq '$') ? 1 : 0;
    $exported_array_count +=  ($type eq '@') ? 1 : 0;
    $exported_hash_count +=   ($type eq '%') ? 1 : 0;
    $exported_sub_count +=    ($type eq '') ? 1 : 0;
    $exported_const_count +=  ($is_const)   ? 1 : 0;

    #
    # We only use the '=' sigil to differentiate between subs and consts for
    # counting purposes, but perl doesn't recognize this, so remove it here:
    #
    if ($is_const) { $name = $basename; $type = ''; }

    if (!(exists $optional_or_tagged_exports->{$origname})) { push @exports,$name; }
  }

  @exports = sort @exports;
  @optional_exports = sort @optional_exports;

  # Create an :ALL tag for convenience:
  if (($optional_export_count > 0) || ($tagged_export_count > 0)) 
    { $tag_to_sym_list{'ALL'} = [ @exports, @optional_exports ]; }

  my $outsep = $X.$B.' '.dashed_vert_bar_3_dashes.' '.$X;
  my $export_list_summary =
    $C.padstring($exported_sub_count,    -3).'  &subs'.$outsep.
    $G.padstring($exported_scalar_count, -3).'  $scalars'.$outsep.
    $Y.padstring($exported_array_count,  -3).'  @arrays'.$outsep.
    $M.padstring($exported_hash_count,   -3).'  %hashes'.$outsep.
    $B.padstring($exported_const_count,  -3).'  =consts'.$outsep.
    (($optional_export_count > 0) ?
       $R.padstring($optional_export_count, -3).'  optional'.$outsep : '').
    (($tagged_export_count > 0) ?
       $R.padstring($tagged_export_count, -3).'  tagged'.$outsep : '');

  $m->{code} = $m->{origcode};

  my $new_export_clauses = NL;
  if ($m->{nobundle}) { $new_export_clauses .= 'nobundle:; '; }

  my @member_of_bundles = (exists $m->{bundle_name}) ? (sort keys %{$m->{bundle_name}}) : ( );
  
  foreach my $b (@member_of_bundles) 
    { $new_export_clauses .= 'bundle_'.$b.':; '; }

  if ($m->{preserve}) { $new_export_clauses .= 'preserve:; '; }

  $new_export_clauses .= 'our @EXPORT = # (auto-generated by perl-mod-deps)'.NL.
    '  qw('.join_and_wrap_long_lines(@exports, 78, ' ', '     ', '', '  qw(').');';

  if ($optional_export_count > 0) {
    $new_export_clauses .= NL.NL.'our @EXPORT_OK = qw('.NL.
    '  '.join_and_wrap_long_lines(@optional_exports, 78, ' ', '  ', '', '  ').');';
  }

  if ($tagged_export_count > 0) {
    $new_export_clauses .= NL.'our %EXPORT_TAGS = (';
    foreach $tag (sort keys %tag_to_sym_list) {
      my $taglist = $tag_to_sym_list{$tag};
      my $prefix = NL.'  '.$tag.' => [qw(';
      my $clause = join_and_wrap_long_lines(@{$taglist}, 78, ' ', 
        (' ' x length($prefix)), '', $prefix);
      $new_export_clauses .= NL.$prefix.$clause.')], ';
    }
    $new_export_clauses .= NL.');';
  }

  my $found_export_array = undef;

  if ((defined $m->{code}) && (!$do_not_update_placeholder)) {
    if (!$m->{preserve}) {
      $found_export_array = ($m->{code} =~ 
        s{$perl_exports_exports_ok_export_tags_clauses_re}
         {$new_export_clauses}oamsxg);
    }
  } else {
    #
    # If code is undefined, this means the caller just wants the generated
    # exports array returned as a string of code, rather than replacing the
    # old export declaration in the original source file. (This is used by
    # the module bundle generator and various other uses).
    #
    $found_export_array = 1;
  }

  my $changed_anything = (!defined $m->{origcode}) || ($m->{code} ne $m->{origcode});
  my $mod_name_color = (defined $found_export_array) ? $G : ($m->{preserve}) ? $K : $R;
  my $msg = $mod_name_color.padstring(format_module_name($module_name, $mod_name_color), $max_module_name_length);

  my $do_not_print_message = 0;

  if (defined $found_export_array) {
    if ($do_not_update_placeholder) {
      $result = GEN_EXPORTS_DECL_ONLY_GENERATE_NO_UPDATE;
      $msg = $msg.$G.'  '.checkmark.'  '.$export_list_summary.$X.NL; 
    } elsif ($changed_anything) {
      $result = GEN_EXPORTS_DECL_UPDATED;
      $msg = $msg.$G.'  '.checkmark.'  '.$export_list_summary.$X.NL; 
    } else {
      $result = GEN_EXPORTS_DECL_UNCHANGED;
      if ($show_unmodified_modules) {
        $msg = $msg.$B.'  '.checkmark_in_box.'  '.$B.'(no changes required)'.$X.NL;
      } else {
        $do_not_print_message = 1; 
      }
    }
  } elsif ($m->{preserve}) {
    $msg = $msg.$Y.'  '.asterisk.'     '.$Y.$U.'skipped'.$X.$R.
      ' because preserve label was applied to @EXPORT list'.$X.NL;
    $result = GEN_EXPORTS_DECL_PRESERVE;
  } else { # ! $found_export_array
    $msg = $msg.$R.'  '.x_symbol.'     '.$Y.$U.'skipped'.$X.$R.
      ' because it\'s missing an applicable placeholder @EXPORT list'.$X.NL;
    $result = GEN_EXPORTS_DECL_MISSING_PLACEHOLDER;
  }

  if (!$do_not_print_message) {
    if ($DEBUG) {
      print(STDERR text_in_a_box($msg, -1, $G));
    } else {
      print(STDERR '  '.$msg);
    }
  }    

  return (wantarray ? ($result, $new_export_clauses) : $result);
}

#------------------------------------------------------------------------------
# generate_module_bundle(@list_of_module_refs, $optional_module_name)
#
# Generate source code for a perl module which imports the specified modules
# and then re-exports all of their symbols. Useful for making it easier to
# import a given collection of modules which are typically all used together.
#
# Returns a module hash comprising the generated module and its source code.
#------------------------------------------------------------------------------

sub generate_module_bundle(+$) {
  my ($modules, $bundle_name) = @_;
  # local (*modules, *bundle_name) = \ (@_);

  my $filename = '/dev/stdout';

  if ($bundle_name =~ /^(.+?)\.pm$/oax) {
    $filename = $bundle_name;
    $bundle_name =~ s{$remove_modpath_re}{}oag if defined($remove_modpath_re);
    $bundle_name =~ s{/}{::}oag;
    print(STDERR $Y.$U.'NOTE:'.$X.' creating module named '.
      $G.$bundle_name.$X.' in specified output file '.$Y.$filename.$X.NL.NL);
  }

  #
  # Check to see if any of the requested modules already define any bundles
  # to which they belong. If none of the modules explicitly specify this, we
  # set the default bundle name to whatever the caller requested for the 
  # target bundle name, since this ensures every module listed will match
  # the target bundle name and thus will be included.
  #
  # This policy makes it more convenient to work with bundles on new code bases,
  # or with sets of modules where it makes sense to include every module in the
  # bundle by default, and it would be a waste of effort to manually label each
  # module with the same bundle name, which is easy to forget to do with newly
  # written modules.
  # 

  if (!sizeof(%bundle_name_to_list_of_modules)) {
    if ($bundle_name =~ /::([^:]++)$/oax) {
      $default_bundle_name = $1;
    } else {
      simple_warning('Cannot derive default bundle name from '.
        'specified -bundle='.$bundle_name.' option; assuming "All"');
    }

    print(STDERR $K.' '.dot.' '.$C.$U.'NOTE:'.$UX.$B.' None of the modules '.
            'explicitly specified a bundle name, so setting default to requested '.
            'bundle name '.$G.format_quoted($default_bundle_name).$B.
              ' and module name '.$Y.format_module_name($bundle_name, $Y).$X.NL);
    print(STDERR NL);

    foreach $m (@$modules) {
      next if (defined $m->{nobundle});
      add_module_to_bundle($m, $default_bundle_name);
    }
  } else {
    print(STDERR $K.' '.dot.' '.$C.$U.'NOTE:'.$UX.$B.' Some of the modules already '.
            'explicitly specified the bundle(s) to which they belong'.$X.NL.NL);
  }

  my %exports = ( );
  my %optional_or_tagged_exports = ( );
  my %imported_module_names = ( );
  my %imported_symbols = ( );

  my $out =
    '# -*- cperl -*-'.NL.'# '.NL.
    '# '.$bundle_name.NL.'#'.NL.
    '# Module bundle (automatically generated by perl-mod-deps)'.NL.
    '#'.NL.NL.
    'package '.$bundle_name.';'.NL.NL;

  my $modules_in_bundle = $bundle_name_to_list_of_modules{$bundle_name};

  my $bundle_printable_tree_root = [ 
    $C.format_module_name($bundle_name, $C).$X.$K.' ('.$Y.
      sizeof($modules_in_bundle).$K.' modules in bundle)'.$X
  ];

  foreach $m (@$modules_in_bundle) {
    my $modname = $m->{module_name};

    my $printable_tree_node_label = [ 
      #[ TREE_CMD_SYMBOL, $G.checkmark ],
      $Y.padstring((defined $modname) ? format_module_name($modname, $Y) : $m->{filename}, 40) 
    ];

    my $printable_tree_node = [ $printable_tree_node_label ];
    push @$bundle_printable_tree_root, $printable_tree_node;

    if (!defined $modname) { 
      push @$printable_tree_node_label, 
        ($K.'is not a module', 
         [ TREE_CMD_SYMBOL, $K.box_with_right_slash ]);
      next;
    }

    if ($m->{nobundle}) { 
      push @$printable_tree_node_label, 
        $R.'contains a '.$Y.'nobundle'.$R.' directive',
          [ TREE_CMD_SYMBOL, $R.x_symbol ];
      next; 
    }
    
    my @member_of_bundles = sort keys %{$m->{bundle_name}};

    if (!exists ($m->{bundle_name}->{$bundle_name})) {
      push @$printable_tree_node_label, 
        $B.'does not belong to this bundle '.
         '(it only belongs to bundle(s) '.$C.
           join($K.', '.$C, @member_of_bundles),
         [ TREE_CMD_SYMBOL, $B.x_symbol ]; 
      next;
    }

    my $mod_exports = $m->{exports};
    my $mod_optional = $m->{optional_or_tagged_exports};
    my @optional_syms = sort keys %{$mod_optional};

    $imported_module_names{$modname} = 1;

    my $conflicts = [ ];
    merge_hashes_and_collect_conflicts(%exports, $mod_exports);
    merge_hashes_and_collect_conflicts(%optional_or_tagged_exports, $mod_optional);
    merge_hashes_and_collect_conflicts(%imported_symbols, $mod_exports, $conflicts);
    merge_hashes_and_collect_conflicts(%imported_symbols, $mod_optional, $conflicts);

    my $symcount = sizeof($mod_exports) + sizeof($mod_optional);
    my $conflict_count = sizeof($conflicts);

    push @$printable_tree_node_label,
      $G.'  added '.$Y.padstring($symcount - $conflict_count, -3).$G.' new symbols';

    if ($conflict_count > 0) { 
      push @$printable_tree_node_label, 
        ($R.' (conflicts with '.$M.$conflict_count.$R.' existing symbols):',
         [ TREE_CMD_SYMBOL, $Y.warning_sign ]);

      foreach $conflict (@$conflicts) 
        { push @$printable_tree_node, [ $M.$conflict.$X ]; }
    }

    $out .= 'use '.$modname.';'.NL;
    if ((scalar @optional_syms) > 0) { 
      $out .= 'use '.$modname.NL.
        '  qw('.join_and_wrap_long_lines
          (@optional_syms, 78, ' ', '', '', '  qw(').');'.NL;
    }
  }

  print_tree($bundle_printable_tree_root, STDERR);

  my $m = {
    index => scalar(@modlist),
    filename => $filename,
    module_name => $bundle_name,
    code => undef,
    origcode => undef,
    preserve => 0,
    exports => \%exports,
    optional_or_tagged_exports => \%optional_or_tagged_exports,
    imported_symbols => { },
    explicitly_imported_modules => \%imported_module_names,
    imported_modules => { },
    dependent_modules => { },
    known_local_symbol_names => { }
  };

  # my ($gen_export_decl_result, $generated_export_decl) = generate_exports_decl($m);

  my $generated_export_decl = 'our @EXPORT = # (auto-generated by perl-mod-deps)'.NL.'('.NL;
  my $generated_export_ok_decl = 'our @EXPORT_OK = # (auto-generated by perl-mod-deps)'.NL.'('.NL;

  foreach my $m (@$modules_in_bundle) {
    my $name = $m->{module_name};
    $generated_export_decl .= '  @'.$name.'::EXPORT,'.NL;
    $generated_export_ok_decl .= '  @'.$name.'::EXPORT_OK,'.NL;
  }

  $generated_export_decl .= ');'.NL.NL;
  $generated_export_ok_decl .= ');'.NL.NL;
  
  $out .= 
    NL.'use Exporter::Lite;'.NL.'nobundle:; preserve:; '.
      $generated_export_decl.NL.
      $generated_export_ok_decl.NL;

  # Add the final 'module successfully loaded' return value:
  $out .= '1;'.NL.NL;

  $m->{origcode} = '';
  $m->{code} = $out;

  push @modlist,$m;

  return $m;
}

#------------------------------------------------------------------------------
# update_auto_imports($modref):
#
# Update the automatically derived list of imported modules, by removing any
# old auto-imports and inserting an updated list below the "#!autoimport"
# line in each module (which must already exist for auto-importing to work):
#------------------------------------------------------------------------------

sub update_auto_imports(+) {
  my ($m) = @_;
  # local (*m) = \ (@_);


  #$longest_import_mod_name = max($longest_import_mod_name, maxlength($m->{imported_module_names});
  my $module_name = $m->{module_name} // $m->{filename};
  my $imports = $m->{imported_module_names};
  my $explicit_imports = $m->{explicitly_imported_modules};
  my $depmods = $m->{dependent_module_names};
  my $depprogs = $m->{dependent_program_filenames};
  
  my $out = '#! autoimport {'.NL;

  #$out .= '# Explicit Imports:'.NL;
  #foreach $xim (sort keys %{$explicit_imports})
  #  { $out .= 'use '.$xim.';'.NL; }

  foreach $import (@$imports) {
    next if (exists $explicit_imports->{$import}); 
    # ($import =~ /$auto_import_module_names_re/oamsx);
    $out .= 'use '.$import.';'.NL;
  }

  if (0) {
    # Informational comments:
    $out .= NL.'# Modules which depend on this module:'.NL.
      join_and_wrap_long_lines($m->{dependent_module_names}, 78, ', ', '# ');
    
    $out .= NL.'# Programs which depend on this module:'.NL.
      join_and_wrap_long_lines($m->{dependent_program_filenames}, 78, ', ', '# ');
  }

  $out .= '#! } # (end autoimport)'.NL;

  my $replcount = ($m->{code} =~ s/$auto_import_clause_re/$out/oamsx);
  if (!$replcount) {
    simple_warning('Module '.($m->{module_name} // $m->{filename}).' did not have an #!autoimport marker');
  }

  return $out;
}

#------------------------------------------------------------------------------
# generate_makefile_deps(@list_of_refs_to_modules):
#
# Generate Makefile formatted dependent prerequisite lists for specified 
# modules, returned as a multi-line string:
#------------------------------------------------------------------------------
sub generate_makefile_deps(+;$) {
  my ($modlist, $prefix) = @_;
  # local (*modlist, *prefix) = \ (@_);

  my $out = '';

  $prefix .= '/' if ($prefix !~ /\/$/oax);

  foreach $m (@{$modlist}) {
    next if (!defined($m));

    my $import_list = $m->{imported_module_names};

    $out .= $prefix.$m->{filename}.':';
    
    foreach my $import (@$import_list) {
      next if ($import !~ /$allowed_module_namespaces_re/oa);
      my $import_filename = $prefix.($import =~ s{::}{/}roamsxg).'.pm';
      $out .= ' '.$import_filename;
    }
    $out .= NL;
  }

  return $out;
}

#------------------------------------------------------------------------------
# write_updated_file($module)
#------------------------------------------------------------------------------
sub write_updated_file($) {
  my ($m) = @_;
  # local (*m) = \ (@_);


  my $changed_anything = ($m->{code} ne $m->{origcode});
  if ($no_output) { $changed_anything = 0; }

  if ($changed_anything) {
    if ($is_stdio) {
      print(STDOUT $m->{code});
    } elsif (!$dryrun) {
      write_file($m->{filename}, $m->{code});
    }
  }

  return $changed_anything;
}

#------------------------------------------------------------------------------
# process_command_line(@ARGV):
#------------------------------------------------------------------------------

my %command_line_options = (
  'info' => [ \$info_mode, 0, 'show' ],
  'imports' => [ \$auto_import_mode, 0, 'i' ],
  'exports' => [ \$auto_export_mode, 0, 'e' ],
  'clear-exports' => [ \$clear_exports_mode, 0, 'ce' ],
  'bundle' => [ \$module_bundle_name, OPTION_VALUE_REQUIRED, 'b' ],
  'makefile' => [ \$makefile_mode, 0, ['m', 'mf', 'make'] ],
  'dump' => [ \$raw_deps_mode, 0, 'raw' ],
  'ppi' => [ \$ppi_tree_mode, 0, 'tree' ],
  'quiet' => [ \$quiet, 0, 'q' ],
  'debug' => [ \$debug, 0, 'd' ],
  'no-output' => [ \$no_output, 0, 'noout' ],
  'dryrun' => [ \$dryrun, 0, [ 'dry-run', 'test' ] ],
  'show-unmodified-modules' => [ \$show_unmodified_modules, 0, [
    'list-all', 'all', 'a', 'list-unmodified-modules', 'list-unmodified', 'show-unmodified' ] ],
  'modpath' => [ \@module_search_paths, OPTION_VALUE_REQUIRED, ['path', 'mp', 'p' ] ],
  'namespaces' => [ \@allowed_module_namespaces, OPTION_VALUE_REQUIRED, ['namespace', 'ns', 'n'] ],
);

sub process_command_line {
  my $end_of_args = 0;

  #
  # First we parse all options (starting with a -), 
  # then we will ll make a second pass over the arguments
  # to handle the actual filenames as explained below:
  #
  foreach (@_) {
    #
    # Filenames:
    #
    next if ($_ !~ /^-/oax);
    #
    # Modes:
    #
    if (/^-(?: info|show|dump|analyze)/oax) {
      $info_mode = 1;
    } elsif (/^-imports?/oax) {
      $auto_import_mode = 1;
    } elsif (/^-exports?/oax) {
      $auto_export_mode = 1;
    } elsif (/^-clear-exports/oax) {
      $clear_exports_mode = 1;
    } elsif (/^-bundle = (.+)$/oax) {
      $module_bundle_name = $1;
    } elsif (/^-make/oax) {
      $makefile_mode = 1;
    } elsif (/^-raw/oax) {
      $raw_deps_mode = 1;
    } elsif (/^-ppi/oax) {
      $ppi_tree_mode = 1;
    }
    #
    # Options:
    #
    elsif (/^-q(?:uiet)?/oax) {
      $quiet = 1;
    } elsif (/^-d(?:ebug)?/oax) {
      $DEBUG = 1;
    } elsif (/^-(?:w|nw|nowarn|no-warnings)/oax) {
      $no_warnings = 1;
    } elsif (/^-no-?out/oax) {
      $no_output = 1;
    } elsif (/^-t(?:est)?|-dry-?run/oax) {
      $dryrun = 1;
    } elsif (/^-(?:show|list)-unmodified(?:-modules)?/oax) {
      $show_unmodified_modules = 1;
    } elsif (/^-modpath = (.+)$/oax) {
      @modpath = split(/[:,]/, $1);
      $remove_modpath_re = '(?:\.pm$)|^/?(?:'.join('|', map(quotemeta, @modpath)).')/?';
      $remove_modpath_re = qr{$remove_modpath_re}oa;
      # Generate reasonable list of auto-import prefixes based on names of
      # subdirectories and .pm module files found within each path component:
      push @auto_import_prefixes, create_auto_import_prefixes_from_mod_path(@modpath);
    } elsif (/^-namespaces? = (.+)$/oax) {
      my $arg = $1;
      @allowed_module_namespaces = sort(split(/,/oax, $arg));
      foreach $ns (@allowed_module_namespaces) 
        { $ns .= '::' if ($ns !~ /::$/oax); }

      $allowed_module_namespaces_re = 
        '^(?:'.join('|', map(quotemeta, @allowed_module_namespaces)).')';

      $allowed_module_namespaces_re = qr{$allowed_module_namespaces_re}oa;
    } elsif (/^-(?:make(?:file)?-)?target-prefix-dir = (.*)$/oax) {
      $makefile_target_prefix_dir = $1;
    } elsif (/^-(?:(no)-)?ppi-?cache (?> = (.*+))?$/oax) {
      $ppi_cache_path = (($1 // '') ne 'no') ? 
        ($2 //  '/tmp/ppi-cache-'.getuid()) : undef;
    }
    #
    # Meta options
    #
    elsif ($_ eq '--') {
      last;
    } elsif (/^-/oax) {
      simple_warning('perl-mod-deps: Invalid option '.$_);
      return 0;
    }
  }

  #
  # Process specified filenames now that we know about any options 
  # which could affect the set of files we will actually be using:
  #
  if (defined $module_bundle_name) {
    $module_bundle_filename = ($module_bundle_name =~ s{::}{/}roaxg);
    if ($module_bundle_filename !~ /\.pm$/) { $module_bundle_filename .= '.pm'; }
    $module_bundle_filename = realpath($module_bundle_filename) // $module_bundle_filename;
  };

  foreach $arg (@_) {
    #
    # Filenames:
    #
    if ($end_of_args || $arg =~ /^[^-]/oax) {
      my $argpath = realpath($arg);
      next if (defined $module_bundle_filename) && (realpath($arg) eq $module_bundle_filename);
      add_module_or_program($arg);
    } elsif ($arg eq '--') {
      $end_of_args = 1;
    } # (otherwise it must be an option which we already processed above)
  }

  return 1;
}

sub main {
  if (!process_command_line(@_)) {
    show_help();
    exit 1;
  }

  if (!scalar(@modlist)) { 
    if (!(-f STDIN || -p STDIN)) {
      show_help();
      exit 1;
    }

    add_module_or_program('/dev/stdin'); 
    $is_stdio = 1; 
  }

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

    $message = '%M%{sym=asterisk}  %Y'.$message.' %C'.scalar(@modlist).'%Y Perl source files:%X'.NL;
    if ($is_stdio) { $message .= '%B(Processing stdin -> stdout instead of updating files)'.NL; }
    show_banner();
    print(STDERR text_in_a_box($message, 0, $R, 'rounded', 'single'));
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
}

1;
