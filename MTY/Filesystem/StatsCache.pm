#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::StatsCache
#
# Cache the results of file stats queries and path existence checks,
# plus accelerate absolute physical path resolution with realpath.
#
# The cache may optionally be disabled, but by default it is enabled
# and kept coherent with the filesystem using inotify (if supported).
#
# This module globally overrides the stat() and realpath() functions.
#
# Copyright 1997 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::StatsCache;

use integer; use warnings; use Exporter qw(import);

preserve:; our @EXPORT = 
  qw(get_file_stats get_file_stats_of_fd flush_file_stats_cache dump_file_stats_cache
     FILE_TIMESTAMP_MODIFIED_DATA FILE_TIMESTAMP_CHANGED_ATTRS FILE_TIMESTAMP_ACCESSED
     fixup_nanosec_file_timestamps get_file_timestamps get_mtime_of_path get_mtime_of_fd
     get_file_type get_file_type_nofollow is_file_type is_file_type_nofollow is_exact_file_type 
     is_exact_file_type_nofollow);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Common::Cache;
use MTY::RegExp::FilesAndPaths;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::PathCache;
use MTY::Filesystem::CurrentDir;

#
# Stat related functions
#
use constant {
  FILE_TIMESTAMP_MODIFIED_DATA => 0,
  FILE_TIMESTAMP_CHANGED_ATTRS => 1,
  FILE_TIMESTAMP_ACCESSED      => 2,
};

sub fixup_nanosec_file_timestamps(+) {
  my ($stats) = @_;

  $stats->[STAT_MTIME_NS] = ($stats->[STAT_MTIME] * BILLION) + $stats->[STAT_MTIME_NS];
  $stats->[STAT_CTIME_NS] = ($stats->[STAT_CTIME] * BILLION) + $stats->[STAT_CTIME_NS];
  $stats->[STAT_ATIME_NS] = ($stats->[STAT_ATIME] * BILLION) + $stats->[STAT_ATIME_NS];

  return $stats;
}

sub get_mtime_of_fd($) {
  my $stats = get_file_stats_of_fd(@_);
  return (defined $stats) ? $stats->[STAT_MTIME_NS] : undef;
}

sub get_mtime_of_path($) {
  my $stats = get_file_stats(@_);
  return (defined $stats) ? $stats->[STAT_MTIME_NS] : undef;
}

#
# get_file_timestamps([pathname|handle|fd|statarray|stathash]):
#
# Return an array of the form [mtime, ctime, atime] containing
# the specified file's three POSIX defined timestamps in seconds,
# as floating point values with nanosecond precision.
#

sub get_file_timestamps {
  my $stats = get_file_stats(@_);

  my @timestamps = (
    $stats->[STAT_MTIME_NS], 
    $stats->[STAT_CTIME_NS], 
    $stats->[STAT_ATIME_NS]
  );

  return (wantarray ? @timestamps : \@timestamps);
}

sub get_file_type($;$) {
  my ($path, $follow_symlinks) = @_;
  $follow_symlinks //= 1;
  my $stats = get_file_stats($path, undef, $follow_symlinks);
  return ((defined $stats) ? $stats->[STAT_TYPE] : undef);
}

sub get_file_type_nofollow($) {
  my ($path) = @_;
  return get_file_type($path, 0);
}

sub is_file_type($$;$$) {
  my ($path_or_fd_or_stats, $req_type, $follow_symlinks, $exact) = @_;
  $follow_symlinks //= 1;
  $exact //= 0;

  my $stats = (is_array_ref $path_or_fd_or_stats) ? $path_or_fd_or_stats :
    (is_string $path_or_fd_or_stats) ? get_file_stats($path_or_fd_or_stats, undef, $follow_symlinks) :
    get_file_stats_of_fd($path_or_fd_or_stats);

  if (!defined $stats) { return undef; }
  my $real_type = $stats->[STAT_TYPE];
  # Correctly handle equivalencies and inclusive subtypes:
  if ($real_type == $req_type) { return 1; }
  if ($exact) { return (($req_type == $real_type) ? 1 : 0); }

  my $match = 
    ($req_type == FILE_TYPE_DIR) ? (($real_type == FILE_TYPE_DIR) || ($real_type >= FILE_TYPE_MOUNT_POINT)) :
    ($req_type == FILE_TYPE_MOUNT_POINT) ? (($real_type >= FILE_TYPE_MOUNT_POINT) && ($real_type < FILE_TYPE_SUBVOLUME)) :
    ($req_type == FILE_TYPE_SUBVOLUME) ? (($real_type == FILE_TYPE_SUBVOLUME) || ($real_type == FILE_TYPE_SNAPSHOT)) :
    ($req_type == $real_type);

  return ($match ? 1 : 0);
}

sub is_file_type_nofollow($$) {
  my ($path, $req_type) = @_;
  return is_file_type($path, $req_type, 0);
}

