#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::EnvVarDefaults
#
# Check a per-package environment variable exported by the shell, where the
# environment variable name is the fully qualified package namespace of the
# caller, with '_' in placeof '::', i.e. My::Calling::Package becomes 
# 'My_Calling_Package'.
#
# The environment variable uses the format 'key=val, key=val, ...',
# where <key> may contain any character in a valid Perl identifier,
# i.e. the \w character class, and <val> may contain any character
# except ',' ':' or '=' (these special characters must be escaped as 
# '\,', '\=', '\:' if contained within <val>). The ':' character may
# optionally be used in place of '=' to separate keys from values,
# and a tab (\t) or newline (\n) may optionally be used instead of
# ',' to separate the key=value pairs from each other.
#
# The get_defaults_from_env() function returns a hash that maps these
# default option names to their specified values. The calling package
# can then configure itself and/or its package local variables as it
# wishes based on these defaults.
#
# This package and get_defaults_from_env() are explicitly intended to
# be safely usable within an INIT { ... } block of the calling package,
# and this package does not depend on any other packages outside the
# MTY::Common and MTY::RegExp namespaces (unlike the more fully 
# featured MTY::Common::CommandLine package).
#
# Copyright 1997 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::EnvVarDefaults;

use MTY::Common::Common;

use integer; use warnings; use Exporter::Lite;
#pragma end_of_includes

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(get_defaults_from_env);

my $env_defaults_sep_re = qr{(?<! \\) [\,\:\=\s]++}oamsx;

#
# Returns reference to the hash of defaults obtained from the 
# environment variable described earlier, or an empty hash if
# no such variable exists in the environment.
#
# The first argument may optionally be a hash that maps setting 
# names within this environment variable to references to other
# scalar variables of the caller's choice; these variables will
# be automatically set to the specified value string if the
# corresponding setting name is specified in the environment
# variable. The setting will also be in the returned hash.
#
# The second and subsequent arguments may optionally specify
# the names of additional environment variables to check if
# the <Calling_Package_Name> environment variable is not set.
#
sub get_defaults_from_env(;+@) {
  my ($vars_to_set, @other_env_var_names) = @_;

  my $package = caller() =~ s{::}{_}roaxg;
  return (wantarray ? ( ) : { }) if (!defined $package);
  my ($program) = ($0 =~ /([^\/]*+) \Z/oamsx);
  if ($program eq '-e') { $program = 'perl_eval'; }

  my $e = undef;
  $e //= $ENV{$program.'_'.$package} if (defined $program);
  $e //= $ENV{$package};
  foreach my $varname (@other_env_var_names) { $e //= $ENV{$varname}; }

  my $env_var_keys_must_specify_package = (!defined $e);

  if (!defined $e) {
    $e //= $ENV{uc($program)} // $ENV{$program};
  }

  return (wantarray ? ( ) : { }) if (!defined $e);

  my @key_val_list = split($env_defaults_sep_re, $e);
  my $settings;

  #
  # If the number of elements in the list is odd, it isn't a valid
  # key => value mapping, so don't try to cast it to a hash, but
  # still set the '' entry in the returned hash in case the caller
  # wants to interpret the settings itself using some other format.
  #
  if (((scalar @key_val_list) & 1) == 0) { $settings = { @key_val_list }; }
  $settings->{''} = $e;

  if (defined $vars_to_set) {
    while (my ($key, $value) = each %$settings) {
      next if ((!defined $key) || (!defined $value));

      next if ($env_var_keys_must_specify_package && (substr($key, 0, length($package)+1) ne $package.'_'));

      my $ref = $vars_to_set->{$key};
      next if (!defined $ref);

      my $type = typeof($ref);
      if ($type == SCALAR_REF) {
        ${$ref} = $value;
      } elsif ($type == ARRAY_REF) {
        @{$ref} = split(/\ ++/oax, $value);
      } else {
        die("get_defaults_from_env($package): cannot set variable for '$key': ".
            "must be ref to scalar or array");
      }      
    }
  }

  return (wantarray ? %$settings : $settings);
}

1;