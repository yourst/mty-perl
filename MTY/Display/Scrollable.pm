#!/usr/bin/perl -w
# -*- cperl -*-
#
# Scrollable less-based display streams (MTY::Display::Scrollable)
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Display::Scrollable;

use integer; use warnings; use Exporter::Lite;

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($scrollable_less_args open_scrollable_stream);

use MTY::Common::Common;
use MTY::Filesystem::Files;

#
# Open a file handle piped to the "less" program; any lines written to
# this file handle will be easily scrollable on screen. The user can
# simply press Ctrl+C or Q to exit the scrollable mode.
#
# To ensure the file handle (and the associated "less" process) are
# closed at the end of the caller's scope, the caller should assign
# the returned file handle to a local variable, as in:
#
# sub example_e_g_show_help() {
#   local $helpfd = open_scrollable_stream();
#   print($helpfd, ...):
#   ...
#   (at end of $helpfd's scope, it will automatically be closed)
# }
#
# Without this, you always need to manually run close($fd) at the end.
#

our $scrollable_less_args = '-A -E -K -R -S -X';

sub open_scrollable_stream(;$) {
  my $args = $_[0] // $scrollable_less_args;
  $args = '| LESSCHARSET=utf-8 LESSUTFBINFMT=*u%04lx less '.$args;
  my $fd;
  if (!open($fd, $args)) { return undef; }

  binmode $fd, ':utf8';
  return $fd;
}

