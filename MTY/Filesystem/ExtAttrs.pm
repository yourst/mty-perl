#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::ExtAttrs
#
# Extended Attribute (xattr) queries and manipulation
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::ExtAttrs;

use integer; use warnings; use Exporter qw(import);

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

noexport:; sub open_if_path($;$) {
  my ($path_or_fd, $mode) = @_;
  $mode //= O_RDONLY;

  if (defined fileno($path_or_fd)) { return $path_or_fd; }

  sysopen(my $fd, $path_or_fd, $mode) || return undef;
  return $fd;
}

sub set_xattrs($+) {
  my ($path_or_fd, $hash) = @_;

  my $fd = open_if_path($path_or_fd);
  if (!defined $fd) { return undef; }

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
      close($fd);
      return -$n;
    }
  }

  close($fd);
  return $n;
}

sub set_xattr($$$) {
  my ($path, $xattr_name, $xattr_value) = @_;

  if (!sys_setxattr($path, $xattr_name, $xattr_value)) { return undef; }
  return 1;
}

sub remove_xattrs($+;$) {
  my ($path_or_fd, $xattr_names) = @_;

  my $fd = open_if_path($path_or_fd);
  if (!defined $fd) { return undef; }

  my $n = 0;

  foreach my $name (@{$xattr_names}) {
    $n++;
    if (!sys_removexattr($fd, $name)) {
      close($fd);
      return -$n;
    }
  }

  close($fd);
  return $n;
}

sub remove_xattr($$;$) {
  my ($path, $xattr_name) = @_;

  if (!sys_removexattr($path, $xattr_name)) { return undef; }
  return 1;
}

sub get_xattrs($;$) {
  my ($path_or_fd) = @_;

  my $fd = open_if_path($path_or_fd);
  if (!defined $fd) { return undef; }

  my $xattrs = { };

  my @xattr_names = sys_listxattr($fd);

  foreach my $name (@xattr_names) 
    { $xattrs->{$name} = sys_getxattr($fd, $name); }

  close($fd);
  return $xattrs;
}

sub get_xattr($$;$) {
  my ($path, $xattr_name) = @_;

  return sys_getxattr($path, $xattr_name);
}

sub get_xattr_names($) {
  my ($path) = @_;

  my @xattr_names = sys_listxattr($path);
  return (wantarray ? @xattr_names : \@xattr_names);
}

sub has_xattrs($;$) {
  my ($path) = @_;

  my @xattr_names = sys_listxattr($path);
  return (scalar @xattr_names);
}

1;
