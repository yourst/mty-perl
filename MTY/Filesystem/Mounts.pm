#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::Mounts
#
# Process related utility functions that use /proc on Linux
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::Mounts;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(MOUNTINFO_ID MOUNTINFO_TYPE MOUNTINFO_SOURCE find_mount_point
     MOUNTINFO_OPTIONS query_mount_point MOUNTINFO_ABS_ROOT MOUNTINFO_CATEGORY
     MOUNTINFO_DEV_MAJOR MOUNTINFO_DEV_MINOR MOUNTINFO_MISC_INFO
     MOUNTINFO_PARENT_ID MOUNTINFO_SUPER_OPTS MOUNTINFO_MOUNT_POINT
     query_mounted_filesystems MOUNTINFO_MOUNT_PATH_COMPONENTS);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::Common::Strings;
use MTY::RegExp::Define;
use MTY::Filesystem::ProcFS;
#pragma end_of_includes

#
# Note that these do not exactly correspond to the fields in 
# /proc/<pid>/mountinfo since MISC_INFO is actually a variable
# number of fields terminated by a '-' separator field, but we
# resolve that complexity in query_mounted_filesystems():
#
use constant {
  MOUNTINFO_ID                    => 0,
  MOUNTINFO_PARENT_ID             => 1,
  MOUNTINFO_DEV_MAJOR             => 2,
  MOUNTINFO_DEV_MINOR             => 3,
  MOUNTINFO_ABS_ROOT              => 4,
  MOUNTINFO_MOUNT_POINT           => 5,
  MOUNTINFO_OPTIONS               => 6,
  MOUNTINFO_MISC_INFO             => 7,
  MOUNTINFO_MOUNT_PATH_COMPONENTS => 8,
  MOUNTINFO_TYPE                  => 9,
  MOUNTINFO_SOURCE                => 10,
  MOUNTINFO_SUPER_OPTS            => 11,
  MOUNTINFO_CATEGORY              => 12, # reuses the FILE_TYPE_MOUNT_xxx constants
};

my $proc_mountinfo_re = compile_regexp(
  qr{^ (\d++) \s++ # ID
        (\d++) \s++ # PARENT_ID
        (\d++):(\d++) \s++ # DEV (major:minor)
        (\S++) \s++ # ABS_ROOT
        (\S++) \s++ # MOUNT_POINT
        (\S++) \s++ # OPTIONS (i.e. option=value,option=value,...)
        ((?> \w++ :? [^\s]*+)*+) \s++ # MISC_INFO
        (-) \s++ # (separator at end of variable length MISC_INFO list)
        (\S++) \s++ # type
        (\S++) \s++ # source (device node path or other identifier)
        (\S++) \s*+ $ # super options (for all instances of this fs type)
     }oamsx, 'proc_mountinfo');

my $proc_mounts_re = qr{^ (\S++) \s++ (\S++) \s++ (\S++)}oamsx;

my $mounts = undef;
my $supported_fs_types = undef;

my %nodev_filesystem_categories = (
# volatile in-memory filesystems capable of storing arbitrary data:
  tmpfs             => FILE_TYPE_VOLATILE_MOUNT,
  ramfs             => FILE_TYPE_VOLATILE_MOUNT,
  devtmpfs          => FILE_TYPE_VOLATILE_MOUNT,
# these are used solely by the kernel for tracking anonymous unnamed objects:
  rootfs            => FILE_TYPE_ANONYMOUS_MOUNT,
  bdev              => FILE_TYPE_ANONYMOUS_MOUNT,
  pipefs            => FILE_TYPE_ANONYMOUS_MOUNT,
  sockfs            => FILE_TYPE_ANONYMOUS_MOUNT,
# userspace filesystems (FUSE):
  fuse              => FILE_TYPE_FUSE_MOUNT,
# known types of network filesystems:
  autofs            => FILE_TYPE_NETWORK_MOUNT,
  nfs               => FILE_TYPE_NETWORK_MOUNT,
  nfs4              => FILE_TYPE_NETWORK_MOUNT,
  nfsv4             => FILE_TYPE_NETWORK_MOUNT,
  nfs               => FILE_TYPE_NETWORK_MOUNT,
  ceph              => FILE_TYPE_NETWORK_MOUNT,
  cifs              => FILE_TYPE_NETWORK_MOUNT,
  smbfs             => FILE_TYPE_NETWORK_MOUNT,
  ncpfs             => FILE_TYPE_NETWORK_MOUNT,
  coda              => FILE_TYPE_NETWORK_MOUNT,
  afs               => FILE_TYPE_NETWORK_MOUNT,
  '9p'              => FILE_TYPE_NETWORK_MOUNT,
# (any others not listed here are assumed to be FILE_TYPE_SPECIAL_MOUNT)
);

sub query_mounted_filesystems(;$) {
  if (!defined $supported_fs_types) {
    my $lines = read_proc_lines('filesystems') || return undef;
    $supported_fs_types = { };
    foreach (@$lines) {
      my ($nodev, $fstype) = /^(\w*+) \s++ (.++)$/oax;
      my $category = 
        ($nodev eq 'nodev') ?
          ($nodev_filesystem_categories{$fstype} // FILE_TYPE_SPECIAL_MOUNT) :
          FILE_TYPE_BLOCK_DEV_MOUNT;
      $supported_fs_types->{$fstype} = $category;
    }
  }

  if (!defined $mounts) {
    $mounts = { };

    my $lines = read_proc_lines('self', 'mountinfo') || return undef;

    foreach (@$lines) {
      my @info = /$proc_mountinfo_re/oamsx;
      my $mountpoint = $info[MOUNTINFO_MOUNT_POINT];
      $info[MOUNTINFO_MOUNT_PATH_COMPONENTS] = split(/\//, $mountpoint);
      $info[MOUNTINFO_CATEGORY] = 
        $supported_fs_types{$info[MOUNTINFO_TYPE]} // FILE_TYPE_MOUNT_POINT;
      $mounts->{$mountpoint} = \@info;
    }
  }

  return ((defined $_[0])
    ? $mounts{$_[0]}
    : (wantarray ? %$mounts : $mounts));
}

sub query_mount_point($) {
  my ($path) = @_;

  my $mountpoints = query_mounted_filesystems();
  die if (!defined $mountpoints);

  $path = resolve_path($path);
  return $mountpoints->{$path};
}

my $terminal_char_dev_path = undef;
#
# Determine the closest filesystem mount point
# directory which contains the specified path:
#

sub find_mount_point($) {
  my ($path) = @_;
  $path = resolve_path($path);

  my @path_components = split(/\//oax, $path);
  my $n = scalar(@path_components);
  if (!$n) { $path = './$path'; $n = 1; }

  my $mountpoints = query_mounted_filesystems();
  die if (!defined $mountpoints);

  my $closest_mount_point = '/';
  my $path_so_far = '';

  # work forwards from the root so we can properly detect 
  # where symlinks redirect us onto different filesystems:
  foreach my $dir (@path_components) {
    next if (!length($dir));
    $path_so_far .= '/'.$dir;
    if (exists $mountpoints->{$path_so_far}) 
      { $closest_mount_point = $path_so_far; }
  }

  return $closest_mount_point;
}

1;
