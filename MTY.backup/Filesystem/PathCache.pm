#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::PathCache
#
# Cache the results of resolving relative paths to absolute physical
# paths (without symlinks, '.' or '..' references), and the results
# of path existence checks.
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::PathCache;

use integer; use warnings; use Exporter qw(import);

preserve:; our @EXPORT = 
  qw(resolve_path resolve_directories_in_path resolve_and_open_path
     path_exists flush_path_cache dump_path_cache resolve_uncached_path
     is_absolute_path filename_of directory_of split_dir_and_filename
     strip_last_path_component path_only_contains_filename
     last_path_component_of path_ends_with_trailing_slash
     normalize_slashes add_trailing_slash normalize_and_add_trailing_slash
     strip_trailing_slash normalize_and_strip_trailing_slash 
     realpath abs_path fast_abs_path follow_symlinks_in_path
     update_path_cache probe_path_cache mkdirs split_path_into_components);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Common::Cache;
use MTY::RegExp::FilesAndPaths;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::CurrentDir;

#
# The Cwd::realpath function is only used as a fallback for resolving
# symlinks found in /proc/*/fd/<fd> which refer to non-mountable
# special inode namespaces. See comments about this in path_cache_fill() 
# below for more information:
#
use Cwd ( );
#pragma end_of_includes

#
# $abspath = resolve_uncached_path($relative_path, $extra_open_path_flags) ... or:
# ($fd, $abspath) = resolve_and_open_uncached_path($relative_path, $extra_open_path_flags)
#
# Resolve the absolute physical path (without any symlinks, . or ..)
# of the specified path, which may be relative or contain symlinks.
#
# Optionally takes a base fd of the base directory as its second 
# argument; otherwise assumes the path is either absolute or relative
# to the current directory.
#
# This is roughly 2x to 3x faster than the libc and/or perl native
# implementation of realpath, which starts at the root and traverses
# each directory comprising the path, following any symlinks until
# they reach a real file or directory. Each step for each directory
# requires several system calls which must be done strictly in order.
#
# In contrast, this function simply asks the kernel for the final 
# absolute path, since the kernel obviously already knows this and 
# can return it much faster than any userspace function can redo
# this work without the benefit of direct access to the kernel's
# directory and inode caches.
#
# Specifically, this function opens a file descriptor for the
# specified path itself using the O_PATH flag (which skips the
# slower process of actually preparing to access the file's data).
# It then simply reads the symlink target of /proc/self/fd/<path-fd>,
# through which the kernel conveniently provides the real path of
# any file descriptor. This requires only three system calls for
# the entire path (rather than for every directory in it):
#
# 1. <fd> = open(<target>, O_PATH)
# 2. <real_path_of_target> = readlinkat("/proc/self/fd/", "<fd>")
# 3. close(<fd>)
#
# As a companion function to resolve_uncached_path(), the 
# resolve_and_open_uncached_path() function returns a pair 
# of the form:
#
#   (O_PATH file descriptor for path, 
#    full path of first argument),
#
# which is often a convenient compound operation, since the O_PATH
# file descriptor needs to be opened anyway.
#

our $resolve_uncached_path_count = 0;
our $resolve_uncached_path_fast_count = 0;

sub is_absolute_path($) {
  my ($path) = @_;
  return ($path =~ $absolute_path_re) ? 1 : 0;
}

sub last_path_component_of($) {
  my ($path) = @_;
  my ($name) = ($_[0] =~ /($last_path_component_re)/oamsx);
  return $name;
}

sub filename_of($) {
  my ($path) = @_;
  my ($name) = ($_[0] =~ /($filename_in_path_re)/oamsx);
  return $name;
}

sub directory_of($) {
  my ($result) = ($_[0] =~ /$directory_in_path_re/oamsx);
  if (!is_there($result)) { $result = '.'; };
  return $result;
}

