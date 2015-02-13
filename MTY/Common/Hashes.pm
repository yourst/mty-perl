#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::Common
#
# Common miscellaneous useful functions and tools for Perl
# (this module is included by all others in the MTY::...
# namespace, so it only depends on bullt-in perl modules).
#
# Copyright 1997 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::Hashes;

use integer; use warnings; use Exporter qw(import);
use MTY::Common::Common;
#pragma end_of_includes

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(add_missing_arrays_to_hash add_missing_hashes_to_hash
     add_missing_scalars_to_hash aliased_keys_hash append_to_hash_of_arrays
     append_to_hash_of_arrays_or_scalars array_pair_to_hash array_to_hash_keys
     array_to_histogram_hash array_values_to_hash count_keys_matching_list
     hash_contains_all_keys hash_contains_any_of_keys hash_is_missing_all_keys
     hash_sorted_by_keys_as_pair_array hash_sorted_by_values_as_pair_array
     hash_to_array_of_pairs hash_to_scope invert_hash
     invert_hash_dups_to_subarrays key_list_of_hash_sorted_by_values keysof
     merge_hashes merge_hashes_and_collect_conflicts
     merge_hashes_without_empty_strings print_hash print_hash_as_string
     remove_leading_trailing_space_on_hash_and_remove_if_empty slice
     slice_as_hash symbol_name_array_to_hash_with_values
     value_list_of_hash_sorted_by_keys);

sub array_pair_to_hash(++) {
  my ($keys, $values) = @_;

  my %h;
  my $n = scalar(@$values);
  prealloc(%h, $values);

  for (my $i = 0; $i < $n; $i++) { $h{$keys->[$i]} = $values->[$i]; }
  return (wantarray ? %h : \%h);
}

sub array_values_to_hash(+) {
  my ($value_array_ref) = @_;
  my %h = (map { $_ => $value_array_ref->[$_] } keys @$value_array_ref);
  return (wantarray ? %h : \%h);
}

sub array_to_hash_keys(+;$) {
  my ($key_array_ref, $value) = @_;

  $value //= 1;

  # Pre-expand the hash to comfortably fit all the keys:
  my %h = (map { ($_, $value) } @$key_array_ref);
  return (wantarray ? %h : \%h);
}

sub array_to_histogram_hash(+;$) {
  my ($key_array_ref) = @_;

  # Pre-expand the hash to comfortably fit all the keys:
  my %h = ( );
  prealloc(%h, $key_array_ref);

  foreach my $k (@{$key_array_ref}) { 
    next if (!$k);
    $h{$k} = (exists $h{$k}) ? ($h{$k} + 1) : 1; 
  }

  return (wantarray ? %h : \%h);
}

sub hash_to_array_of_pairs(+) {
  my ($hash) = @_;

  my @array = ( );

  while (my ($k, $v) = each %$hash) { push @array, [ $k, $v ]; }

  return (wantarray ? @array : \@array);
}

sub invert_hash(+) {
  my ($hash) = @_;
  
  return (wantarray ? reverse %$hash : { reverse %$hash });
}

sub invert_hash_dups_to_subarrays(+) {
  my ($hash) = @_;

  my %rev = ( );
  prealloc(%rev, scalar keys %$hash);

  while (my ($k, $v) = each %$hash) {
    if (exists $rev{$v}) {
      my $r = $rev{$v};
      if (ref $r) { push @$r, $k; } else { $rev{$v} = [ $r, $k ]; };
    } else {
      $rev{$v} = $k;
    }
  }

  return (wantarray ? %h : \%h);
}

sub merge_hashes(++;$$) {
  my ($target, $source, $add_count_ref, $update_count_ref) = @_;

  my $update_count = 0;
  my $add_count = 0;
  prealloc($target, ((scalar keys %$target) + (scalar keys %$source)));

  while (my ($k, $v) = each %$source) { 
    my $e = exists $target->{$k};
    $update_count += $e;
    $add_count += !$e;
    $target->{$k} = $v; 
  }

  if (defined $add_count_ref) { $$add_count_ref += $add_count; }
  if (defined $update_count_ref) { $$update_count_ref += $update_count; }
  return ($target, $add_count, $update_count);
}

