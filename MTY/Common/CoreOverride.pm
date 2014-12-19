#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::CoreOverride
#
# Globally override Perl core functions with user defined
# functions using the following syntax:
# 
#  use MTY::Common::CoreOverride (
#     original_symbol1 => 'override_with_symbol',
#     original_symbol2 => 'Optional::Package::override_with_symbol2',
#     ...
#  );
#
# Copyright 1997 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::CoreOverride;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = ( );

sub import {
  my $package = shift;

  my $contains_namespace_re = qr{::}oax; 
  my $caller_package = caller(0).'::';

  while (@_) {
    my ($original_symbol, $override_with_symbol) = (shift, shift);
    die if ((!defined $original_symbol) || (!defined $override_with_symbol));

    if ($override_with_symbol !~ $contains_namespace_re)
      { $override_with_symbol = $caller_package.$override_with_symbol; };
    
    *{$original_symbol} = *{$override_with_symbol};
    push @EXPORT_OK, $original_symbol;
  }

  $package->export('CORE::GLOBAL', @EXPORT_OK);
}

1;