sub split_dir_and_filename($) {
  if ($_[0] =~ /$directory_and_filename_re/oamsx) {
    return (((if_there $1) // './'), $2);
  } else {
    return ( );
  }
}

sub strip_last_path_component($) {
  my ($path) = @_;
  $path =~ s{$strip_last_path_component_re}{}oamsx;
  return $path;
}

sub path_only_contains_filename($) {
  return ($_[0] =~ /$filename_without_leading_directories_re/oamsx) ? 1 : 0;
}

#
# Normalize the specified path by removing redundant slashes
# throughout the path, then ensuring the path is terminated by a
# single trailing slash. (This function should therefore only
# be passed paths to directories; it does NOT check the actual
# filesystem to confirm the path is a directory).
#
our $trailing_slash_re = qr{/++\Z}oamsx;

sub path_ends_with_trailing_slash($) {
  my ($path) = @_;
  return ($path =~ /$trailing_slash_re/oamsx) ? 1 : 0;
}

sub normalize_slashes($) { ($_[0] =~ tr{/}{/}rs); }

sub normalize_and_add_trailing_slash($) { (($_[0].'/') =~ tr{/}{/}rs); }

sub normalize_and_strip_trailing_slash($) {
  my $p = ($_[0] =~ tr{/}{/}rs);
  local $/ = '/'; chomp $p; return $p;
}

sub add_trailing_slash($) {
  my $p = $_[0]; local $/ = '/'; chomp $p; return $p.'/';
}

sub strip_trailing_slash($) {
  my $p = $_[0]; local $/ = '/'; chomp $p; return $p;
}

my $path_component_re = qr{((?> [^/]++))}oamsx;

sub split_path_into_components($) {
  my ($path) = @_;

  my @components = ($path =~ /$path_component_re/oamsxg);
  return (wantarray ? @components : \@components);
}

my $proc_pid_fd_or_deleted_symlink_target_re = 
  qr{(?>
       (?> \A \w++ : \[?+ \w++ \]?+) |
       (?> \s \(deleted\) \Z)
     )}oamsx;

sub resolve_uncached_path($;$$) {
  my ($relative_path, $base_dir_fd, $follow_final_symlink) = @_;

  $follow_final_symlink //= 1;

  $relative_path //= '';
  my $orig_relative_path = $relative_path;

  if (!$follow_final_symlink) { $relative_path = strip_last_path_component($relative_path); }

  my $path =
    (is_absolute_path($relative_path)) ? $relative_path :
      (($base_dir_fd // AT_FDCWD) == AT_FDCWD) ? getcwd().'/'.$relative_path :
      path_of_open_fd($base_dir_fd).'/'.$relative_path;
  
  if (!$follow_final_symlink) { $path .= '/'.filename_of($orig_relative_path); }

  $path = Cwd::realpath($path);

  return $path;
}

noexport:; sub path_cache_fill(+$$$;$) {
  my ($cache, $path_key, $relative_path, $base_dir_fd, $follow_final_symlink) = @_;
  $follow_final_symlink //= 1;
  $relative_path //= '';

  $resolve_uncached_path_count++;
  printdebug{'path_cache_fill: key ', $path_key, ', rel ', $relative_path, 
     ', base_dir_fd ', $base_dir_fd, ' (', path_of_open_fd($base_dir_fd), 
     '), follow? ', $follow_final_symlink, '):'};

  if (!length $relative_path) {
    $base_dir_fd //= get_current_dir_fd();
    return path_of_open_fd($base_dir_fd);
  } elsif (is_absolute_path($relative_path)) {
    #
    # If the path is absolute (explicitly starts at the root), 
    # the base_dir_fd doesn't matter. Note that the path may still
    # have symlinks, . or ..:
    #
    $base_dir_fd = undef;
  } elsif ($relative_path =~ $filename_without_leading_directories_re) {
    #
    # Let the shortcut below work on filenames in the current directory too:
    #
    $base_dir_fd //= get_current_dir_fd();

    #
    # Faster shortcut when resolving a filename within a base directory
    # for which we already have an fd (and thus either already know the
    # resolved path of that fd, or can obtain it once and then cache it).
    #
    # In this case, we can simply append the specified name to the base
    # directory's previously resolved path, unless the named file is a
    # symbolic link (since this may require recursive resolution of 
    # additional symlinks within the symlink's target path, which 
    # precludes using this shortcut in this uncommon situation).
    #

    my $base_dir_path = path_of_open_fd($base_dir_fd);
    if ($base_dir_path eq '/') { $base_dir_path = ''; }
    my $base_dir_and_rel_path = $base_dir_path.'/'.$relative_path;

    if (($relative_path eq '.') || ($relative_path eq '..')) {
      # caller passed us the equivalent of '/dir/path/here/.' or '/dir/path/here/..':
      my $path = path_of_open_fd($base_dir_fd);

      $path = 
        ($relative_path eq '.') ? $path :
        ($relative_path eq '..') ? strip_last_path_component($path)
        : undef; # this case should never occur since the regexp only matches . or ..

      $resolve_uncached_path_fast_count++;

      return $path;
    } else {
      # returns +1 if symlink, 0 if file/directory/non-symlink, -1 if path does not actually exist 
      my $rc = path_is_symlink($relative_path, $base_dir_fd);
      if ($rc <= 0) {
        $resolve_uncached_path_fast_count++;
        return ($rc == 0) ? $base_dir_and_rel_path : undef;
      } else { # (it must be a symlink)
        if (!$follow_final_symlink) { return $base_dir_and_rel_path; }
      } # otherwise use the full path resolution code below
    }
  }

  #
  # The O_NOFOLLOW flag only applies to the final path component,
  # since this lets us successfully query the existence of a symlink
  # in a directory regardless of whether or not its target is valid.
  #
  my $fd = sys_open_path($relative_path, $base_dir_fd, ($follow_final_symlink ? 0 : O_NOFOLLOW));

  #
  # If we can't even open a path handle to it, it doesn't exist, so tell the
  # cache to record a negative result for this query so we won't repeat it:
  #
  if (($fd // -1) < 0) { return undef; }

  my $path = path_of_open_fd($fd);

  sys_close($fd);

  if ((defined $path) && ($path =~ $proc_pid_fd_or_deleted_symlink_target_re) && 0) {
    # 
    # We have opened the target of a special /proc/pid/<fd> symlink
    # which was dynamically generated by the kernel to represent
    # either a special type of file descriptor without any path,
    # or a deleted file, specifically including:
    #
    # - handles for eventfd, eventpoll, inotify, signalfd, timerfd
    # - namespace identifier inodes for the ipc, mnt, net, pid, user, uts namespaces
    # - anonymous pipe inodes
    # - anonymous socket inodes
    # - deleted files which are still open but no longer have any filenames 
    #   still linked to their inode
    #
    # The aforementioned special symlinks are in one of the following formats:
    # 
    #   "<type>:[<anonymous inode number or subtype>]"
    #   "/original/path/to/deleted/file (deleted)"
    #
    # If the caller intends to open any of these special object types, 
    # the caller must use the open or openat syscall on the symlink
    # itself (i.e. /proc/<pid>/<fd>, etc), since the resolved symlink
    # points into a namespace which can't be accessed like a filesystem.
    # Therefore, we return the path of the symlink in these cases,
    # instead of returning its target.
    #

    $path =
      (is_absolute_path($relative_path)) ? $relative_path :
      (($base_dir_fd // AT_FDCWD) == AT_FDCWD) ? getcwd().'/'.$relative_path :
      path_of_open_fd($base_dir_fd).'/'.$relative_path;
  }

  return $path;
}

#
# Cache which maps absolute resolved path names to their stats arrays:
#
my $path_cache;

noexport:; sub init_path_cache() {
  $path_cache //= MTY::Common::Cache->new(\&path_cache_fill, 'path_cache');
}

INIT {
  init_path_cache();
};

noexport:; sub generate_path_key_and_update_base_dir_fd(;$$$) {
  my ($relative_path, $base_dir_fd, $follow_final_symlink) = @_;

  $relative_path //= '';
  $follow_final_symlink //= 1;
  
  my $path_key;

  if (is_absolute_path($relative_path)) {
    $base_dir_fd = undef;
    $path_key = $relative_path;
  } else {
    $base_dir_fd //= get_current_dir_fd(); 
    $path_key = path_of_open_fd($base_dir_fd);
    if ($path_key eq '/') { $path_key = ''; } # don't double the slash in this corner case
    if (length $relative_path) { $path_key .= '/'.$relative_path; }
  }

  $path_key = strip_trailing_slash($path_key) . ($follow_final_symlink ? '>' : '!');

  return ($path_key, $base_dir_fd);
}

sub update_path_cache($$;$$) {
  my ($abs_path, $relative_path, $base_dir_fd, $follow_final_symlink) = @_;
  init_path_cache();

  my $path_key;
  ($path_key, $new_base_dir_fd) = generate_path_key_and_update_base_dir_fd(
    $relative_path, $base_dir_fd, $follow_final_symlink);

  printdebug{'update_path_cache(abs_path ', $abs_path, ', rel_path ',
     $relative_path, ', base_dir_fd ', $base_dir_fd,
     '(', ((defined $base_dir_fd) ? path_of_open_fd($base_dir_fd) : undef),
     '), follow? ', $follow_final_symlink, ') => ',
     'path_key ', $path_key, ', new_base_dir_fd ', $new_base_dir_fd};

  return $path_cache->put($path_key, strip_trailing_slash($abs_path));
}

sub probe_path_cache($;$$) {
  my ($relative_path, $orig_base_dir_fd, $follow_final_symlink) = @_;
  return undef if (!defined $path_cache);
  
  my ($path_key, $base_dir_fd) = generate_path_key_and_update_base_dir_fd(
    $relative_path, $orig_base_dir_fd, $follow_final_symlink);

  return $path_cache->probe($path_key);
}

sub resolve_path($;$$) {
  my ($relative_path, $base_dir_fd, $follow_final_symlink) = @_;
  $relative_path //= '';
  $follow_final_symlink //= 1;
  my $orig_base_dir_fd = $base_dir_fd;

  printdebug{'resolve_path(', $relative_path, ', base_dir_fd ', $orig_base_dir_fd, ' (', path_of_open_fd($base_dir_fd), '), ',
    'follow? ', $follow_final_symlink, '):'};

  init_path_cache();

  if ((!length $relative_path) && (defined $base_dir_fd)) 
    { return path_of_open_fd($base_dir_fd); }

  my $original_filename = undef;

  #
  # Filter out undesirable redundant aliases to the same effective path:
  #
  $relative_path = normalize_slashes($relative_path);
  #
  # Remove any trailing slash (unless the path is the root directory, i.e. '/')
  # to prevent the caching of redundant aliases (i.e. xyz, xyz/, xyz//, ...).
  #
  # However, if a trailing slash was present, this means the caller knows the 
  # final target must be a directory and wants its absolute path, even if the 
  # relative path refers to a symlink (which must point to a directory in this
  # case), regardless of the value of $follow_final_symlink:
  #
  if ($relative_path =~ s{. \K / \Z}{}oamsxg) { $follow_final_symlink = 1; }
  
  my $path_key;
  ($path_key, $base_dir_fd) = generate_path_key_and_update_base_dir_fd(
    $relative_path, $base_dir_fd, $follow_final_symlink);

  printdebug{'resolve_path(', $relative_path, ', base_dir_fd ', $orig_base_dir_fd,
     ' (', path_of_open_fd($base_dir_fd), '), ', 'follow? ', $follow_final_symlink, 
     ') => new base_dir_fd ', $base_dir_fd, ', path_key ', $path_key};

  my ($path, $hit) = $path_cache->get(
    $path_key, $relative_path, $base_dir_fd, $follow_final_symlink);

  $path = strip_trailing_slash($path) if (defined $path);

  if ((!$hit) && (defined $path)) {
    my $existed = $path_cache->put($path.'>', $path);
    printdebug{'resolve_path(', $path, '): path cache miss, but abs path found: ',
      'added identity mapping for abs path too (', 
       ($existed ? 'already existed' : 'newly cached'), ')'};
  }

  if ((defined $path) && (!length $path)) { $path = '/'; }
  printdebug{'  => final resolved path = ', $path};

  return $path;
}

sub resolve_directories_in_path(;$$) {
  my ($relative_path, $base_dir_fd) = @_;
  return resolve_path($relative_path, $base_dir_fd, 0);
}

sub resolve_and_open_path(;$$$) {
  my ($relative_path, $base_dir_fd, $extra_open_path_flags) = @_;
  $relative_path //= '';
  
  my $path_key;

  ($path_key, $base_dir_fd) = generate_path_key_and_update_base_dir_fd($relative_path, $base_dir_fd, $follow_final_symlink);

  my $fd = sys_open_path($relative_path, $base_dir_fd, $extra_open_path_flags // 0) // -1;
  my $path = (defined $fd) ? path_of_open_fd($fd) : undef;

  #
  # Insert undefined results into the cache too, since these indicate
  # the file was missing or inaccessible (so we should not waste time
  # re-checking it all over again).
  #
  if (defined $path_cache) { $path_cache->put($path_key, $path); }

  return (wantarray ? ($fd, $path) : $fd);
}

sub path_exists($;$$) { 
  my ($relative_path, $base_dir_fd, $follow_final_symlink) = @_; 

  return (defined resolve_path($relative_path, $base_dir_fd, $follow_final_symlink)) ? 1 : 0;
}

sub flush_path_cache(;$$$) {
  my ($path, $orig_base_dir_fd, $follow_final_symlink) = @_;
  $follow_final_symlink //= 1;

  printdebug{'Invalidating path cache for path ', $path};

  #
  # Make sure the path cache has been initialized already
  # (if it hasn't been initialized, it hasn't cached any
  # entries we could flush in the first place):
  #
  return if (!defined $path_cache);

  if (!defined $path) {
    # Flush the entire cache to invalidate all possible paths:
    return $path_cache->flush();
  }

  my ($path_key, $base_dir_fd) = generate_path_key_and_update_base_dir_fd(
    $path, $orig_base_dir_fd, $follow_final_symlink);

  return $path_cache->invalidate($path_key);
}

sub dump_path_cache() {
  return if (!defined $path_cache);

  my $h = $path_cache->get_hash();
  my ($hits, $misses, $flushes) = $path_cache->get_stats();

  my @path_key_list = sort keys %$h;
  my $longest_key = maxlength(@path_key_list);

  printfd(STDERR, NL.'Path Cache ('.(scalar @path_key_list).' relative paths cached):'.NL.NL);
  printfd(STDERR, "  Performance: $hits hits, $misses misses, $flushes flushes (".
          ratio_to_percent($hits, $hits+$misses).'% hit rate)'.NL.NL);

  my $path_and_path_key_type_re = 
    qr{\A ([^\>\!]++) ([\>\!]) \Z}oamsx;

  foreach my $pathkey (@path_key_list) {
    my $abspath = $h->{$pathkey};
    my ($path, $type) = ($pathkey =~ /$path_and_path_key_type_re/oamsx);
    my $type_desc = ($type eq '>') ? '[follow]' : ($type eq '!') ? '[nolink]' : '[????='.$type.']';
    
    printfd(STDERR, '  '.$type_desc.'  '.padstring($path, $longest_key).'  =>  '.($abspath // '<undef>').NL);
  }

  printfd(STDERR, NL);
}

#
# Create any and all missing directories comprising the specified path:
#
sub mkdirs($;$$) {
  my ($path, $base_dir_fd, $perms) = @_;
  $perms //= 0755; # 0755 = rwxr-xr-x

  init_path_cache();

  my $base_path = '';

  if (is_absolute_path($path)) {
    $base_dir_fd = undef;
    $base_path = '/';
  } else {
    $base_dir_fd //= get_current_dir_fd(); 
    $base_path = path_of_open_fd($base_dir_fd);
  }

  $base_path = normalize_and_add_trailing_slash($base_path);
  $path = normalize_and_add_trailing_slash($path);

  # printdebug{'mkdirs(', $path, ', orig base_dir_fd ', $orig_base_dir_fd,
  #   '(', ((defined $orig_base_dir_fd) ? path_of_open_fd($orig_base_dir_fd) : undef),
  #   ')) => path ', $path, ', base_dir_fd ', $base_dir_fd, ', base_path ', $base_path};

  #
  # Just return it if it already exists (this is quite common in many 
  # scenarios where the caller wants to create a file and needs to
  # ensure its directory actually exists first, yet open() et al
  # won't create directories like they'll create the file itself).
  #
  my $abs_path_so_far = resolve_path($path, $base_dir_fd);

  if (defined $abs_path_so_far) {
    # printdebug{'mkdirs(', $path, '): final target path ', 
    #   $abs_path_so_far, ' already exists'};
    return $abs_path_so_far;
  }

  #
  # Try to simply create the directory, which will succeed if the parent 
  # directory already exists (which is a very common scenario when a
  # sorted list of paths in a directory hierarchy are created in order):
  #

  $abs_path_so_far = $base_path.$path;

  if (sys_mkdirat($base_dir_fd // AT_FDCWD, $path, $perms)) {
    flush_path_cache($path, $base_dir_fd);
    $abs_path_so_far = resolve_path($path);
    # printdebug{'mkdirs(', $path, '): simple mkdir successful => abs path ', 
    #   $abs_path_so_far};
    return $abs_path_so_far;
  }

  #
  # If neither the path itself nor its parent directory already existed,
  # we need to take the following more complex slow path instead:
  #
  # We use the well known "one directory component at a time" method,
  # starting from the root (or the base path we know already exists),
  # then try to create each subdirectory where necessary until we've
  # created any missing directories in the entire path:
  #
  # First traverse any leading directories that already exist.
  # If we can resolve it to a real absolute path (and the
  # trailing slash guarantees it must be a directory), this
  # means the path so far already exists, so skip this 
  # directory component and try the next one.
  #

  $path_so_far = (defined $base_dir_fd) ? '' : '/'; # it's relative to basefd's path now
  $abs_path_so_far = $base_path;

  my @chunks = split_path_into_components($path);

  my $i;
  my $dir;

  my $follow_phase = 1;

  while (($i, $dir) = each @chunks) {
    $path_so_far .= $dir.'/';

    if ($follow_phase) {
      my $new_abs_path = resolve_path($path_so_far, $base_dir_fd);

      # printdebug{'[ follow ] ', $dir, ': ', $path_so_far, 
      #   ' => abs ', $new_abs_path};

      if (defined $new_abs_path) 
        { $abs_path_so_far = add_trailing_slash($new_abs_path); } 
      else {
        # Make sure we don't have a soon to be stale cache entry:
        flush_path_cache($path_so_far, $base_dir_fd);
        $follow_phase = 0;
      };
    }

    #
    # After this point none of the remaining subdirectories exist,
    # so we'll need to create all of them. The path cache may also
    # contain negative entries because those parts of the path
    # did not previously exist, so we'll flush them from the cache.
    #

    if (!$follow_phase) { # create phase:
      # printdebug{'[ create ] (next will be ', $dir, '): ', $path_so_far, 
      #   ", abs so far = ", $abs_path_so_far};

      if (!sys_mkdirat($base_dir_fd // AT_FDCWD, $path_so_far, $perms)) {
        # warning('mkdirs(', $path, '): failed to create dir ', $path_so_far, 
        #  ' rel to fd ', $base_dir_fd, ': errno ', $!);
        return undef;
      }

      $abs_path_so_far .= $dir.'/';
      update_path_cache($abs_path_so_far, $path_so_far, $base_dir_fd);
      # Add an identity mapping entry for the full absolute path:
      update_path_cache($abs_path_so_far, $abs_path_so_far);
    }
  }

  # printdebug{'  Finished! absolute path is now:  ', $abs_path_so_far, NL};
  # printdebug{'    and the relative path so far:  ', $path_so_far, NL};
  # printdebug{'    and the final value for dir:   ', $dir, NL};

  return $abs_path_so_far;
}

#
# Override functions normally defined in Cwd package:
#
sub realpath { goto &resolve_path; }
sub abs_path { goto &resolve_path; }
sub fast_abs_path { goto &resolve_path; }

#
# Hook the following built-in Perl functions so we can invalidate
# the corresponding path cache entries (if any) as these functions
# modify the filesystem. (See comments in MTY/System/POSIX.pm for
# many more details on how and why we need to do this).
#

sub invalidate_cached_paths { 
  foreach my $path (@_) { 
    flush_path_cache($path) if (is_string $path); 
  } 
}

INIT {
  push @invalidate_cached_path_hooks, \&invalidate_cached_paths;
}

1;