sub merge_hashes_and_collect_conflicts(++;+$) {
  my ($target, $source, $conflicts, $overwrite_if_conflict) = @_;

  $conflicts //= [ ];
  $overwrite_if_conflict = 1;
  prealloc($target, ((scalar keys %$target) + (scalar keys %$source)));

  while (my ($k, $v) = each %$source) { 
    my $e = exists $target->{$k};
    if ($e) { 
      push @$conflicts, $k; 
      if ($overwrite_if_conflict) { $target->{$k} = $v; }
    } else {
      $target->{$k} = $v; 
    }
  }

  return (wantarray ? @$conflicts : $conflicts);
}

sub merge_hashes_without_empty_strings(++) {
  my ($target, $source) = @_;

  my $removed_items = 0;

  while (my ($k, $v) = each %$source) {
    if (is_there($v)) {
      $target->{$k} = $v;
    } else {
      $removed_items++;
    }
  }

  return $removed_items;
}

sub print_hash_as_string(+) {
  my $h = $_[0];
  my $s = '';

  $s .= '%'.$h.' ('.(scalar keys %$h). ' keys) = {'.NL;

  foreach my $k (keys %$h) {
    # skip quotes on hash keys that look like perl identifiers:
    my $q = ($k =~ /^\w+$/oax) ? '' : '\'';
    my $v = $h->{$k} // 'undef';
    $s .= '  '.$q.$k.$q.' => '.$v.','.NL;
  }
  $s .= '}'.NL;
  return $s;
}

sub print_hash(+;$) {
  my $h = $_[0];
  my $fd = $_[1] // STDERR;

  printfd($fd, print_hash_as_string($h));
}

sub symbol_name_array_to_hash_with_values(+) {
  my ($syms) = @_;

  my %h = ( );

  prealloc(%h, $syms);

  foreach my $sym (@$syms) {
    $h{$sym} = eval { $sym };
  }

  return %h;
};

sub key_list_of_hash_sorted_by_values(+) {
  my $h = $_[0];
  return sort {
    my $av = $h->{$a}; 
    my $bv = $h->{$b};
    ((is_string $av) ? ($av cmp $bv) : ($av <=> $bv)) 
  } keys %{$h};
}

sub value_list_of_hash_sorted_by_keys(+) {
  my $h = $_[0];
  return @{$h}{(sort keys %$h)};
}

sub hash_sorted_by_keys_as_pair_array(+) {
  my $h = $_[0];
  return (map { ($_ => $h->{$_}) } (sort keys %$h));
}

sub hash_sorted_by_values_as_pair_array(+) {
  my $h = $_[0];
  return (map { ($_ => $h->{$_}) } 
            (key_list_of_hash_sorted_by_values $h));
}

sub hash_to_scope(+) {
  my $hashref = $_[0];

  while (my ($k, $v) = each %{$_[0]}) { eval { ${$k} = $v; }; }
};

sub add_missing_scalars_to_hash(+$;@) {
  my $h = shift;
  my $v = shift;
  foreach my $key (@_) {
    next if (exists $h->{$key});
    $h->{$key} = $v;
  }
}

sub add_missing_arrays_to_hash(+;@) {
  my $h = shift;
  foreach my $key (@_) {
    next if (exists $h->{$key});
    $h->{$key} = [ ];
  }
}

sub add_missing_hashes_to_hash(+;@) {
  my $h = shift;
  foreach my $key (@_) {
    next if (exists $h->{$key});
    $h->{$key} = { };
  }
}

