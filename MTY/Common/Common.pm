#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::Common
#
# Common miscellaneous useful functions and tools for Perl
# (this module is included by all others in the MTY::...
# namespace, so it only depends on bullt-in perl modules).
#
# Copyright 1997 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::Common;

use integer; use warnings; use Exporter::Lite;
use re qw(is_regexp regexp_pattern regmust regname regnames regnames_count);

use Scalar::Util qw(refaddr reftype looks_like_number openhandle isdual blessed);
use List::Util qw(reduce any all none notall first sum0 pairgrep pairfirst pairmap pairs pairkeys pairvalues); # qw(max min)
#pragma end_of_includes

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($empty_array_ref $empty_hash_ref $empty_scalar $empty_scalar_ref
     $undef_scalar $zero_scalar %empty_hash %ref_type_string_to_index
     @empty_array @ref_type_index_to_string @ref_type_index_to_symbol
     ARRAY_REF BILLION BLESSED_REF CLASS_REF CODE_REF EB FORMAT_REF GB
     GLOB_REF HASH_REF IO_REF KB LVALUE_REF MB MILLION OBJECT_REF QUADRILLION
     RATIO_1_10 RATIO_1_2 RATIO_1_3 RATIO_1_4 RATIO_2_3 RATIO_3_4 RATIO_9_10
     REF_REF REGEXP_REF SCALAR SCALAR_REF TB THOUSAND TRILLION UNDEF
     UNDEF_REF VSTRING_REF all_defined all_empty all_filled all_there
     any_empty any_filled any_there any_undefined bit bitmask bits clipto
     compare_arrays compare_vec_to_scalar_and_generate_bitmask
     copy_array_elements_where_undef extractbits first_specified
     hash_of_constants_in_package inrange is_array_ref is_blessed_ref
     is_class_ref is_code_ref is_constant is_empty is_filled is_hash_ref
     is_numeric is_object_ref is_ref is_ref_ref is_regexp_ref is_scalar
     is_scalar_ref is_string is_there list_contains
     list_of_constants_in_package lowbits masked_store_into_array max
     max_in_list min min_in_list null pad_array pair_list_with_value
     partition_into_parallel_arrays partition_into_subarrays prealloc
     push_if_defined ratio_to_percent remove_dups remove_dups_in_place
     remove_undefs remove_undefs_in_place set_clipto set_max set_min
     shifted_bitmask single_value_sparse_array sizeof sparse_array
     topological_sort_dependencies typeof undefs_to undefs_to_empty_strings
     undefs_to_empty_strings_inplace undefs_to_inplace);

# Dummy variables to simplify creation of references (but these must not be modified!):
our @empty_array = ( );
our %empty_hash = ( );
our $empty_scalar = '';
our $empty_array_ref = \@empty_array;
our $empty_hash_ref = \@empty_hash;
our $empty_scalar_ref = \$empty_scalar;
our $zero_scalar = +0;
our $undef_scalar = undef;

use constant {
  SCALAR         => 0,  # simple scalar passed by value
  # ... or a reference to any of the following:
  SCALAR_REF     => 1,  # scalar value (may be a string, numeric or both: use isdual() to check)
  ARRAY_REF      => 2,  # array
  HASH_REF       => 3,  # hash
  CODE_REF       => 4,  # entry point of compiled perl function, subroutine or lambda
  REF_REF        => 5,  # indirect reference to another reference
  GLOB_REF       => 6,  # global symbol, potentially with per-type slots
  LVALUE_REF     => 7,  # assignable lvalue (as returned by 'sub xxx: lvalue { ... }'
  FORMAT_REF     => 8,  # precompiled string output format
  IO_REF         => 9,  # I/O capable object
  VSTRING_REF    => 10, # version string (e.g. 1.23.456); treated specially for comparisons
  REGEXP_REF     => 11, # regular expression pre-compiled and optimized by qr{...} et al.
  BLESSED_REF    => 12, # blessed reference to object or instance of class
  UNDEF          => 13, # undefined value
};

