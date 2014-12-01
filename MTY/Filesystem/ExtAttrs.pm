#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::ExtAttrs
#
# Extended Attribute (xattr) queries and manipulation
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::ExtAttrs;

use integer; use warnings; use Exporter::Lite;

preserve:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(get_xattr get_xattr_names get_xattrs has_xattrs
     remove_xattr remove_xattrs set_xattr set_xattrs
    sys_getxattr sys_setxattr sys_removexattr sys_listxattr);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Filesystem::Files;

use Linux::UserXAttr qw(:all);

BEGIN {
  *sys_getxattr = *Linux::UserXAttr::getxattr;
  *sys_setxattr = *Linux::UserXAttr::setxattr;
  *sys_removexattr = *Linux::UserXAttr::removexattr;
  *sys_listxattr = *Linux::UserXAttr::listxattr;
};

sub set_xattrs($+;$) {
  my ($path, $hash, $basefd) = @_;
  $basefd //= AT_FDCWD;

  my $fd = open_file_or_dir($path);
  if (!(defined $fd)) { return undef; }

  my $n = 0;

  foreach my $k (keys %{$hash}) {
    my $v = $hash->{$k};
    $n++;
    my $ok = 1;
    if (defined $v) {
      if (!sys_setxattr($fd, $k, $v)) { $ok = 0; }
    } else {
      if (!sys_removexattr($fd, $k)) { $ok = 0; }
    }

    if (!$ok) {
      $fd->close();
      return -$n;
    }
  }

  $fd->close();
  return $n;
}

sub set_xattr($$$;$) {
  my ($path, $xattr_name, $xattr_value, $basefd) = @_;
  $basefd //= AT_FDCWD;

  if (!sys_setxattr($path, $xattr_name, $xattr_value)) { return undef; }
  return 1;
}

sub remove_xattrs($+;$) {
  my ($path, $xattr_names, $basefd) = @_;

  my $fd = open_file_or_dir($path);
  if (!(defined $fd)) { return undef; }

  my $n = 0;

  foreach my $name (@{$xattr_names}) {
    $n++;
    if (!sys_removexattr($fd, $name)) {
      $fd->close();
      return -$n;
    }
  }

  $fd->close();
  return $n;
}

sub remove_xattr($$;$) {
  my ($path, $xattr_name) = @_;

  if (!sys_removexattr($path, $xattr_name)) { return undef; }
  return 1;
}

sub get_xattrs($;$) {
  my ($path, $fd) = @_;

  if (!defined $fd) {
    $fd = open_file_or_dir($path);
    if (!(defined $fd)) { return undef; }
  }

  my %xattrs = ( );

  my $xattr_names = listxattr($fd);
  if (!(defined $xattr_names)) { 
    $fd->close();
    return undef;
  }

  foreach my $name (@{$xattr_names}) {
    my $value = sys_getxattr($fd, $name);
    $xattrs{$name} = $value;
  }

  $fd->close();
  return (wantarray ? %xattrs : \%xattrs);
}

sub get_xattr($$;$) {
  my ($path, $xattr_name, $basefd) = @_;

  return sys_getxattr($path, $xattr_name);
}

sub get_xattr_names($) {
  my ($path) = @_;

  my @xattr_names = listxattr($path);
  return (wantarray ? @xattr_names : \@xattr_names);
}

sub has_xattrs($;$) {
  my ($path, $basefd) = @_;

  my @xattr_names = listxattr($path);
  return (scalar @xattr_names);
}

1;
