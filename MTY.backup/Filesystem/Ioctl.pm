#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::System::Misc
#
# Linux I/O Device Controls (ioctls)
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::Ioctl;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(IOCTL_BLKALIGNOFF IOCTL_BLKBSZGET IOCTL_BLKBSZSET IOCTL_BLKDISCARD
     IOCTL_BLKDISCARDZEROES IOCTL_BLKFLSBUF IOCTL_BLKFRAGET IOCTL_BLKFRASET
     IOCTL_BLKGETSIZE IOCTL_BLKGETSIZE64 IOCTL_BLKIOMIN IOCTL_BLKIOOPT
     IOCTL_BLKPBSZGET IOCTL_BLKRAGET IOCTL_BLKRASET IOCTL_BLKROGET
     IOCTL_BLKROSET IOCTL_BLKROTATIONAL IOCTL_BLKRRPART IOCTL_BLKSECDISCARD
     IOCTL_BLKSECTGET IOCTL_BLKSECTSET IOCTL_BLKSSZGET IOCTL_BLKZEROOUT
     IOCTL_FIBMAP IOCTL_FIFREEZE IOCTL_FIGETBSZ IOCTL_FITHAW IOCTL_FITRIM
     IOCTL_FORMAT_BYTE IOCTL_FORMAT_INT16 IOCTL_FORMAT_INT32
     IOCTL_FORMAT_INT64 IOCTL_FORMAT_UBYTE IOCTL_FORMAT_UINT16
     IOCTL_FORMAT_UINT32 IOCTL_FORMAT_UINT64 IOCTL_FS_IOC32_GETFLAGS
     IOCTL_FS_IOC32_GETVERSION IOCTL_FS_IOC32_SETFLAGS
     IOCTL_FS_IOC32_SETVERSION IOCTL_FS_IOC_FIEMAP IOCTL_FS_IOC_GETFLAGS
     IOCTL_FS_IOC_GETVERSION IOCTL_FS_IOC_SETFLAGS IOCTL_FS_IOC_SETVERSION
     IOCTL_TIOCGWINSZ IOCTL_TIOCSWINSZ get_block_dev_size
     get_terminal_window_size ioctl_open_and_query_with_format
     ioctl_open_and_set_with_format ioctl_query_byte ioctl_query_int16
     ioctl_query_int32 ioctl_query_int64 ioctl_query_ubyte ioctl_query_uint16
     ioctl_query_uint32 ioctl_query_uint64 ioctl_query_with_format
     ioctl_set_byte ioctl_set_int16 ioctl_set_int32 ioctl_set_int64
     ioctl_set_ubyte ioctl_set_uint16 ioctl_set_uint32 ioctl_set_uint64
     ioctl_set_with_format);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
#pragma end_of_includes

sub ioctl_query_with_format($$$;$) {
  my ($fd, $ioctl, $format, $field_count) = @_;
  # not always accurate, but caller should specify this explicitly if needed:
  $field_count //= length($format); 

  my $packed = pack($format, ((0) x $field_count));
  my $rc = ioctl($fd, $ioctl, $packed) || -1;
  if ($rc < 0) { $! = -$rc; return undef; }
  my @out = unpack($format, $packed);
  return (wantarray ? @out : $out[0]);
}

sub ioctl_open_and_query_with_format($$$;$) {
  my ($devpath, $ioctl, $format, $cache) = @_;

  my $cachekey = $devpath.'/'.$ioctl;
  if ((defined $cache) && (exists $cache->{$cachekey})) { return $cache->{$cachekey}; }
  sysopen(my $fd, $devpath, O_RDONLY) || return undef;
  my @out = ioctl_query_with_format($fd, $ioctl, $format);
  close($fd);
  if (defined $cache) { $cache->{$cachekey} = (((scalar @out) > 1) ? [ @out ] : $out[0]); }
  return (wantarray ? @out : $out[0]);
}

sub ioctl_set_with_format($$+$;$) {
  my ($fd, $ioctl, $v, $format, $field_count) = @_;
  if (!is_array_ref $v) { $v = [ $v ]; }

  $field_count //= scalar(@$v);

  my $packed = pack($format, @$v);
  my $rc = ioctl($fd, $ioctl, $packed) || -1;
  if ($rc < 0) { $! = -$rc; return $rc; }
  return 0;
}

sub ioctl_open_and_set_with_format($$+$;$) {
  my ($devpath, $ioctl, $v, $format, $field_count) = @_;

  sysopen(my $fd, $devpath, O_RDWR) || return undef;
  my $rc = ioctl_set_uint64($fd, $ioctl, $v, $format, $field_count);
  close($fd);
  return $rc;
}

use constant {
  IOCTL_FORMAT_BYTE => 'c',
  IOCTL_FORMAT_UBYTE => 'C',
  IOCTL_FORMAT_INT16 => 's',
  IOCTL_FORMAT_UINT16 => 'S',
  IOCTL_FORMAT_INT32 => 'i',
  IOCTL_FORMAT_UINT32 => 'I',
  IOCTL_FORMAT_INT64 => 'q',
  IOCTL_FORMAT_UINT64 => 'Q',
};

