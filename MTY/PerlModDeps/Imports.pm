# -*- cperl -*-
#
# MTY::PerlModDeps::Exports
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::PerlModDeps::Imports;

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
use MTY::RegExp::PerlRegExpParser;
use MTY::RegExp::PerlSyntax;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
use MTY::System::POSIX;

use MTY::PerlModDeps::Common;
use MTY::PerlModDeps::Module;


#pragma end_of_includes

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(create_auto_import_module_names_re
     create_auto_import_prefixes_from_mod_path show_auto_import_prefixes
     update_auto_imports);
#
# Instantiate a container for this module or perl program file:
# Make sure we initialize the correct data types for each field:
#

sub create_auto_import_prefixes_from_mod_path(+) {
  my ($list) = @_;

  my @out = ( );
  my $DEBUG = 0;
  foreach $p (@$list) {
    $p = realpath($p);
    opendir(my $dirfd, $p) || die "Cannot open module path directory '$p' ($!)";
    my @files_and_subdirs = readdir($dirfd);
    closedir $dirfd;
    if ($DEBUG) {
      printfd(STDERR, $B.' '.arrow_head.' '.$Y.$U.'Module path directory '.
              $K.left_quote.$C.$p.$K.right_quote.$Y.' has '.$C.
                scalar(@files_and_subdirs).$Y.' entries:'.$X.NL);
    }

    foreach $f (@files_and_subdirs) {
      next if ($f =~ /^\./oamsx); # skip dot files + . and .. dirs
      $f = resolve_path($p.'/'.$f);
      my ($basename, $dir, $suffix) = split_path_version_aware($f);
      $dir //= ''; $suffix //= '';
      if ($DEBUG) {
        printfd(STDERR, $G.'   '.checkmark.' '.$K.'dir '.$Y.$dir.$K.' name '.$C.$basename.$K);
        if (is_there($suffix)) { printfd(STDERR, ' suffix '.$G.$suffix.$K); }
        printfd(STDERR, $B.' '.large_arrow_barbed.' ');
      }
      
      # ignore files and dirs that aren't valid package names
      if ($basename !~ /^\w+$/) {
        if ($DEBUG) { printfd(STDERR, $K.' (skipped - not a valid package name)'.$X.NL); }
        next;
      }
      if ((-f $f) && ($suffix eq '.pm')) {
        if ($DEBUG) { printfd(STDERR, $C.$basename.$K.' (module)'.$X.NL); }
        push @out,$basename;
      } elsif ((-d $f) && (length($suffix) == 0)) {
        if ($DEBUG) { printfd(STDERR, $Y.$basename.$G.'::'.$K.' (package hierarchy)'.$X.NL); }
        push @out,($basename.'::');
      }
    }
  }
  return (wantarray ? @out : \@out);
}

sub show_auto_import_prefixes {
  printfd(STDOUT, $B.' '.arrow_head.' '.$C.$U.'Package name prefixes of modules to automatically import:'.$X.NL);
  my $n = maxlength(@auto_import_prefixes);
  foreach $p (@auto_import_prefixes) {
    my $s = $p;
    $s = padstring($s, $n);
    #my ($hierarchy, $module) = ($s =~ /^([\w\:]+?) :: ([^\:]*)$/oamsxg);
    #$hierarchy //= '';
    #$module //= ''; 
    #$hierarchy =~ s/::/${B}::${Y}/oamsxg;

    printfd(STDOUT, ' '.$G.checkmark.' '.$Y.$s.$X.NL);
  }

  #show_compiled_regexp('auto_import_module_names', \$auto_import_module_names_re);
}

sub create_auto_import_module_names_re(+) {
  my ($list) = @_;

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

#------------------------------------------------------------------------------
# update_auto_imports($modref):
#
# Update the automatically derived list of imported modules, by removing any
# old auto-imports and inserting an updated list below the "#!autoimport"
# line in each module (which must already exist for auto-importing to work):
#------------------------------------------------------------------------------

sub update_auto_imports(+) {
  my ($m) = @_;

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
      wrap_long_lines($m->{dependent_module_names}, 78, ', ', '# ', '# ', '', '');
    $out .= NL.'# Programs which depend on this module:'.NL.
      wrap_long_lines($m->{dependent_program_filenames}, 78, ', ', '# ', '# ', '', '');
  }

  $out .= '#! } # (end autoimport)'.NL;

  my $replcount = ($m->{code} =~ s/$auto_import_clause_re/$out/oamsx);
  if (!$replcount) {
    simple_warning('Module '.($m->{module_name} // $m->{filename}).' did not have an #!autoimport marker');
  }

  return $out;
}