sub is_exact_file_type($$;$) {
  my ($path, $req_type, $follow_symlinks) = @_;
  return is_file_type($path, $req_type, $follow_symlinks, 1);
}

sub is_exact_file_type_nofollow($$) {
  my ($path, $req_type) = @_;
  return is_file_type($path, $req_type, 0, 1);
}

noexport:; sub file_stats_cache_fill(+$$$$) {
  my ($cache, $path_key, $relative_path, $base_dir_fd, $follow_symlinks) = @_;

  $relative_path //= '';
  
  my $flags = 
    ($follow_symlinks ? 0 : AT_SYMLINK_NOFOLLOW) |
    ((!length $relative_path) ? AT_EMPTY_PATH : 0);

  my @stats = sys_fstatat($base_dir_fd // AT_FDCWD, $relative_path, $flags);

  if (!@stats) { return undef; }

  fixup_nanosec_file_timestamps(@stats);

  $path_key //= resolve_path($relative_path, $base_dir_fd, $follow_symlinks);

  $stats[STAT_PATH] = $path_key;
  $stats[STAT_NAME] = ($path_key eq '/') ? '/' : (filename_of($path_key) // '');
  $stats[STAT_TYPE] = ($stats[STAT_MODE] >> S_IFMT_SHIFT);
  $stats[STAT_SUBSET] = STATS_QUERY_BASE;

  return \@stats;
}

my $file_stats_cache;

noexport:; sub init_file_stats_cache() { 
  $file_stats_cache //= MTY::Common::Cache->new(\&file_stats_cache_fill, 'file_stats_cache');
  return $file_stats_cache;
}

sub get_file_stats($;$$$) {
  my ($relative_path, $base_dir_fd, $follow_symlinks, $path_key) = @_;
  $follow_symlinks //= 1;
  $relative_path //= '';

  $file_stats_cache //= init_file_stats_cache();

  # Just directly query the stats of the base_dir_fd itself if the path is empty or undef:
  $path_key //= resolve_path($relative_path, $base_dir_fd, $follow_symlinks);

  #
  # If we can't resolve (base_dir_fd, relative_path) to an absolute path,
  # this means the ultimate target either doesn't exist and/or we cannot
  # access one or more directories and/or symlinks leading to that target:
  #
  if (!defined $path_key) { return undef; }

  my $stats = $file_stats_cache->get($path_key, $relative_path, $base_dir_fd, $follow_symlinks);

  return (wantarray ? ((defined $stats) ? @$stats : ( )) : $stats);
}

sub get_file_stats_of_fd {
  my $fd_or_handle = shift;

  my $fd = get_native_fd($fd_or_handle);
  if (!defined $fd) { die('Cannot get underlying file descriptor for specified handle'); }

  $file_stats_cache //= init_file_stats_cache();

  my $path = path_of_open_fd($fd);

  my $stats = $file_stats_cache->get($path, undef, $fd);

  return (wantarray ? ((defined $stats) ? @$stats : ( )) : $stats);
}

sub flush_file_stats_cache() {
  return if (!defined $file_stats_cache);

  $file_stats_cache->flush();
}

sub dump_file_stats_cache() {
  return if (!defined $file_stats_cache);

  my $h = $file_stats_cache->get_hash();
  my ($hits, $misses, $flushes) = $file_stats_cache->get_stats();

  my @abs_path_list = sort keys %$h;
  my $longest_abs_path = maxlength(@abs_path_list);

  printfd(STDERR, 'Stats Cache ('.(scalar @abs_path_list).' unique filesystem objects cached):'.NL);
  printfd(STDERR, "  Performance: $hits hits, $misses misses, $flushes flushes (".
          ratio_to_percent($hits, $hits+$misses).'% hit rate)'.NL);

  foreach my $abs (@abs_path_list) {
    my $stats = $h->{$abs};
    printfd(STDERR, '  '.padstring($abs, $longest_abs_path).' => {'.
            ((defined $stats) ? join(', ', @$stats) : '<undef>').'}'.NL);
  }

  printf(STDERR NL);
}

noexport:; sub override_stat_or_lstat {
  my ($follow_symlinks, $path_or_fd) = @_;
  $path_or_fd //= $_;

  my $path = $path_or_fd;
  my $path_key = undef;
  my $fd = fileno($path_or_fd);
  if (defined $fd) {
    $path_key = path_of_open_fd($fd);
    $path = undef;
  }

  my @stats = get_file_stats($path, $fd, $follow_symlinks, $path_key);

  return ((scalar @stats) ? (wantarray ? @stats : 1) : (wantarray ? ( ) : 0));
}

sub override_stat { return override_stat_or_lstat(1, @_); }
sub override_lstat { return override_stat_or_lstat(0, @_); }

# BEGIN {
#  no warnings;
#  *CORE::GLOBAL::stat = *override_stat;
#  *CORE::GLOBAL::lstat = *override_lstat;
#  use warnings;
# };

1;