# Aliases to the *_REF constants above:
use constant {
  CLASS_REF => BLESSED_REF,
  OBJECT_REF => BLESSED_REF,
  UNDEF_REF => UNDEF,
  null => UNDEF,
};

our @ref_type_index_to_string = 
  qw(SCALAR SCALAR_REF ARRAY_REF HASH_REF CODE_REF REF_REF 
     GLOB_REF LVALUE_REF FORMAT_REF IO_REF/ VSTRING_REF REGEXP_REF);

our @ref_type_index_to_symbol =
  ('', '$', '@', '%', '&', '\\', '*', '=', 'FMT:', 'IO:', 'qr/', '::', '!');

#
# Note: the typeof() function below is faster than
# checking $ref_type_string_to_index{ref($...)},
# so this hash is for special uses only:
#
our %ref_type_string_to_index = (
  ''        => SCALAR,
  'SCALAR'  => SCALAR_REF,
  'ARRAY'   => ARRAY_REF,
  'HASH'    => HASH_REF,
  'CODE'    => CODE_REF,
  'REF'     => REF_REF,
  'GLOB'    => GLOB_REF,
  'LVALUE'  => LVALUE_REF,
  'FORMAT'  => FORMAT_REF,
  'IO'      => IO_REF,
  'Regexp'  => REGEXP_REF,
);

#
# The typeof(<obj>) function returns one of the xxx_REF constants listed above
# deppending on the data type of <obj> (which may be passed either as a true
# reference or as e.g. @obj, %obj, &obj, *obj, $obj, etc). This function is
# much faster than comparing the strings returned by ref(), since it only has
# to examine the first character of the reference type string to find the type
# of the reference (all type strings in perl (as of 5.18 at least) each have
# different initial characters, thus making it easy to disambiguate them (with
# the sole exception of (R)EF vs (R)egexp, but this is handled as a special
# case since it's not very common). 
#

my @ref_type_string_first_char_to_index = (
  SCALAR, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,          # 0   - 15
  0,      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,          # 16  - 31
  0,      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,          # 32  - 47
  0,      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,          # 48  - 63
  0,                                                            # 64
  ARRAY_REF, 0, CODE_REF, 0, 0, FORMAT_REF, GLOB_REF, HASH_REF, # 0  -  7 (A-H)
  IO_REF, 0, 0, LVALUE_REF, 0, 0, 0, 0,                         # 8  - 15 (I-P)
  0, REGEXP_REF, SCALAR_REF);                                   # 16 - 18 (Q-S)

sub typeof(+) {
  return undef if (!defined $_[0]);
  my $r = ref $_[0];
  my $t = (blessed $r) ? OBJECT_REF : $ref_type_string_first_char_to_index[ord($r)];
  return ($t != REGEXP_REF) ? $t : ((re::is_regexp($_[0])) ? REGEXP_REF : REF_REF);
}

sub is_scalar(+) { return (!ref($_[0])); }
sub is_ref { return (!!(ref $_[0])); }
sub is_scalar_ref { return (ord ref $_[0]) == 83; }
sub is_array_ref { return (ord ref $_[0]) == 65; }
sub is_hash_ref { return (ord ref $_[0]) == 72; }
sub is_code_ref { return (ord ref $_[0]) == 67; }
sub is_ref_ref { return ((ord ref $_[0]) == 82) && (!is_regexp($_[0])); }
sub is_regexp_ref { return ((ord ref $_[0]) == 82) && (is_regexp($_[0])); }
sub is_blessed_ref { return (blessed $_[0]); }
sub is_object_ref { return (blessed $_[0]); }
sub is_class_ref { return (blessed $_[0]); }

sub is_string { return ((defined $_[0]) && (!ref $_[0]) && (!looks_like_number $_[0])); }
sub is_numeric { return ((defined $_[0]) && (!ref $_[0]) && looks_like_number($_[0])); }

