#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::ListDeps::Perl: plugin for Perl programs and modules
#
# Copyright 1997 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::ListDeps::Perl;

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
use Config;
use Module::CoreList;

#pragma end_of_includes

my %perl_config = %Config;
my $perl_binary = resolve_path($perl_config{perlpath});

# Find all modules already distributed with Perl itself:
my $perl_version_vstring = $Module::CoreList::VERSION;
my %core_modules = %{$Module::CoreList::version{$perl_version_vstring}};
my @core_modules = sort keys %core_modules;

# my $perl_shebang_contents_re = qr{perl[^/]*}oax;

my $current_perl_binary = $Config{perlpath}; # (or try $Config{startperl}, which includes the shebang)
my $perl_interp_names = [ $current_perl_binary, '/usr/bin/perl*', '/usr/local/bin/perl*', '/bin/perl*' ];

my $perl_emacs_modes = [ qw(perl cperl perl.pm cperl.pm) ];

use constant {
  COMMON_PERL_SOURCE_TYPE_FLAGS => SOURCE_FLAG_COMPILABLE | SOURCE_FLAG_INTERPRETED | SOURCE_FLAG_INVARIANT_SYMBOLIC_DEPS_TO_FILENAMES,
};

my $supported_source_types = {
  perl => {
    description => 'Perl program',
    flags => SOURCE_FLAG_PROGRAM | COMMON_PERL_SOURCE_TYPE_FLAGS,
    suffixes => [ qw(pl PL perl) ],
    interps => $perl_interp_names,
    emacs_modes => $perl_emacs_modes,
    tree_node_symbol => Y.x_signed_light.' ',
  },
 
  perl_module => {
    description => 'Perl module or package',
    flags => SOURCE_FLAG_INCLUDABLE | COMMON_PERL_SOURCE_TYPE_FLAGS,
    suffixes => [ qw(pm al) ],
    interps => $perl_interp_names,
    emacs_modes => $perl_emacs_modes,
    tree_node_symbol => G.p_in_circle.' ',
  },

  perl_header => {
    description => 'Perl header',
    flags => SOURCE_FLAG_INCLUDABLE | COMMON_PERL_SOURCE_TYPE_FLAGS,
    suffixes => [ qw(ph) ],
    tree_node_symbol => M.italic_lowercase_h.' ',
  },
};

my $include_perl_core_deps = 0;
my $include_perl_sys_deps = 0;

my @perl_lib_dirs = ( );
my $include_pmc_files = 1;

my $command_line_options = {
  'libdir' => [ \@perl_lib_dirs, OPTION_LIST, [ 'L', 'perllibs', 'lib', 'libs' ] ],
  'perl-core-deps' => [ \$include_perl_core_deps, 0, [ 'coredeps' ] ],
  'perl-sys-deps' => [ \$include_perl_sys_deps, 0, [ 'sysdeps' ] ],
  'pmc' => [ \$include_pmc_files, 0, [ 'pmc-first' ] ],
};

my $option_descriptions = [
  'libdir' => 'Specify additional library directory stems to check before @INC',
  'perl-core-deps' => 'Include dependencies on packages distributed with Perl',
  'perl-sys-deps' => 'Include dependencies on system packages installed in /usr/lib/perl5/... which are not Perl core packages',
  'pmc' => 'Find .pmc files before equivalently named .pm files (use -no-pmc to disable)',
];

my %perl_package_to_source = ( );
my %perl_package_to_deps = ( );

my $searchable_perl_lib_dirs;
my $perl_libs_base_dir;

