#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::PathCache
#
# Cache the results of resolving relative paths to absolute physical
# paths (without symlinks, '.' or '..' references), and the results
# of path existence checks.
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::PathCache;

use integer; use warnings; use Exporter::Lite;

preserve:; our @EXPORT = 
  qw(resolve_path resolve_directories_in_path resolve_and_open_path
     path_exists flush_path_cache dump_path_cache resolve_uncached_path
     is_absolute_path filename_of directory_of split_dir_and_filename
     strip_last_path_component path_only_contains_filename
     normalize_trailing_slash strip_trailing_slash 
     realpath abs_path fast_abs_path follow_symlinks_in_path);

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
    return ((is_there($1) ? $1 : './'), $2);
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

our $trailing_slash_re = qr{/++$}oax;

sub normalize_trailing_slash($;$) {
  my ($dirlist, $suffix) = @_;

  $suffix //= '/';

  if (is_array_ref($dirlist)) {
    my @out = map { ($_ =~ s{$trailing_slash_re}{}roax).$suffix; } @$dirlist;
    return (wantarray ? @out : \@out);
  } else {
    return ($dirlist =~ s{$trailing_slash_re}{}roax).$suffix;
  }
}

sub strip_trailing_slash {
  return normalize_trailing_slash($_[0], '');
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

  $path_key .= ($follow_final_symlink ? '>' : '!');

  return ($path_key, $base_dir_fd);
}

sub resolve_path($;$$) {
  my ($relative_path, $base_dir_fd, $follow_final_symlink) = @_;
  $relative_path //= '';
  $follow_final_symlink //= 1;

  $path_cache //= MTY::Common::Cache->new(\&path_cache_fill, 'path_cache');

  my $path_key;

  if ((!length $relative_path) && (defined $base_dir_fd)) 
    { return path_of_open_fd($base_dir_fd); }

  my $original_filename = undef;

  # Filter out undesirable redundant aliases to the same effective path:
  $relative_path =~ tr{/}{/}s; # remove duplicate slashes
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
  
  ($path_key, $base_dir_fd) = generate_path_key_and_update_base_dir_fd($relative_path, $base_dir_fd, $follow_final_symlink);
  
  my $path = $path_cache->get($path_key, $relative_path, $base_dir_fd, $follow_final_symlink);

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

  return $path;
}

sub path_exists($;$$) { 
  my ($relative_path, $base_dir_fd, $follow_final_symlink) = @_; 

  return (defined resolve_path($relative_path, $base_dir_fd, $follow_final_symlink)) ? 1 : 0;
}

sub flush_path_cache() {
  if (defined $path_cache) { $path_cache->flush(); }
}

sub dump_path_cache() {
  return if (!defined $path_cache);

  my $h = $path_cache->get_hash();
  my ($hits, $misses, $flushes) = $path_cache->get_stats();

  my @rel_path_list = sort keys %$h;
  my $longest_rel_path = maxlength(@rel_path_list);

  print(STDERR 'Path Cache ('.(scalar @rel_path_list).' relative paths cached):'.NL);
  print(STDERR "  Performance: $hits hits, $misses misses, $flushes flushes (".
          ratio_to_percent($hits, $hits+$misses).'% hit rate)'.NL);

  foreach my $rel (@rel_path_list) {
    my $abs = $h->{$rel};
    print(STDERR '  '.padstring($rel, $longest_rel_path).' => '.($abs // '<undef>').NL);
  }

  printf(STDERR NL);
}

#
# Override functions normally defined in Cwd package:
#
sub realpath { goto &resolve_path; }
sub abs_path { goto &resolve_path; }
sub fast_abs_path { goto &resolve_path; }

1;
