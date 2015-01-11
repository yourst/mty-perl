# -*- cperl -*-
#
# MTY::PerlModDeps::Exports
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::PerlModDeps::Bundle;

use integer; use warnings; use Exporter::Lite;

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;

use MTY::Filesystem::Files;

use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::Tree;
use MTY::Display::TextInABox;

use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::PerlSyntax;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
use MTY::System::POSIX;

use MTY::PerlModDeps::Common;
use MTY::PerlModDeps::Module;

#pragma end_of_includes

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(generate_module_bundle);

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

  my $filename = '/dev/stdout';

  if ($bundle_name =~ /^(.+?)\.pm$/oax) {
    $filename = $bundle_name;
    $bundle_name =~ s{$remove_modpath_re}{}oag if defined($remove_modpath_re);
    $bundle_name =~ s{/}{::}oag;
    printfd(STDERR, $Y.$U.'NOTE:'.$X.' creating module named '.
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

    printfd(STDERR, $K.' '.dot.' '.$C.$U.'NOTE:'.$UX.$B.' None of the modules '.
            'explicitly specified a bundle name, so setting default to requested '.
            'bundle name '.$G.format_quoted($default_bundle_name).$B.
              ' and module name '.$Y.format_module_name($bundle_name, $Y).$X.NL);
    printfd(STDERR, NL);

    foreach $m (@$modules) {
      next if (defined $m->{nobundle});
      add_module_to_bundle($m, $default_bundle_name);
    }
  } else {
    printfd(STDERR, $K.' '.dot.' '.$C.$U.'NOTE:'.$UX.$B.' Some of the modules already '.
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
        '  qw('.wrap_long_lines(@optional_syms, 78, ' ', '', '     ', '', '  qw(').');'.NL;
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