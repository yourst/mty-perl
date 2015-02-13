# -*- cperl -*-
#
# MTY::Common::ModuleCache
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#
# Maintains a persistent cache that maps each Perl package name to the 
# module file (*.pm) which provides the latest version of that package.
#
# Without this facility, every time a Perl program is executed, Perl's
# dynamic loader will waste time needlessly searching for both a .pm
# and .pmc file for every used or required package in every directory
# listed in @INC until it finds a matching module file. 
#
# Most other dynamic linkers (like ld.so) avoid this by maintaining a 
# persistent cache (e.g. /etc/ld.so.cache) so they can directly open 
# the proper file on the first try. Perl does not do this for various
# reasons, mainly because there are scenarios where the user may want
# to override the cached package selections, but in practice these
# mappings do not need to be changed every time each program is run
# (except perhaps when testing out various substitute modules).
#
# This package remedies this inefficiency by adding a per-user cache
# directory as the first directory in @INC to be searched, followed
# by a callback function which adds any uncached packages to this
# first directory (so Perl won't need to even invoke the callback 
# the next time the package is requested), and finally followed by
# the remaining directories in @INC as a fallback and so this 
# package knows which directories to search during a cache miss.
#
# The cache directory is actually a directory tree structured as
# Perl expects, i.e. My::Module::Name is cached in the directory
# /home/<username>/.perlcache/v5.x.x/My/Module/Name.pmc, which is
# a symlink to the real location of the latest version of that
# package (e.g. in /usr/lib/perl5/.../My/Module/Name.pm). On most
# modern filesystems, it would be more efficient to simply put
# every cached package in a single directory (named with the '::'
# separated notation), but this ends up being slower since Perl
# would need to invoke our callback every time it loads a package
# rather than bypassing it entirely by just finding the package
# in the very first directory in @INC, so this is the method we
# actually implement here.
#
# This package also provides a convenient means of logging the 
# order in which packages are loaded at startup, as well as
# listing all used packages (and denoting which ones were not
# cached yet) right before the program exits. This facility is
# enabled by setting the environment variable PERL_CACHE_DEBUG=1.
#

package MTY::Common::ModuleCache;

preserve:; our @EXPORT = ( );

my $cache_dir;
my $debug;
my ($directory_separator_re, $strip_filename_re, $strip_trailing_slashes_re, $slash_re, $dot_pm_re);
my $prepended_code;

#
# For performance reasons this constant is not enabled by default;
# it must be set to 1 before PERL_CACHE_DEBUG has any effect:
#
sub DEBUG { 0; }