sub ioctl_query_byte($$) { return ioctl_query_with_format($_[0], $_[1], 'c'); }
sub ioctl_query_ubyte($$) { return ioctl_query_with_format($_[0], $_[1], 'C'); }
sub ioctl_query_int16($$) { return ioctl_query_with_format($_[0], $_[1], 's'); }
sub ioctl_query_uint16($$) { return ioctl_query_with_format($_[0], $_[1], 'S'); }
sub ioctl_query_int32($$) { return ioctl_query_with_format($_[0], $_[1], 'i'); }
sub ioctl_query_uint32($$) { return ioctl_query_with_format($_[0], $_[1], 'I'); }
sub ioctl_query_int64($$) { return ioctl_query_with_format($_[0], $_[1], 'q'); }
sub ioctl_query_uint64($$) { return ioctl_query_with_format($_[0], $_[1], 'Q'); }

sub ioctl_set_byte($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'c'); }
sub ioctl_set_ubyte($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'C'); }
sub ioctl_set_int16($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 's'); }
sub ioctl_set_uint16($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'S'); }
sub ioctl_set_int32($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'i'); }
sub ioctl_set_uint32($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'I'); }
sub ioctl_set_int64($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'q'); }
sub ioctl_set_uint64($$$) { return ioctl_set_with_format($_[0], $_[1], $_[2], 'Q'); }

use constant {
  IOCTL_BLKROSET => 0x0000125d,
  IOCTL_BLKROGET => 0x0000125e,
  IOCTL_BLKRRPART => 0x0000125f,
  IOCTL_BLKGETSIZE => 0x00001260,
  IOCTL_BLKFLSBUF => 0x00001261,
  IOCTL_BLKRASET => 0x00001262,
  IOCTL_BLKRAGET => 0x00001263,
  IOCTL_BLKFRASET => 0x00001264,
  IOCTL_BLKFRAGET => 0x00001265,
  IOCTL_BLKSECTSET => 0x00001266,
  IOCTL_BLKSECTGET => 0x00001267,
  IOCTL_BLKSSZGET => 0x00001268,
  IOCTL_BLKBSZGET => 0x80081270,
  IOCTL_BLKBSZSET => 0x40081271,
  IOCTL_BLKGETSIZE64 => 0x80081272,
  IOCTL_BLKDISCARD => 0x00001277,
  IOCTL_BLKIOMIN => 0x00001278,
  IOCTL_BLKIOOPT => 0x00001279,
  IOCTL_BLKALIGNOFF => 0x0000127a,
  IOCTL_BLKPBSZGET => 0x0000127b,
  IOCTL_BLKDISCARDZEROES => 0x0000127c,
  IOCTL_BLKSECDISCARD => 0x0000127d,
  IOCTL_BLKROTATIONAL => 0x0000127e,
  IOCTL_BLKZEROOUT => 0x0000127f,
  IOCTL_FIBMAP => 0x00000001,
  IOCTL_FIGETBSZ => 0x00000002,
  IOCTL_FIFREEZE => 0xc0045877,
  IOCTL_FITHAW => 0xc0045878,
  IOCTL_FITRIM => 0xc0185879,
  IOCTL_FS_IOC_GETFLAGS => 0x80086601,
  IOCTL_FS_IOC_SETFLAGS => 0x40086602,
  IOCTL_FS_IOC_GETVERSION => 0x80087601,
  IOCTL_FS_IOC_SETVERSION => 0x40087602,
  IOCTL_FS_IOC_FIEMAP => 0xc020660b,
  IOCTL_FS_IOC32_GETFLAGS => 0x80046601,
  IOCTL_FS_IOC32_SETFLAGS => 0x40046602,
  IOCTL_FS_IOC32_GETVERSION => 0x80047601,
  IOCTL_FS_IOC32_SETVERSION => 0x40047602,
  IOCTL_TIOCGWINSZ => 0x00005413,
  IOCTL_TIOCSWINSZ => 0x00005414,
};

my $block_dev_size_cache = { };

sub get_block_dev_size($) {
  my ($fd_or_dev_path) = @_;
  return (is_file_handle($fd_or_dev_path))
    ? ioctl_query_with_format($fd_or_dev_path, IOCTL_BLKGETSIZE64, IOCTL_FORMAT_UINT64)
    : ioctl_open_and_query_with_format($fd_or_dev_path, IOCTL_BLKGETSIZE64, IOCTL_FORMAT_UINT64, $block_dev_size_cache);
}

sub get_terminal_window_size() {
  my $fd = STDOUT;
  my ($rows, $cols, $xpixels, $ypixels) = ioctl_query_with_format(
    $fd, IOCTL_TIOCGWINSZ, (IOCTL_FORMAT_UINT16 x 4), 4);

  return ($rows, $cols, $xpixels, $ypixels);
}

1;