use constant {
  THOUSAND => 1000,
  MILLION => 1000000,
  BILLION => 1000000000,
  TRILLION => 1000000000000,
  QUADRILLION => 1000000000000000,
  KB => 1024,
  MB => 1024*1024,
  GB => 1024*1024*1024,
  TB => 1024*1024*1024*1024,
  EB => 1024*1024*1024*1024*1024,
};

sub bit($$) { return ($_[0] >> $_[1]) & 1; }
sub bitmask($) { return ($_[0] >= 64) ? (~0) : ((1 << $_[0]) - 1); }
sub shifted_bitmask($$) { return (bitmask($_[1]) << ($_[0])); }
sub bits($$$) { return (($_[0] >> $_[1]) & bitmask($_[2])); }
sub lowbits($$) { return ($_[0] & bitmask($_[1])); }

sub extractbits {
  my $v = shift;
  my $out = 0;
  while (my ($bitoffs, $bitwidth) = each @_) 
    { $out = ($out << $bitwidth) | bits($v, $bitoffs, $bitwidth); }
  return $out;
}

# sub splitbits {
#   my $v = shift;
#   my @out = ( );
#   while (my ($bitoffs, $bitwidth) = each @_) { }
#     { push @out, ($v, $bitoffs, $bitwidth); } 
#   return @out;
# }
#
# sub joinbits {
#   my $out = 0;
#   while (my ($bitwidth, $value) = each @_) 
#     { $out = ($out << $bitwidth) | lowbits($value, $bitwidth); }
#   return $out;
# }

#
# Numerical convenience functions
#

sub min($$;@) {
  return (($_[0] < $_[1]) ? $_[0] : $_[1]);
}

sub set_min($$) {
  return $_[0] if (!defined $_[1]);
  my $v = (($_[0] < $_[1]) ? $_[0] : $_[1]);
  $_[0] = $v;
  return $v;
}

