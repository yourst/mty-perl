#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::Files
#
# Common functions on files and directories
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::Files;

use integer; use warnings; use Exporter qw(import);

preserve:; our @EXPORT = 
  qw($max_read_chunk_size STDERR_FD STDIN_FD actual_filename_of_open_fd
     STDOUT_FD basename_of final_suffix_of is_same_file read_directory
     read_directory_handle READ_DIR_FILENAMES READ_DIR_INODES_AND_TYPES READ_DIR_PACKED_INODES_AND_TYPES
     read_file read_file_handle split_filename_into_basename_and_suffixes
     read_file_as_lines read_file_handle_as_lines write_file_safely 
     split_path split_path_into_dirs_basename_and_suffixes write_file_with_backup
     split_path_version_aware suffix_of write_file write_file_handle 
     get_file_type get_fd_type get_dev_node_major_minor_type
     split_path_into_components path_ends_with_trailing_slash
     normalize_slashes add_trailing_slash normalize_and_add_trailing_slash
     strip_trailing_slash normalize_and_strip_trailing_slash

     directory_of filename_of is_file_handle  
     split_dir_and_filename split_filename_into_basename_and_suffixes
     strip_last_path_component longest_common_path_prefix
     longest_common_string_component_prefix new_handle_from_fd

     get_file_stats get_file_stats_of_fd get_native_fd get_current_dir_fd
     resolve_path resolve_directories_in_path resolve_and_open_path path_exists
     realpath abs_path sys_getcwd sys_chdir getcwd cwd mkdirs

     get_file_type get_file_type_nofollow is_file_type is_file_type_nofollow is_exact_file_type 
     is_exact_file_type_nofollow suffixes_without_dot_of final_suffix_without_dot_of

     FILE_TIMESTAMP_MODIFIED_DATA FILE_TIMESTAMP_CHANGED_ATTRS FILE_TIMESTAMP_ACCESSED
     fixup_nanosec_file_timestamps get_file_timestamps get_mtime_of_path get_mtime_of_fd);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;

use MTY::Common::Strings;
use MTY::RegExp::FilesAndPaths;

use MTY::Filesystem::FileStats;
use MTY::Filesystem::PathCache;
use MTY::Filesystem::StatsCache;
use MTY::Filesystem::CurrentDir;

use IO::File;
#pragma end_of_includes

use constant {
  STDIN_FD => 0,
  STDOUT_FD => 1,
  STDERR_FD => 2,
};

#
# These are actually implemented in MTY::Filesystem::PathCache
# but for convenience we re-export them from this module too:
#
#     is_absolute_path 
#     filename_of 
#     directory_of
#     split_dir_and_filename
#     strip_last_path_component
#     path_only_contains_filename
#     normalize_trailing_slash
#     strip_trailing_slash 
#

#
# Split specified path into list of (directory, basename, suffixes),
# with empty strings in place of any missing components:
#
sub split_path($;$) {
  my ($path, $re) = @_;
  $re //= $filesystem_path_re;

  my ($dirname, $basename, $suffixes) = ($_[0] =~ /$re/oax);
  if (!is_there($dirname)) { $dirname = '.'; };
  $basename //= '';
  $suffixes //= '';
  if ((!is_there($basename)) && (is_there($suffixes))) {
    # dot files (e.g. ".filename") with nothing before the dot
    # should appear as the basename, not the suffix with no basename:
    $basename = $suffixes;
    $suffixes = '';
  }

  return ($dirname, $basename, $suffixes);
}

sub split_path_version_aware($) {
  return split_path($_[0], $filesystem_dir_basename_suffixes_version_aware_re);
}

sub split_filename_into_basename_and_suffixes($) {
  my @result = ($_[0] =~ /$basename_and_suffixes_re/oax);
  $result[0] //= '';
  $result[1] //= '';
  return @result;
}

sub basename_of($) {
  my ($result) = ($_[0] =~ /$filename_without_suffixes_in_path_re/oax);
  return $result;
}

sub suffix_of($) {
  my ($result) = ($_[0] =~ /$suffixes_in_path_re/oax);
  return $result;
}

sub final_suffix_of($) {
  my ($result) = ($_[0] =~ /$final_suffix_in_path_re/oax);
  return $result;
}

sub suffixes_without_dot_of($) {
  my ($result) = ($_[0] =~ /$suffixes_in_path_no_dot_re/oax);
  return $result;
}

sub final_suffix_without_dot_of($) {
  my ($result) = ($_[0] =~ /$final_suffix_in_path_no_dot_re/oax);
  return $result;
}

