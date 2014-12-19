#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::EnhancedFileStats
#
# Enhanced file stat() facility which also identifies extended attributes,
# ACLs, mount points, subvolumes, open files and more
#
# Copyright 1997 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::EnhancedFileStats;

#
# NOTE: EnhancedFileStats is a separate module from FileStats
# (which has most of the relevant constant definitions) since
# this is arrangement was necessary to break a dependency
# loop with other modules (like MTY::Filesystem::BtrFS) which
# need the basic stat() facilities, yet the enhanced stat()
# facilities themselves depend on these other modules. 
#
# Therefore, you should use both FileStats and EnhancedFileStats
# when the enhanced stat() facility is desired.
#
use integer; use warnings; use Exporter::Lite;

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(STATS_FOLLOW_SYMLINKS STATS_QUERY_ACCESSIBLE STATS_QUERY_ACLS
     STATS_QUERY_ALL STATS_QUERY_DEFAULT STATS_QUERY_EXTENTS
     STATS_QUERY_MOUNTS STATS_QUERY_OPENFD STATS_QUERY_SYMLINK
     STATS_QUERY_XATTRS STATS_QUERY_XATTR_VALUES get_enhanced_file_stats
     is_directory_from_stats is_path_directory open_and_read_directory
     stat_files_in_directory);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Common::Cache;
use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::RegExp::FilesAndPaths;
use MTY::Filesystem::Mounts;
use MTY::Filesystem::ExtAttrs;
use MTY::Filesystem::ProcFS;
use MTY::Filesystem::OpenFiles;
use MTY::Filesystem::ExtentMap;
use MTY::Filesystem::BtrFS;

# use with s{$remove_trailing_slash_re}{}oamsx:
my $remove_trailing_slash_re = qr{\/$}oamsx;

use constant {
# STATS_QUERY_BASE       (1 << 0), # basic sys_stat() info + (type, name, path)
  STATS_QUERY_SYMLINK => (1 << 1), # symlink target
  STATS_QUERY_MOUNTS  => (1 << 2), # mount points
  STATS_QUERY_ACLS    => (1 << 3), # ext attrs
  STATS_QUERY_XATTRS  => (1 << 4), # ext attrs
  STATS_QUERY_XATTR_VALUES => (1 << 5), # ext attrs
  STATS_QUERY_OPENFD  => (1 << 6), # open files
  STATS_QUERY_EXTENTS => (1 << 7), # cloned copy-on-write extents (on btrfs et al)
  STATS_QUERY_ACCESSIBLE => (1 << 8), # STAT_IS_ACCESSIBLE is set to '1' if the caller can read the file or traverse the directory
};

use constant {
  #
  # Return the stats of the target of a symlink, not the link itself
  #
  STATS_FOLLOW_SYMLINKS => 0x40000000,

  #
  # Query all supported_stats (up to 28 categories,
  # since bit 30 is STATS_FOLLOW_SYMLINKS):
  #
  STATS_QUERY_ALL => 
    STATS_QUERY_BASE |
    STATS_QUERY_SYMLINK |
    STATS_QUERY_MOUNTS |
    STATS_QUERY_ACLS |
    STATS_QUERY_XATTRS |
    STATS_QUERY_XATTR_VALUES |
    STATS_QUERY_OPENFD |
    STATS_QUERY_EXTENTS |
    STATS_QUERY_ACCESSIBLE,

  #
  # Query the subset of all possible stats which we can obtain
  # quickly without requiring the caller to obtain additional
  # information for us (like the list of all open files, etc).
  # Mount points are still handled by default since /proc/mounts
  # only needs to be queried once (unless the caller is actively
  # mounting or unmounting filesystems of course).
  #
  STATS_QUERY_DEFAULT => 
    STATS_QUERY_BASE |
    STATS_QUERY_SYMLINK |
    STATS_QUERY_MOUNTS
};

