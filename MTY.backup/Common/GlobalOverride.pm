#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::GlobalOverride
#
# Globally override arbitrary Perl functions with user defined
# functions using the following syntax:
# 
#  use MTY::Common::GlobalOverride (
#     original_symbol1 => 'override_with_symbol',
#     Target::Package::original_symbol2 => 'Optional::Package::override_with_symbol2',
#     ...
#  );
#
# Copyright 1997 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::GlobalOverride;

require Exporter;
#pragma end_of_includes
our @ISA = qw(Exporter);
our @EXPORT_OK = ( );

sub import {
  my $package = shift;

  my $contains_namespace_re = qr{::}oax;
  my $package_namespace_and_symbol_re = qr{^ (\w++ (?> :: \w++)*?) :: (\w+) $}oax;
  
  my $original_namespace = undef;

  while (@_) {
    my ($original_symbol, $override_with_symbol) = (shift, shift);
    die if ((!defined $original_symbol) || (!defined $override_with_symbol));

    if ($override_with_symbol !~ $contains_namespace_re)
      { $override_with_symbol = caller(0).'::'.$override_with_symbol; };
    
    if ($original_symbol =~ $package_namespace_and_symbol_re) 
      { ($target_namespace, $original_symbol) = ($1, $2); }

    my $target_namespace //= 'CORE::GLOBAL';

    if ((defined $original_namespace) && ($target_namespace ne $original_namespace)) { 
      die("Target namespace '$target_namespace' does not match ".
          "previously declared namespace '$original_namespace'");
    }

    $original_namespace = $target_namespace;
    
    *{$original_symbol} = *{$override_with_symbol};
    push @EXPORT_OK, $original_symbol;
  }

  $package->export($original_namespace, @EXPORT_OK) if (defined $original_namespace);
}

1;