noexport:; sub configure($++;+) {
  my ($plugin, $command_line_option_values, $filenames, $cache) = @_;

  if (!@perl_lib_dirs) { @perl_lib_dirs = @INC; }
  @perl_lib_dirs = grep { is_string($_) && ($_ !~ '/.perlcache/') } @perl_lib_dirs;
  $searchable_perl_lib_dirs = MTY::Filesystem::SearchableDirList->new([ @perl_lib_dirs ], 'perl_lib_dirs');

  my @search_path_to_short_name = (
    $perl_config{vendorlib}, SYSTEM_PATH_PREFIX_COLOR.'vend',
    $perl_config{privlib}, COMPILER_PATH_PREFIX_COLOR.'perl',
    $perl_config{sitelib}, EXTRA_PATH_PREFIX_COLOR_2.'site',
    (map { ($perl_config{$_} => EXTRA_PATH_PREFIX_COLOR_1.$_) } qw(archlib vendorarch sitearch)));

  $perl_libs_base_dir = (($perl_config{sitelib_stem} // '/usr/lib/perl5/site_perl') =~ s{/site_perl$}{}roax).'/';
  push @search_path_to_short_name, ($perl_libs_base_dir => SYSTEM_PATH_PREFIX_COLOR.'perllibs');

  register_path_prefixes(@search_path_to_short_name);

  return 1;
}

INIT {
  register_file_type_plugin(
    'Perl',
    __PACKAGE__,
    $supported_source_types,
    $command_line_options,
    $option_descriptions);
};

noexport:; sub include_package_as_dep($) {
  my ($package) = @_;

  my $filename = resolve_perl_package_to_filename($package);
  my $is_core = exists($core_modules{$package});
  my $is_system = (defined $filename) 
    ? (starts_with($filename, $perl_libs_base_dir)) : 0;

  return (($is_core && (!$include_perl_core_deps)) ||
            $is_system && (!$include_perl_sys_deps)) ? 0 : 1;
}

method:; sub new($$$;+$$$$) { # (constructor)
  my ($class, $filename, $code, $type, $parent, $suffix, $interp, $emacs_mode) = @_;

  my $current_package = undef;
  my $primary_package = undef;

  my %package_to_deps = ( );
  my $current_package_deps = undef;
  my %all_deps = ( );
  my $is_module = 0;

  while ($code =~ /$perl_package_decls_and_deps_re/oamsxg) {
    my ($keyword, $package) = ($1, $2);
    # skip package or use clauses within comments, strings, POD docs, etc.:
    next if (!length $keyword); 

    if ($keyword eq 'package') {
      $type = $supported_source_types->{perl_module};
      $is_module = 1;
      $current_package = $package;
      $primary_package //= $current_package;
      $current_package_deps = $package_to_deps{$current_package} // [ ];
      $package_to_deps{$current_package} //= $current_package_deps;
      if ($verbose) { printfd(STDERR, 'pkg '.$current_package.' (in '.$filename.')'.NL); }
    } elsif ($keyword eq 'use' || $keyword eq 'require') {
      if (!defined $current_package) {
        # using another package without declaring our own package name
        # implies this is a program rather than a module:
        $type = $supported_source_types->{perl};
        $is_module = 0;
        # Scripts don't usually define a package name,
        # so use the filename instead:
        $current_package = $filename;
        $primary_package //= $current_package;
        $current_package_deps = $package_to_deps{$current_package} // [ ];
        $package_to_deps{$current_package} //= $current_package_deps;
        if ($verbose) { printfd(STDERR, 'pkg '.$current_package.' (implied by '.$filename.')'.NL); }
      }

      push @$current_package_deps, $package;
      $all_deps{$package} = 1;
      if ($verbose) { printfd(STDERR, 'use '.$package.NL); }
    } elsif ($keyword eq 'pragma' && $package eq 'end_of_includes') {
      if ($verbose) { printfd(STDERR, 'end of includes'.' (in '.$filename.')'.NL); }
      last;
    } elsif ($keyword eq '__DATA__' || $keyword eq '__END__') {
      if ($verbose) { printfd(STDERR, 'end of perl code due to ', $keyword, NL); }
      last;
    }
  }

  my $packages = [ sort keys %package_to_deps ];

  my @excluded_external_deps = ( );

  my $direct_symbolic_deps = [ grep { 
    my $ok = include_package_as_dep($_);
    if (!$ok) { push @excluded_external_deps, $_; }
    $ok;
  } sort keys %all_deps ];

  my $this = MTY::ListDeps::Source->new(
    $filename, $code, $type, $direct_symbolic_deps, $parent,
    $suffix, $interp, $emacs_mode);

  # Set file type specific attributes:
  setfields $this,
    is_module => $is_module,
    primary_package => $primary_package,
    packages => $packages,
    package_to_deps => \%package_to_deps;

  if (@excluded_external_deps) 
    { $this->{excluded_external_deps} = \@excluded_external_deps; }

  foreach (@$packages) { 
    $perl_package_to_source{$_} = $this; 
    $perl_package_to_deps{$_} = $package_deps{$_};
  }

  return bless $this, $class;
}

noexport:; sub resolve_perl_package_to_filename($) {
  my ($symdep) = @_;

  #
  # If the dependency is in one of the quoted forms:
  #
  #   require "xxx";
  #   require 'xxx';
  #
  # this means we should literally search every directory in @INC
  # for the filename or subpath within the quotes, rather than
  # converting it from a '::' delimited package namespace into
  # a subpath to that module, since 'require "A::B::CC" literally
  # means look for a file called "A::B::C", not "A/B/C.pm".
  #
  my ($quoted_subpath) = ($symdep =~ $perl_quoted_string_re);

  if ((defined $quoted_subpath) && ($quoted_subpath =~ /\$/oamsx)) {
    # Quoted subpath passed to require refers to an interpolated variable:
    # there is no way we can resolve that into an actual filename here,
    # so just return undef so the caller will treat it like a missing file:
    return undef;
  }
  
  my $subpath = $quoted_subpath // 
    ($symdep =~ s{$perl_package_namespace_separator_re}{/}roaxg);

  # look for .pmc files before .pm files:
  my $alternatives = (defined $quoted_subpath) ? $quoted_subpath : 
    ($include_pmc_files) ? [ $subpath.'.pmc', $subpath.'.pm' ] : $subpath;

  my $filename = $searchable_perl_lib_dirs->get($alternatives);

  return $filename;
}

method:; sub resolve_symbolic_dep_to_filename(+$) {
  my ($this, $symdep) = @_;
  return resolve_perl_package_to_filename($symdep);
}

1;
