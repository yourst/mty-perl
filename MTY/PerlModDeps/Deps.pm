# -*- cperl -*-
#
# MTY::PerlModDeps::Module
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::PerlModDeps::Deps;

use integer; use warnings; use Exporter qw(import);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Display::Colorize;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::Tree;
use MTY::Display::TextInABox;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::PerlRegExpParser;
use MTY::RegExp::PerlSyntax;
use MTY::Common::PerlSourceTools;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
use MTY::System::POSIX;

use MTY::PerlModDeps::Common;
use MTY::PerlModDeps::Module;
#pragma end_of_includes

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(generate_makefile_deps print_module_dependencies
     print_symbol_dependencies resolve_symbol_and_module_dependency_graphs);

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
  printfd($fd, NL);
}

#------------------------------------------------------------------------------
# print_module_dependencies(\@modlist, $fd = STDERR, $fancy_format = 1)
#------------------------------------------------------------------------------
sub print_module_dependencies(+;$$) {
  my ($module_refs, $fd, $fancy_format) = @_;

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
      format_perl_package_name($module_name, $C), $Y,
      scalar(@$imports).' modules',
      scalar(@$depmods).' modules',
      scalar(@$depprogs).' modules');
  
    for my $i (0..($n-1)) {
      my $bg = (($i % 2) == 1) ? bg_color_rgb(48, 48, 48) : '';
      #if ($i == $n-1) { prints(STDERR $U); }
      my $import = $imports->[$i] // '';
      my $is_auto_import = ($import =~ /$auto_import_module_names_re/oamsx);

      my $is_outside_namespace = 
        ($import !~ /$allowed_module_namespaces_re/oa) ? 1 : 0;
      my $color = (($is_auto_import) ? ($is_outside_namespace ? $R : $Y) : $M);
      printf(STDERR $bg.$format.$X,
             ' ', ' ',
             $color,
             format_perl_package_name($import, $color),
             format_perl_package_name($depmods->[$i] // ' ', $G),
             $depprogs->[$i] // ' ');
    }
  }
}

#------------------------------------------------------------------------------
# generate_makefile_deps(@list_of_refs_to_modules):
#
# Generate Makefile formatted dependent prerequisite lists for specified 
# modules, returned as a multi-line string:
#------------------------------------------------------------------------------
sub generate_makefile_deps(+;$) {
  my ($modlist, $prefix) = @_;

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