sub get_enhanced_file_stats($;$+$$+$) {
  my ($name, $stats_subset, $stats, $base_dir_fd, $base_dir_name, $base_dir_stats, $open_files) = @_;

  $stats_subset //= STATS_QUERY_DEFAULT;

  $stats //= get_file_stats($name, $base_dir_fd, ($stats_subset & STATS_FOLLOW_SYMLINKS) ? 1 : 0);

  if (!defined $stats) { return undef; }

  my $fullpath = $stats->[STAT_PATH];

  my $existing_subset = $stats->[STAT_SUBSET] // 0;

  if (($stats_subset & $existing_subset) == $stats_subset) {
    # If the stats cache already contains the enhanced stats, just return them:
    return (wantarray ? @$stats : $stats); 
  }

  $stats->[STAT_SUBSET] = $stats_subset | $existing_subset;

  my $type = ($stats->[STAT_MODE] >> S_IFMT_SHIFT);
  $stats->[STAT_TYPE] = $type;
  $is_dir = ($type == FILE_TYPE_DIR); # but we don't know if the directory is a mount point or subvolume yet...
  $is_special = ($type == FILE_TYPE_PIPE) || ($type == FILE_TYPE_SOCKET) || ($type == FILE_TYPE_BLOCK_DEV) || ($type == FILE_TYPE_CHAR_DEV);

  if (($type == FILE_TYPE_SYMLINK) && ($stats_subset & STATS_QUERY_SYMLINK))
    { $stats->[STAT_SYMLINK] = sys_readlinkat($base_dir_fd // AT_FDCWD, $name); }

  my $xattrs = { };
  my $access_acl = undef;
  my $default_acl = undef;
  my $capability_acl = undef;

  my $query_acls = ($stats_subset & STATS_QUERY_ACLS) ? 1 : 0;
  my $query_xattrs = ($stats_subset & STATS_QUERY_XATTRS) ? 1 : 0;
  my $query_xattr_values = ($stats_subset & STATS_QUERY_XATTR_VALUES) ? 1 : 0;

  # querying ACLs implies querying at least xattr names, since ACLs are stored in xattrs:
  $query_xattrs |= $query_acls; 

  # querying xattr values implies querying the list of xattrs
  $query_xattrs |= $query_xattr_values;

  # querying xattr values lets us query ACLs with no extra overhead:
  $query_acls |= $query_xattr_values;

  if (($type != FILE_TYPE_SYMLINK) && $query_xattrs) {
    my @xattr_names = sys_listxattr($fullpath);
    
    if ($query_xattr_values) {
      foreach my $name (@xattr_names) 
        { $xattrs->{$name} = sys_getxattr($fullpath, $name); }
               
      if ($query_acls) {
        $access_acl = $xattrs->{'system.posix_acl_access'};
        $default_acl = $xattrs->{'system.posix_acl_default'};
        $capability_acl = $xattrs->{'security.capability'};
      }
    } else { # ! $query_xattr_values
      $xattrs = array_to_hash_keys([ @xattr_names ], undef);
    }

    if ($query_acls) {
      #
      # If we do not want xattrs but do want just the ACLs, 
      # use a faster method of only querying the access ACL
      # and default ACL plus any executable capabilities:
      #
      if (!$query_xattr_values) {
        # Only query the values of the xattrs that actually exist:
        foreach my $name (@xattr_names) {
          next if (ord($name) != ord('s')); # skip if not system.* or security.*
          my $ref = 
            ($name eq 'system.posix_acl_access') ? \$access_acl :
            ($name eq 'system.posix_acl_default') ? \$default_acl :
            ($name eq 'security.capability') ? \$capability_acl : undef;
          if (defined $ref) { 
            my $value = sys_getxattr($fullpath, $name); 
            $$ref = $value;
            $xattrs->{$name} = $value;
          }
        }
      }

      $stats->[STAT_ACL] = $access_acl;
      $stats->[STAT_DEFAULT_ACL] = $default_acl;
      $stats->[STAT_CAPABILITIES] = $capability_acl;
    }

    $stats->[STAT_XATTRS] = $xattrs;
  }

  if ($stats_subset & STATS_QUERY_EXTENTS) {
    my $extents = get_file_extents($fullpath, $stats);
    my $summary = summarize_extents($extents, $stats);
    $stats->[STAT_EXTENTS] = $summary;
  }

  if ($stats_subset & STATS_QUERY_OPENFD) {
    if (defined $open_files) {
      my $open_as_fd_in_contexts = $open_files->{$fullpath};
      $stats->[STAT_OPENFD] = $open_files->{$fullpath};
    }
  }

  if ($stats_subset & STATS_QUERY_ACCESSIBLE) {
    my $access_type = ($is_dir) ? X_OK : R_OK;
    $stats->[STAT_IS_ACCESSIBLE] = sys_faccessat($base_dir_fd // AT_FDCWD, $name, $access_type, AT_EACCESS) ? 1 : 0;
  }

  if (!$is_dir) { return $stats; } # files and other non-containers don't need any info collected below here

  #
  # It must be a simple directory if the device number of the parent
  # directory is the same as the specified directory's device number
  # (even subvolumes will change the minor device numbers):
  #
  # If the name ends with a slash, chop it off to prevent confusion:
  #

  #
  # It must be a mount point (or a subvolume) if we make it to here:
  #
  # (Note: the list of mounted filesystems is only obtained from 
  # /proc/self/mountinfo the first time this is called; subsequent
  # calls return the cached copy of this list unless it has changed:
  #

  if ($stats_subset & STATS_QUERY_MOUNTS) {
    if (!defined $base_dir_stats) {
      my $path_for_base_dir_stats_query = (defined $base_dir_fd) 
        ? undef : strip_last_path_component($fullpath);

      $base_dir_stats = get_file_stats($path_for_base_dir_stats_query, $base_dir_fd);
    }
    
    if (($base_dir_stats->[STAT_DEV] == $stats->[STAT_DEV]) && ($name ne '/'))
      { $stats->[STAT_TYPE] = FILE_TYPE_DIR; return $stats; }
  
    # default of empty '{ }' in case /proc/mounts was 
    # unavailable or the caller did not ask for mounts:
    my $all_mounts = query_mounted_filesystems() // { };
  
    #
    # We really need to have the entire absolute path name at this point.
    # If we are doing this relative to $base_dir_fd, it is OK if we just
    # slap the filename onto the end of $base_dir_name as long as we found
    # the real path with all symlinks resolved of the base directory
    # in which the specified file resides:
    #
  
    my $mountpoint = undef;
    my $mountinfo = $all_mounts->{$fullpath};
    
    if (!defined $mountinfo) {
      # It must be a subvolume of a mounted filesystem closer to the root:
      $mountpoint = find_mount_point($fullpath);
      if (!defined $mountpoint) { die("Cannot find filesystem containing '$fullpath'"); }
      $mountinfo = $all_mounts->{$mountpoint};
      if (!defined $mountinfo) { die("No mount information found for mount point '$mountpoint'"); }    
    }

    # Get the filesystem type name:
    $stats->[STAT_FSTYPE] = $mountinfo->[MOUNTINFO_TYPE];
    # We can simply reuse the mount category as the extended file type,
    # since by this point it is guaranteed to be a mount point directory
    # with one of the types FILE_TYPE_{BLOCK_DEV, BIND, VOLATILE, SPECIAL,
    # NETWORK or FUSE}_MOUNT:

    $stats->[STAT_TYPE] = $mountinfo->[MOUNTINFO_CATEGORY];
    
    if (($stats->[STAT_FSTYPE] eq 'btrfs') && 
          is_btrfs_subvol_or_root($fullpath, $stats)) {
      $stats->[STAT_TYPE] = (is_subvol_writable($fullpath) 
                               ? FILE_TYPE_SUBVOLUME :
                                 FILE_TYPE_SNAPSHOT);
    }
  } else { # (!STATS_QUERY_MOUNTS)
    if ($name eq '/') { $stats->[STAT_TYPE] = FILE_TYPE_MOUNT_POINT; }
  }

  return (wantarray ? (@$stats) : $stats);
}

sub is_path_directory($) {
  my ($dev, $inode, $mode) = get_file_stats($_[0], undef, 1);
  return S_ISDIR($mode) ? 1 : 0;
}

sub is_directory_from_stats($) {
  my ($stats) = @_;
  return (S_ISDIR($stats->[STAT_MODE]) ? 1 : 0);
}

#
# Open a O_PATH file descriptor for the specified path (which is typically a
# directory, but may also be a single file or other filesystem object). 
#
# Query the stats of the path to determine if it's a directory; if so, read 
# the directory to produce an array of the filenames it contains. If the path
# is *not* a directory, this array will have only one element corresponding to
# the path itself (specifically the non-directory portion of the path).
#
# Return the opened file descriptor, the array of filenames, the stats of the
# directory itself, and a flag indicating if the path was a directory or a file.
#
sub open_and_read_directory($;$$) {
  my ($path, $follow_symlinks, $exclude_dot_and_dot_dot) = @_;
  $follow_symlinks //= 0;
  $exclude_dot_and_dot_dot //= 0;

  my $dirfd = sys_open_path($path, undef, 0);
  if (!defined $dirfd) { warn('Cannot open "'.$path.'" (errno '.$?.')'); return undef; }

  my $base_path_stats = get_file_stats_of_fd($dirfd);
  my $path_is_dir = S_ISDIR($base_path_stats->[STAT_MODE]);
  my $flags = $exclude_dot_and_dot_dot ? READ_DIR_ExCLUDE_DOT_AND_DOT_DOT : 0;
  my $filenames = ($path_is_dir) ? read_directory($path, $flags) : [ $path ];
  return ($dirfd, $filenames, $base_path_stats, $path_is_dir);
}

sub stat_files_in_directory($;+$$+++$) {
  my ($base_dir_path, $filenames, $subset_and_flags, 
      $base_dir_fd, $base_dir_stats, $open_files, 
      $filename_to_stats_hash, $prepend_to_path_key) = @_;

  $subset_and_flags //= STATS_QUERY_DEFAULT;
  $prepend_to_path_key //= '';

  my $close_base_dir_fd = (!defined $base_dir_fd);

  $base_dir_fd //= sys_open_path($base_dir_path, undef, 0);

  if (!defined $base_dir_fd) { 
    warn('Cannot open directory "'.$base_dir_path.'" (errno '.$?.')');
    return undef;
  }

  $base_dir_stats //= [ get_file_stats_of_fd($base_dir_fd) ];
  die if (!scalar @$base_dir_stats);

  my $path_is_dir = ($base_dir_stats->[STAT_TYPE] == FILE_TYPE_DIR) || 
    ($base_dir_stats->[STAT_TYPE] >= FILE_TYPE_MOUNT_POINT);

  $filenames //= ($path_is_dir) ? read_directory($base_dir_path, READ_DIR_ExCLUDE_DOT_AND_DOT_DOT) : [ $base_dir_path ];

  $filename_to_stats_hash //= { };
  prealloc($filename_to_stats_hash, $filenames);

  foreach my $filename (@$filenames) {
    my $stats = get_enhanced_file_stats($filename, $subset_and_flags, undef, 
                                        $base_dir_fd, $base_dir_path, $base_dir_stats, 
                                        $open_files);

    $filename_to_stats_hash->{$prepend_to_path_key.$filename} = $stats;
  }

  sys_close($base_dir_fd) if ($close_base_dir_fd);

  return $filename_to_stats_hash;
}

1;