sub min_in_list {
  if (!(scalar @_)) { return 0; }
  my $list = (is_array_ref($_[0])) ? $_[0] : @_;
  my $min = undef;
  foreach my $v (@$list) {
    next if (!defined $v);
    $min = ($v <= ($min // $v)) ? $v : $min;
  }
  return $min;
}

sub max($$) {
  return (($_[0] > $_[1]) ? $_[0] : $_[1]);
}

sub set_max($$) {
  return $_[0] if (!defined $_[1]);
  my $v = (($_[0] > $_[1]) ? $_[0] : $_[1]);
  $_[0] = $v;
  return $v;
}

sub max_in_list {
  if (!(scalar @_)) { return 0; }
  my $list = (is_array_ref($_[0])) ? $_[0] : @_;
  my $max = 0;
  foreach my $v (@$list) {
    next if (!defined $v);
    $max = ($v > $max) ? $v : $max;
  }
  return $max;
}

sub inrange($$$) { return (($_[0] >= $_[1]) && ($_[0] <= $_[2])) ? 1 : 0; }

sub clipto($$$) {
  return ($_[0] < $_[1]) ? $_[1] : ($_[0] > $_[2]) ? $_[2] : $_[0];
}

sub set_clipto($$$) {
  $_[0] = ($_[0] < $_[1]) ? $_[1] : ($_[0] > $_[2]) ? $_[2] : $_[0];
  return $_[0];
}

no integer;
use constant {
  RATIO_9_10 => 0.90,
  RATIO_3_4 => 0.75,
  RATIO_2_3 => 2.0 / 3.0,
  RATIO_1_2 => 0.5,
  RATIO_1_3 => 1.0 / 3.0,
  RATIO_1_4 => 0.25,
  RATIO_1_10 => 0.10,
};
use integer;

sub ratio_to_percent($$) {
no integer;
  my ($a, $b) = @_;
  $a //= 0; $b //= 0;
  return ($b > 0) ? int((($a / $b) * 100.0) + 0.5) : 0;
use integer;
}

#
# Utility functions which consider both defined-vs-undef
# state of the argument, and iff it's defined, they'll
# only return true if the argument (taken as a string)
# is filled in (i.e. it has a non-zero length). Obviously
# is_empty() returns the exact opposite of is_filled().
#
# There are also all_filled() and any_empty() to check
# these properties for every item in the specified list.
#
sub is_there($) { return ((defined $_[0]) && ((length $_[0]) > 0)) ? 1 : 0; }
sub is_filled($) { return ((defined $_[0]) && ((length $_[0]) > 0)) ? 1 : 0; }
sub is_empty($) { return ((!(defined $_[0])) || ((length $_[0]) == 0)) ? 1 : 0; }

sub all_defined {
  foreach my $v (@_) { return 0 if (!(defined $v)); }
  return 1;
}

sub any_undefined {
  foreach my $v (@_) { return 1 if (!(defined $v)); }
  return 0;
}

sub all_there {
  foreach my $v (@_) { return 0 if is_empty($v); }
  return 1;
}

sub all_filled {
  foreach my $v (@_) { return 0 if is_empty($v); }
  return 1;
}

sub all_empty {
  foreach my $v (@_) { return 0 if is_there($v); }
  return 1;
}

sub any_there {
  foreach my $v (@_) { return 1 if is_there($v); }
  return 0;
}

sub any_filled {
  foreach my $v (@_) { return 1 if is_there($v); }
  return 0;
}

sub any_empty {
  foreach my $v (@_) { return 1 if is_empty($v); }
  return 0;
}

sub first_specified {
  foreach my $v (@_) { return $v if ((defined $v) && (length $v)); }
  return undef;
}

sub undefs_to {
  my $to = shift;
  my @out = map { $_ // $to } @_;
  return @out;
}

sub undefs_to_inplace {
  my $to = shift;
  foreach my $v (@_) { $v //= $to; };
  return @_;
}

sub undefs_to_empty_strings {
  return map { $_ // '' } @_;
}

sub undefs_to_empty_strings_inplace {
  foreach my $v (@_) { $v //= ''; };
  return @_;
}

sub list_contains(+$) {
  my ($list, $target) = @_;

  my $n = scalar(@$list);
  for (my $i = 0; $i < $n; $i++) {
    if ($list->[$i] eq $_[1]) { return $i; }
  }
  return undef;
}

sub sizeof(+) {
  local $t = typeof($_[0]);
  return
    (!defined $_[0]) ? 0 :
    ($t == ARRAY_REF) ? scalar @{$_[0]} :
    ($t == HASH_REF) ? scalar keys %{$_[0]} :
    ($t == SCALAR_REF) ? length ${$_[0]} :
      length $_[0];
}

#
# Pre-allocate an array or hash of a certain length when we know
# we'll be assigning to indexes up to that length (or for hashes,
# we'll be inserting the specified number of keys).
#
# NOTE: It is NOT safe to use a pre-allocated array for push
# operations, since the next array index written by the push
# will be the preallocated length, rather than the actual
# number of elements pushed so far.
#

sub prealloc(+$;$) {
  my ($array_or_hash, $length_or_fit_to, $filler) = @_;

  my $type = typeof($array_or_hash);
  my $length_type = typeof($length_or_fit_to);

  my $n = 
    ($length_type == ARRAY_REF) ? scalar @$length_or_fit_to :
    ($length_type == HASH_REF) ? scalar keys %$length_or_fit_to :
    $length_or_fit_to;

  if ($type == ARRAY_REF) {
    my $oldlen = scalar(@$array_or_hash);
    $#{$array_or_hash} = $n-1;
    if (defined $filler) {
      for (my $i = $oldlen; $i < $n; $i++) { $array_or_hash->[$i] = $filler; }
    }
  } else {
    keys %$array_or_hash = $n;
  }

  return $array_or_hash;
}

sub sparse_array {
  my @a = ( );

  foreach (pairs @_) {
    my ($index, $value) = @$_;
    $a[$index] = $value;
  }

  return @a;
}

sub single_value_sparse_array {
  my $value = shift;
  my @a = ( );

  foreach my $index (@_) {
    $a[$index] = $value;
  }

  return @a;
}

sub pair_list_with_value(+;$) {
  my ($list, $value) = @_;
  $value //= 1;
  return (map { ($_, $value) } @$list);
}

sub compare_arrays(++) {
  my ($a, $b) = @_;

  my $n = min(scalar(@{$a}), scalar(@{$b}));
  my $i;
  for ($i = 0; $i < $n; $i++) {
    if ($a->[$i] ne $b->[$i]) { last; }
  }
  return $i;
}

sub remove_undefs {
  return (grep { defined } @_);
}

sub remove_undefs_in_place(+) {
  my ($a) = @_;
  @$a = grep { defined } @$a;
}

sub remove_dups(+) {
  my ($a) = @_;
  my %found = ( );
  return (grep { my $inc = (exists $found{$_}) ? 0 : 1; $found{$_} = 1; $inc; } @$a);
}

sub remove_dups_in_place(+) {
  my ($a) = @_;
  @$a = remove_dups($a);
}

sub push_if_defined(+@) {
  my ($a) = shift;
  push @$a, (grep { defined $_ } @_);
  return (scalar @$a);
}

sub copy_array_elements_where_undef(++) {
  my ($a, $b) = @_;

  #
  # Use the larger size as our limit, since perl will fill in 
  # any elements past the end of the smaller array with undefs
  # (if @b is larger than @a, this effectively means all elements
  # in @b at indexes greater than the size of @a will be copied
  # unconditionally into the corresponding indexes in @a).
  #
  my $size = max(scalar(@$a), scalar(@$b));

  my @out = ( );

  for (my $i = 0; $i < $size; $i++) {
    $out[$i] = $a->[$i] // $b->[$i];
  }

  return (wantarray ? @out : \@out);
}

sub pad_array(+;$$) {
  my ($array, $newsize, $pad) = @_;
  
  my $n = scalar(@$array);

  $pad //= (($n > 0) ? $array->[$n-1] : '');

  foreach (my $i = $n; $i < $newsize; $i++) { $array->[$i] = $pad; }

  return (wantarray ? @$array : $array);
}

#
# Partition the specified array into groups of N consecutive elements,
# and return a new array of references to these N-element sub-arrays.
#
sub partition_into_subarrays(+;$) {
  my ($array, $n) = @_;
  $n //= 1;
  my $len = scalar @$array;
  my $chunks = ($len + ($n-1)) / $n;
  my @out = ( );

  foreach (my $i = 0; $i < $len; $i += $n) 
    { push @out, [ @{$array}[$i..($i+($n-1))] ]; }

  return ((wantarray) ? @out : \@out);
}

#
# Partition the specified array into N parallel subarrays, where
# subarray 0 holds input array elements 0, N, 2*N, 3*N, etc.,
# subarray 1 holds input array elements 1, N+1, (2*N)+1, etc.
# and so forth. The subarrays are returned as a list of references
# to those subarrays.
#
sub partition_into_parallel_arrays(+;$) {
  my ($array, $n) = @_;
  $n //= 1;
  my $len = scalar @$array;
  my @out;
  foreach my $i ($n) { $out[$i] = [ ]; }
  my $i = 0;
  foreach $v (@$array) {
    my $a = $out[$i];
    push @{$out[$i]}, $v;
    # avoid modulo operator for better performance:
    $i = ($i + 1); if ($i == $n) { $i = 0; }
  }

  return (wantarray ? @out : \@out);
}

#
# is_constant($name, $package):
# Returns 1 if the symbol $name is a constant in package $package,
# or returns 0 if the symbol doesn't exist or it isn't a constant.
#
# Note: be careful when evaluating what appears to be a constant 
# (but is really a sub) in any security sensitive or privileged
# code that lets an unprivileged user specify a (supposedly) 
# constant symbol's name to look up and evaluate.
#
# $name = symbol name of desired constant
#
# $package = package name (delimited by '::')
#            (if unspecified, "main" is the default package)
#
sub is_constant($;$) {
  my $name = $_[0];
  my $package = $_[1] // caller;

  my $fullname = $package.'::'.$name;
  return (exists $constant::declared{$fullname});
}

sub list_of_constants_in_package(;$) {
  my $package = $_[0] // caller;
  my $stash = $package.'::';
  my @list;

  foreach my $name (keys %$stash) {
    # my $sub = $package->can($name);
    # next unless (defined $sub);
    # my $prototype = prototype($sub);
    # next unless ((defined $prototype) && (!length($prototype)));
    my $fullname = $package.'::'.$name;
    push @list,$name if (exists $constant::declared{$fullname});
  }

  return (wantarray ? @list : \@list);
}

sub hash_of_constants_in_package(;$) {
  my $package = $_[0] // caller;
  my $stash = $package.'::';
  my %hash;

  foreach my $name (keys %$stash) {
    # my $sub = $package->can($name);
    # next unless (defined $sub);
    # my $prototype = prototype($sub);
    # next unless ((defined $prototype) && (!length($prototype)));
    my $fullname = $package.'::'.$name;
    next unless (exists $constant::declared{$fullname});
    #%hash{$name} = $sub->();
  }

  return (wantarray ? %hash : \%hash);
}

#
# topological_sort_dependencies(%key_to_array_of_dep_keys, $from, (optional) \@depths):
#
# Perform a topological sort on the list of all dependencies of $from,
# where the returned array lists all dependencies before the nodes which
# depend on them, obtained through a depth first search of the graph of
# dependencies starting from $from. If a circular dependency is found,
# returns the key of the first node in that dependency loop.
#
# The %name_to_array_of_dep_names hash maps each key to an array of the 
# keys it depends on. The $from argument, keys in %key_to_array_of_dep_keys
# and elements in the arrays of dependencies may be strings, numbers, 
# references or any other scalar data type. If any key or the list of
# dependencies is undefined, it is handled like a node with no dependencies
# and will be ignored. If a ref to the @depths array is provided, this array
# will be filled with integers representing the recursion depth of $from 
# (at depth 0) and each subsequent dependency.
#
# The $found and $out arguments are internally used during recursion only.
#

sub topological_sort_dependencies { # prototype (+$;+$++)
  my ($h, $from, $depths, $depth, $found, $out) = @_;

  $depth //= 0;
  $found //= { };
  $out //= [ ];

  my $deps = $h->{$from} // \@empty_array;
  if (!ref $deps) { $deps = [ $deps ]; };

  foreach my $dep (@$deps) {
    next if (!defined $dep);
    if (exists $found->{$dep}) { return $dep; }
    topological_sort_dependencies($h, $dep, $depths, $depth+1, $found, $out);
  }

done:
  if (defined $depths) { push @$depths, $depth; }
  push @$out,$from;

  return $out;
}

sub masked_store_into_array(+$$) {
  my ($array, $value, $mask) = @_;

  foreach $item (@$array) {
    $item = $value if (($mask & 1) == 1);
    $mask >>= 1;
  }

  return $array;
}

sub compare_vec_to_scalar_and_generate_bitmask(+$) {
  my ($array, $value) = @_;
  my $n = sizeof($array);
  my $b = 0;
no warnings; # it's OK if we compare undef to undef:
  for (my $i = $n-1; $i >= 0; $i--) {
    $b <<= 1;
    $b |= (($array->[$i] == $value) ? 1 : 0);
  }
use warnings;
  return $b;
}

1;
