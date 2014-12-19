#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::CurrentDir
#
# Cache the results of resolving relative paths to absolute physical
# paths (without symlinks, '.' or '..' references), and the results
# of path existence checks.
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::CurrentDir;

use integer; use warnings; use Exporter::Lite;

preserve:; our @EXPORT = qw(sys_getcwd sys_chdir get_current_dir_fd getcwd cwd);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::FileStats;

#pragma end_of_includes

my $cached_current_dir = undef;
my $current_dir_fd = undef;

sub sys_getcwd() {
  if (defined $cached_current_dir) { return $cached_current_dir; }

  $cached_current_dir //= POSIX::getcwd();

  if (!defined $cached_current_dir) 
    { die('Cannot query the current directory'); }

  $current_dir_fd //= sys_open_path($cached_current_dir);

  if (!defined $current_dir_fd)
    { die('Cannot open a handle to the current directory'); }

  return (wantarray ? ($cached_current_dir, $current_dir_fd) : $cached_current_dir);
}

#
# Make sure the $cached_current_dir and $current_dir_fd variables
# are set to whatever the current directory was at startup:
#
INIT { sys_getcwd(); }

sub get_current_dir_fd() {
  if (defined $current_dir_fd) { return $current_dir_fd; }

  my ($dir, $fd) = sys_getcwd();
  return (wantarray ? ($fd, $dir) : $fd);
}

noexport:; sub close_current_dir_fd() {
  if (defined $current_dir_fd) { sys_close($current_dir_fd); }
  $current_dir_fd = undef;
  $cached_current_dir = undef;
}

sub sys_fchdir {
  my ($fd) = @_;

  if (($fd // -1) < 0) { return undef; }
  my $dir = path_of_open_fd($fd);
  
  #
  # Technically we should still chdir to the fd itself (rather than just
  # getting its path and passing that to the path based chdir()), even
  # if it's the same as the current directory, since unlike chdir(),
  # fchdir() has side effects like retaining a reference to the fd.
  # Therefore, the following code from sys_chdir() above is omitted:
  # 
  # if ((defined $cached_current_dir) && ($dir eq $cached_current_dir)) 
  # { return $cached_current_dir; }

  close_current_dir_fd();  

  my $rc = POSIX::2008::fchdir($fd);

  if (!defined $rc) { return undef; }

  #
  # Make sure we set $current_dir_fd to a duplicate of the $fd passed
  # by the caller (rather than $fd itself), so the next chdir() or
  # fchdir() (actually close_current_dir_fd()) will close this internal
  # duplicate fd rather than the fd owned by the caller.
  # 
  $current_dir_fd = POSIX::dup($fd);
  $cached_current_dir = $dir;

  return $cached_current_dir;
}

sub sys_chdir {
  my ($dir) = @_;

  if ((defined $cached_current_dir) && ($dir eq $cached_current_dir)) 
    { return $cached_current_dir; }

  #
  # first get a handle to the target directory to guarantee it exists,
  # we can access it, and it is in fact a directory (this is done prior
  # to the actual chdir to avoid race conditions with other processes).
  #

  my $dirfd = sys_open_path($dir);

  #
  # If we can't even open a path handle to it, it doesn't exist, so tell the
  # cache to record a negative result for this query so we won't repeat it:
  #
  if (($dirfd // -1) < 0) { return undef; }

  #
  # Don't preemptively update the cached current directory path,
  # since at the time this is called, we don't yet know if the
  # new directory passed to chdir() is actually valid or not:
  #
  close_current_dir_fd();

  # Finally change to the new directory via its handle:
  if (!POSIX::2008::fchdir($dirfd)) {
    # If we get here, something is seriously wrong (i.e. the directory
    # was removed in between when we opened 
    sys_close($dirfd);
    return undef;
  }

  # (At this point the entire operation is guaranteed to be successful)
  $current_dir_fd = $dirfd;
  $cached_current_dir = path_of_open_fd($dirfd);

  return $cached_current_dir;
}

sub getcwd { goto &sys_getcwd; }
sub cwd { goto &sys_getcwd; }

BEGIN {
  no warnings;
  *CORE::GLOBAL::chdir = *sys_chdir;
  use warnings;
};

1;