BEGIN {
  $debug = (length($ENV{PERL_CACHE_DEBUG} // '') > 0) && DEBUG;
};

sub debuglog($) {
  my ($message) = @_;
  return if (!$debug);
  syswrite(STDERR, '['.$message.']'."\n");
}

BEGIN {
  $directory_separator_re = qr{/++}oamsx;
  $strip_filename_re = qr{[^/]++ /*+ \Z}oamsx;
  $trailing_slashes_re = qr{/++ \Z}oamsx;
  $normalize_trailing_slashes_re = qr{[^/] \K /*+ \Z}oamsx;
  $slash_re = qr{/}oamsx;
  $dot_pm_re = qr{\.pmc? \Z}oamsx;
  $prepended_code = '';
};

#
# These functions are typically faster than regexps for the
# specific simple scenarios they are designed to handle:
#
sub starts_with($$) {
  my ($s, $prefix) = @_;
  return (((length $s) >= (length $prefix)) && 
            (substr($s, 0, length($prefix)) eq $prefix)) ? 1 : 0;
}

sub remove_from_start($$) {
  my ($s, $prefix) = @_;
  my $n = length($prefix);
  my $removed = (((length $s) >= $n) && (substr($s, 0, $n) eq $prefix));
  $s = ($removed) ? substr($s, $n) : $s;
  return (wantarray ? ($s, $removed) : $s);
}

sub ends_with($$) {
  my ($s, $suffix) = @_;
  return (((length $s) >= (length $suffix)) && 
            (substr($s, -length($suffix), length($suffix)) eq $suffix)) ? 1 : 0;
}

#
# Creates every intermediate directory along the specified path,
# assuming all directories in base_path already exist (or starting
# from the root directory otherwise). Both path and base_path must
# already end in '/'. The permissions of each directory default to
# rwxr-xr-x (0755) if not specified.
#
sub mkdirs($;$$) {
  my ($path, $base_path, $perms) = @_;
  $path //= tr{/}{/}s; # remove things like //duplicate/slashes////here////

  $base_path //= '/';
  $perms //= 0755; # 0755 = rwxr-xr-x
  # Check if the full path already exists:
  return $path if (-d $path);
  
  # Try to simply create the directory, which will succeed if the parent 
  # directory already exists (which is a very common scenario when a
  # sorted list of paths in a directory hierarchy are created in order):
  return $path if (mkdir($path, $perms));

  # Fall back to the "one directory component at a time" method,
  # starting from the base path we know exists already:
  my $path_so_far = $base_path;
  $path = remove_from_start($path, $path_so_far);

  foreach my $dir (split $directory_separator_re, $path) {
    $path_so_far .= $dir.'/';
    next if (-d $path_so_far);
    mkdir($path_so_far, $perms) || return undef;
  }

  return $path_so_far;
}

sub get_home_dir() {
  my $dir = $ENV{HOME};
  if (defined $dir) { return $dir; }

  my $euid = $>;
  my @info = getpwuid($euid);
  $dir = $info[7];
  if ((defined $dir) && (-d $dir)) { return $dir; }

  $dir = '/tmp/uid-'.$euid;
  if (-d $dir) { return $dir; }
  mkdir($dir);
  return (-d $dir) ? $dir : undef;
}

sub get_cache_dir() {
  $dir = $ENV{PERL_LIB_CACHE}; # // '/usr/lib/perl5/.cache/'.$ver;
  if ((defined $dir) && (-d $dir)) { 
    # make sure it ends in a single slash, 
    # and remove any redundant slashes (e.g. //a/b/c///)
    $dir .= '/';
    $dir =~ tr{/}{/}s;
    return $dir;
  }

  my $ver = $^V;

  my $homedir = get_home_dir();
  if (!defined $homedir) { return undef; }

  my $dir = $homedir.'/.perlcache/'.$ver.'/';
  if (-d $dir) { return $dir; }

  mkdir($homedir.'/.perlcache/');
  mkdir($dir);
  if (-d $dir) { return $dir; }

  return undef;
}

sub find_package($) {
  my ($relative_filename) = @_;

  my $relative_pmc_filename = $relative_filename.'c';

  foreach my $d (@INC) {
    next if (ref $d); # skip our code ref callback

    my $dir = ($d =~ s{$normalize_trailing_slashes_re}{/}roamsxg);
    next if ($dir eq $cache_dir);

    my $path = $dir.$relative_pmc_filename;
    # debuglog('  '.$dir.': try path "'.$path.'"');
    if ((-r $path) && (! -d _)) { return $path; }

    $path = $dir.$relative_filename;
    # debuglog('  try path "'.$path.'"');
    if ((-r $path) && (! -d _)) { return $path; }
  }

  return undef;
}

#
# This is the main callback function invoked by Perl as the
# second entry in @INC whenever it cannot find a package in
# the cache directory listed as the first entry in @INC:
#
sub update_cache($) {
  my ($relative_filename) = @_;
  $relative_filename //= '<undef>';

  # Skip the update if it already exists in the cache:
  my $cached_pmc_path = $cache_dir.($relative_filename =~ s{$dot_pm_re}{.pmc}roamsx);

  return if (-e $cached_pmc_path);

  my $package = ($relative_filename =~ s{$slash_re}{::}roamsxg =~ s{$dot_pm_re}{}roamsx);

  my $found = find_package($relative_filename);

  if (!$found) {
    debuglog('Cannot find package '.$package) if (DEBUG && $debug);
    return;
  }

  my $relative_parent_dir = ($cached_pmc_path =~ s{$strip_filename_re}{}roamsx);
  mkdirs($relative_parent_dir, $cache_dir) || die("Cannot create directories in path '$cached_pmc_path' for module '$relative_filename'");

  if (symlink($found, $cached_pmc_path)) {
    debuglog('Added package '.$package.' to cache from '.$found) if (DEBUG && $debug);
    return;
  } else {
    debuglog('Cannot create symlink from '.$found.' to '.$cached_pmc_path.' (error '.$!.')') if (DEBUG && $debug);
    return;
  }

  return;
}

sub package_load_hook {
  my ($thisfunc, $relative_filename) = @_;
  return update_cache($relative_filename);
}

BEGIN {
  $cache_dir = get_cache_dir();
  if (!defined $cache_dir) { return; }

  debuglog('Perl library cache dir is in '.$cache_dir) if (DEBUG && $debug);
}

BEGIN {
  #
  # The cache directory will be the first listed in @INC, so Perl 
  # won't even call our hook once each package has been cached:
  #
  unshift @INC, $cache_dir, \&package_load_hook;

  print(STDERR '[@INC is now '.join(' ', @INC)."]\n") if (DEBUG && $debug);
}

sub show_all_used_modules() {
  printf(STDERR "\n".'Modules used:'."\n\n");
  my $maxn = 0;
  foreach (keys %INC) {
    my $name = ($_ =~ s{/}{::}roaxg =~ s{\.pmc?$}{}roaxg);
    $n = length($name); $maxn = $n if ($n > $maxn);
  }
  my $format = '  %-'.$maxn.'s  =>  %-8s  %s'."\n";

  my $cached_count = 0;

  while (my ($m, $f) = each %INC) {
    my $name = (($m // '<undef>') =~ s{/}{::}roaxg =~ s{\.pmc?$}{}roaxg);
    my $cached = starts_with($f, $cache_dir) ? 1 : 0;
    $cached_count += $cached;
    print(STDERR sprintf($format, $name, ($cached ? '<cached>' : ''), ($cached ? $m : $f)));
  }

  print(STDERR "\n".'Total of '.(scalar keys %INC).' modules loaded ('.$cached_count.' from cache)'."\n");
  print(STDERR 'Cache directory is '.$cache_dir."\n\n");
}

#
# Sometimes we will miss any packages required before this package
# was used, so we intercept the program right before it exits to
# add these packages to the cache.
#
# (In theory this package could be simplified by only updating the
# cache when the program exits, rather than adding a hook to @INC;
# we may switch to this approach in a later version of this package).
#
sub add_missing_modules_to_cache() {
  my $updated_count = 0;

  debuglog("Adding any missed modules to the cache...") if (DEBUG && $debug);

  while (my ($m, $f) = each %INC) {
    next if (starts_with($f, $cache_dir));
    update_cache($m);
    $updated_count++;
  }

  debuglog("Added $updated_count missing modules to the cache") if (DEBUG && $debug);
}

END {
  if (DEBUG && $debug) { show_all_used_modules(); }
  add_missing_modules_to_cache();
}

1;