sub split_path_into_dirs_basename_and_suffixes($) {
  my ($path) = @_;

  if (my @dirs_basename_and_suffixes = ($path =~ /$filesystem_path_re/oamsx)) {
    return @dirs_basename_and_suffixes;
  } else { 
    return undef; 
  }
}

#
# Read the entire file into $text (or @text, if used in list context
# to return an array of lines):
#
# (This is usually faster than the following code, despite looking
# like it's a lot longer and more convoluted, since it bypasses
# buffering and directly uses the read syscall to grab everything).
#
# read_file_handle {
#  my ($F) = @_;
#  local $/; # turn off all line separators in this function
#  return <$F>;
# }
#

our $max_read_chunk_size = 1048576;

sub read_file_handle($;+$) {
  my ($fd, $bufref, $limit) = @_;
  $limit //= LONG_MAX;

  $fd = get_native_fd($fd);
  my $buf = '';
  $bufref = \$buf if (!defined($bufref)) || (!ref($bufref));

  my $stats = get_file_stats_of_fd($fd);
  return undef if (!defined $stats);

  my ($type, $size) = @{$stats}[STAT_TYPE, STAT_SIZE];

  my $is_file = ($type == FILE_TYPE_FILE) ? 1 : 0;
  my $chunksize = ($is_file) ? $size : $max_read_chunk_size;
  if ($is_file) { set_min($limit, $size); }

  while ($limit >= 0) {
    my $offset = length($$bufref);
    my $bytes_to_read = min($chunksize, $limit);
    my $n = sys_read($fd, ($offset > 0) ? substr($$bufref, $offset) : $$bufref, $bytes_to_read);
    
    if (!defined($n)) { die("read_file_handle(): WARNING: n not defined: errno = ".$!.", ^E = ".$^E.NL); }
    return undef if (!defined($n));
    last if ($n <= 0);

    $limit -= $n;
  }

  return $$bufref;
}

sub read_file($;+$) {
  my ($filename, $bufref, $limit) = @_;
  my $fd = sys_open($filename, O_RDONLY);
  return undef if (!defined $fd);
  my $data = read_file_handle($fd, $bufref);
  sys_close($fd);
  return $data;
}

sub read_file_handle_as_lines($;+$) {
  my ($fd, $bufref, $limit) = @_;
  my $data = read_file_handle($fd, $bufref, $limit);
  if (!defined $data) { return (wantarray ? ( ) : undef); }
  my $lines = [ split(/\n/oamsx, $data) ];
  return (wantarray ? @$lines : $lines);
}

sub read_file_as_lines($;+$) {
  my ($filename, $bufref, $limit) = @_;
  my $data = read_file($filename, $bufref, $limit);
  if (!defined $data) { return (wantarray ? ( ) : undef); }
  my $lines = [ split(/\n/oamsx, $data) ];
  return (wantarray ? @$lines : $lines);
}

sub write_file_handle($+) {
  my ($fd, $data) = @_;

  $fd = get_native_fd($fd);
  if (!defined $fd) { die('file handle has no underlying native file descriptor'); }

  # If we've been passed an array, write it as a series of lines of text:
  if (is_array_ref($data)) { $data = join(NL, @$data); }

  my $len = length($data);
  my $remaining = $len;
  my $offset = 0;
  do {
    my $n = sys_write($fd, ($offset > 0) ? substr($data, $offset) : $data, $remaining);

    if (!defined($n)) 
      { warn('Cannot write to fd '.$fd.': '.$!); return undef; }

    $remaining -= $n;
    $offset += $n;
  } while ($remaining > 0);

  return $len;
}

sub write_file($+) {
  my ($filename, $buf) = @_;

  my $fd = sys_open($filename, O_WRONLY|O_CREAT|O_TRUNC);
  if (!defined $fd) { return undef; }
  my $len = write_file_handle($fd, $buf);
  sys_close($fd);
  return $len;
}

sub write_file_safely($+;$) {
  my ($filename, $buf, $temp_suffix, $sync) = @_;
  $temp_suffix //= '.~tmp~.pid-'.getpid();
  my $temp_filename = $filename.$temp_suffix;

  my $fd = sys_open($temp_filename, O_WRONLY|O_CREAT|O_TRUNC);
  if (!defined $fd) { return undef; }
  my $n = write_file_handle($fd, $buf);
  if ((!defined sys_fdatasync($fd)) || (!defined sys_close($fd)) || 
      (!defined $n) || ($n != (length $buf))) {
    sys_unlink($temp_filename);
    return undef; 
  }

  if (!rename($temp_filename, $filename)) { return undef; }

  return $n;
}