#
# Append the specified value to the array reference in the hash slot 
# for the specified key. If that key's value was previously undefined,
# a new single element array is created to hold the value and assigned
# by reference to that key's value. If the value already existed but
# was a scalar, upgrade it to an array that now holds both the original
# scalar and the new value. Values may be any data type, and are not
# limited to scalars.
#
sub append_to_hash_of_arrays(+$$) {
  my ($hash, $key, $value) = @_;

  my $a = $hash->{$key};
  if (defined $a) {
    if ((ref $a) ne 'ARRAY') {
      # convert single value (usually a scalar) 
      # into the first entry in a new array:
      $a = [ $a ];
    }

    push @$a, $value;
  } else {
    $a = [ $value ];
    $hash->{$key} = $a;
  }

  return $a;
}

#
# The append_to_hash_of_arrays_or_scalars function is very similar to 
# append_to_hash_of_arrays (see above), but will first add single scalars
# as a scalar value, and will only upgrade the hash slot to an array
# if multiple values are inserted for the same key:
#
sub append_to_hash_of_arrays_or_scalars(+$@) {
  my $hash = shift;
  my $key = shift;

  my $a = $hash->{$key};

  if (defined $a) {
    if (!is_array_ref($a)) {
      # convert single value (usually a scalar) 
      # into the first entry in a new array:
      $a = [ $a ];
    }

    push @$a, @_;
    return $a;
  } else {
    $hash->{$key} = (((scalar @_) > 1) ? [ @_ ] : $_[0]);
    return $value;
  }
}

sub remove_leading_trailing_space_on_hash_and_remove_if_empty(+) {
  my $h = $_[0];

  my $n = 0;
  foreach my $k (keys %{$h}) {
    my $v = \$h->{$k};
    my $l = length($$v);
    if (is_there($v)) {
      $$v =~ s/$leading_spaces_re//oag;
      $$v =~ s/$trailing_spaces_re//oag;
    }
    if (!is_there($$v)) { 
      delete $h->{$k}; 
      $n++;
    }
  }

  return $n;
}

#
# Construct a hash where multiple keys may be aliased to the same value,
# by using the following invocation:
# 
#   my %hash = aliased_keys_hash abc => 123, [qw(def ghi)] => 456, ...
#

sub aliased_keys_hash {
  #++MTY TODO: needs pair iterator
}

sub count_keys_matching_list(+@) {
  my ($hash) = shift;
  
  my $n = 0;
  foreach my $key (@_) {
    $n += (exists $hash->{$key}) ? 1 : 0;
  }

  return $n;
}

sub hash_contains_all_keys(+@) {
  my ($hash) = shift;
  return (count_keys_matching_list($hash, @_) == scalar(@_)) ? 1 : 0;
}

sub hash_is_missing_all_keys(+@) {
  my ($hash) = shift;
  return (count_keys_matching_list($hash, @_) == 0) ? 1 : 0;
}

sub hash_contains_any_of_keys(+@) {
  my ($hash) = shift;
  return (count_keys_matching_list($hash, @_) > 0) ? 1 : 0;
}

sub keysof {
  my ($obj) = $_[0];
  my $type = typeof($obj);

  my @keys =
    (!defined $obj) ? ( ) :
    ($type == ARRAY_REF) ? (keys @$obj) :
    ($type == HASH_REF) ? (keys %$obj) :
    @_;
}

#
# Return a new hash that is a slice of the specified hash
# with only the specified keys and their respective values:
#
sub slice_as_hash(+;@) {
  my ($obj, @keys) = @_;

  @keys = keysof(@keys) if ((scalar @keys) < 2);

  my $type = typeof($obj);

  return
    (!defined $obj) ? { } :
    ($type == ARRAY_REF) ? { %{$obj}[@keys] } :
    ($type == HASH_REF) ? { %{$obj}{@keys} } :
    undef;
}

sub slice(+;@) {
  my ($obj, @keys) = @_;

  @keys = keysof(@keys) if ((scalar @keys) < 2);

  my $type = typeof($obj);

  return
    (!defined $obj) ? ( ) :
    ($type == ARRAY_REF) ? @{$obj}[@keys] :
    ($type == HASH_REF) ? @{$obj}{@keys} :
    ( );
}

1;