sub write_file_with_backup($+;$$) {
  my ($filename, $buf, $backup_filename) = @_;
  $backup_filename //= $filename.'.orig';

  if (!rename($filename, $backup_filename)) { return undef; }

  return (write_file($filename, $buf));
}

sub new_handle_from_fd($;$) {
  my ($fd, $flags) = @_;

  my $fdmode = ($flags & O_ACCMODE);
  my $append = ($flags & O_APPEND);

  my $plmode = 
    (($fdmode == O_RDONLY) ? 'r' :
     ($fdmode == O_WRONLY) ? ($append ? 'a' : 'w') :
     ($fdmode == O_RDWR) ? ($append ? 'a+' : 'r+') : '');

  return IO::File->new_from_fd($fd, $plmode);
}

use constant {
  READ_DIR_FILENAMES => 0,
  READ_DIR_INODES_AND_TYPES => 1,
  READ_DIR_PACKED_INODES_AND_TYPES => 2,
};

noexport:; sub read_directory_handle_internal($$) {
  my ($fd, $format) = @_;

  my @filelist = ($format >= READ_DIR_INODES_AND_TYPES) ? sys_readdir_ext($fd) : sys_readdir($fd);
  if ($format == READ_DIR_INODES_AND_TYPES)
    { @filelist = pairmap { $a => [ inode_and_type_of_dir_entry($b) ] } @filelist; };

  return @filelist;
}

sub read_directory_handle($;$) {
  my ($fd, $format) = @_;
  $format //= READ_DIR_FILENAMES;

  if (is_numeric($fd)) {
    # We're reading a native file descriptor instead of a Perl file handle,
    # so redirect this through /proc/self/fd/<fd> as if we specified that path:
    return (read_directory('/proc/self/fd/'.$fd, $format));
  }

  my @filelist = read_directory_handle_internal($fd, $format);

  return (wantarray ? @filelist : (($format >= READ_DIR_INODES_AND_TYPES) ? { @filelist } : [ @filelist ]));
}

sub read_directory($;$) {
  my ($path, $format) = @_;
  $format //= READ_DIR_FILENAMES;

  my $fd = sys_opendir($path);

  if (!defined $fd) {
    warn('read_directory(): Cannot open directory "'.$path.'"'); 
    return undef; 
  }

  my @filelist = read_directory_handle_internal($fd, $format);
  
  sys_closedir($fd);

  return (wantarray ? @filelist : (($format >= READ_DIR_INODES_AND_TYPES) ? { @filelist } : [ @filelist ]));
}

sub is_same_file {
  my ($file1, $file2) = @_;
  my $file1_stats = get_file_stats($file1);
  my $file2_stats = get_file_stats($file2);
  if ((!defined $file1_stats) || (!defined $file2_stats)) { return 0; }

  return (($file1_stats->[STAT_DEV] == $file2_stats->[STAT_DEV]) && 
          ($file1_stats->[STAT_INODE] == $file2_stats->[STAT_INODE])) ? 1 : 0;
}

sub get_fd_type {
  my $stats = get_file_stats_of_fd(@_);
  if (!defined $stats) { return undef; }
  return $stats->[STAT_TYPE];
}

sub actual_filename_of_open_fd($) {
  my ($fd) = @_;
  my $stats = get_file_stats_of_fd($fd);
  return ($stats->[STAT_TYPE] == FILE_TYPE_FILE) ? $stats->[STAT_PATH] : undef;
}

sub get_dev_node_major_minor_type {
  my $stats = get_file_stats(@_);
  if (!defined $stats) { return (wantarray ? ( ) : undef); }
  my ($major, $minor) = split_major_minor_dev($stats->[STAT_BLOCK_CHAR_DEV_SPEC]);
  my @ret = ($major, $minor, ($stats->[STAT_MODE] >> S_IFMT_SHIFT), $stats);
  return (wantarray ? @ret : \@ret);
}

sub longest_common_string_component_prefix(+;$$) {
  my ($list, $separator, $separator_re) = @_;

  $separator //= '/';
  my $separator_escaped = quotemeta($separator);
  $separator_re //= (($separator eq '/')
    ? $path_separator_re
    : qr{${separator_escaped}++}oamsx);

  my $n = scalar @$list;
  if ($n <= 1) { return (($n) ? $list->[0] : ''); }

  my @split_list = map { [ split $separator_re, $_ ] } @$list;

  my @longest = longest_common_array_prefix(@split_list);
  return (wantarray ? @longest : join($separator, @longest));
}

sub longest_common_path_prefix(+;@) {
  my $list = ((defined $_[0]) && (is_array_ref $_[0])) ? $_[0] : \@_;

  return longest_common_string_component_prefix($list, '/');
}

1;
