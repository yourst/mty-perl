#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::Cache
#
# Caches the results of previous queries, or if the query key
# was not previously seen, calls a generator function to produce
# the corresponding value and then stores this in the cache. Also
# provides methods for flushing the cache or specific keys.
#
# Copyright 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::Cache;

use integer; use warnings; use Exporter::Lite;

use MTY::Common::Common;
use MTY::Common::Strings qw(NL);
use MTY::Common::Hashes;

preserve:; our @EXPORT = qw(query_hash);

#
# Treats the specified hash as a cache of previously queried
# keys and their values. If the hash contains the specified
# key, its value is returned (even if it is undefined).
#
# Otherwise, the generator function is called (and passed
# the key as its only argument), and its return value is
# inserted into the hash for that key before the value is
# returned (so in effect the caller never knows whether
# or not the cache itself serviced the request, or if 
# the generator had to be invoked to produce a previously
# unknown value for the key).
#

use constant DEBUG_QUERY_AND_UPDATE_CACHE => 0;

noexport: use constant {
  hash        => 0,
  generator   => 1,
  label       => 2,
  capacity    => 3,
  parent_ref  => 4,
  last_key    => 5,
  last_value  => 6,
  hits        => 7,
  misses      => 8,
  flushes     => 9,
  FIELD_COUNT => 10,
};

noexport:; sub new($;&$$) {
  my ($class, $generator, $label, $capacity) = @_;
  $capacity //= (1 << 31); # i.e ~2 billion entries

  my $hash = { };
  my $this = [ $hash, $generator, $label, $capacity, undef, undef, undef, 0, 0, 0 ];

  return bless $this, $class;
}

noexport:; sub parent($;$) {
  my ($this, $new_parent) = @_;

  return $this->[parent_ref] if (!defined $new_parent);

  $this->[parent_ref] = $new_parent;
  return $new_parent;
}

noexport:; sub set_generator(+&) {
  my ($this, $generator) = @_;
  $this->[generator] = $generator;
  return $generator;
}

noexport:; sub get_stats(+) {
  my ($this) = @_;
  my $hash = $this->[hash];
  return @{$_[0]}[hits, misses, flushes, scalar keys %$hash];
}

noexport:; sub get_using(+$;$@) {
  my ($this, $key, $generator, @args) = @_;
  my $cache = $this->[hash];

  if (exists $cache->{$key}) {
    $this->[hits]++;
    return ((wantarray) ? ($cache->{$key}, 1, \($cache->{$key})) : $cache->{$key});
  }

  #
  # The query missed the cache, so invoke the slow path generator
  # and then update the cache with whatever value it returns.
  #

  $this->[misses]++;

  $generator //= $this->[generator];
  
  if (!defined $generator) 
    { die($this.' has no registered generator, and none was specified'); }

  #
  # keep the cache within its capacity bounds:
  #
  # (in the future we should use some LRU approximation or at least
  # some sort of bloom filter like mechanism (even if it's a very
  # small filter e.g. 64 bits) to avoid erratic performance after
  # flushing the entire cache:
  #
  if (scalar(keys %$cache) >= $this->[capacity]) { $this->flush(); }

  #
  # The generator is free to return undef to indicate it's appropriate
  # to cache the mere fact that the object corresponding to the key could
  # not be found (e.g. when doing lookups on a long list of paths, many
  # of which may not even exist).
  #
  my $genobj = $this->[parent_ref] // $this;
  my $v = $generator->($genobj, $key, @args);
  $cache->{$key} = $v;

  return (wantarray ? ($v, 0, \($cache->{$key})) : $v);
}

noexport:; sub get(+$;@) { 
  my ($this, $key, @args) = @_;
  return $this->get_using($key, $this->[generator], @args);
}

noexport:; sub probe(+$;@) { 
  my ($this, $key) = @_;
  my $h = $this->[hash];
  if ((!defined $key) || (!exists $h->{$key})) { return (wantarray ? (undef, 0) : undef); }
  return (wantarray ? ($h->{$key}, 1) : $h->{$key});
}

#
# Explicitly add the specified key to value mapping into the cache,
# without invoking the cache's previously defined generator function.
# This can be useful to initialize the first few entries in certain
# types of newly created caches, or where some commonly known constant
# mappings need to be added to the cache. For instance, in the case
# of a cache that maps user IDs to user names, $cache->put(0, 'root')
# would be a good use of this function, since there is no reason to
# spend time querying the name of the root user, which is always 
# named 'root' and always has a constant uid (its key) of 0.
#
# Returns 1 if the cache already contained a value for the key 
# (this value is then overwritten with the specified value), 
# or returns 0 if the key was not previously cached.
#

noexport:; sub put(+$;$) {
  my ($this, $key, $value) = @_;
  my $h = $this->[hash];
  my $existed = (exists $h->{$key});
  $this->[hash]->{$key} = $value;
  return $existed;
}

noexport:; sub invalidate(+;$) {
  my ($this, $key) = @_;
  my $cache = $this->[hash];

  die if (!defined $key);

  my $existed = (exists $cache->{$key}) ? 1 : 0;
  delete $cache->{$key} if ($existed);
  $this->[flushes] += $existed;
  return $existed;
}

noexport:; sub trim(+;$) {
  my ($this, $new_capacity) = @_;
  my $cache = $this->[hash];

  my $current_size = sizeof $cache;
  my $delta = $current_size - $new_capacity;
  return $delta if ($current_size <= $new_capacity);

  my @keys_to_evict = (keys %$cache)[$delta];
  foreach $key (@keys_to_evict) { delete $cache->{$key}; }
  $this->[flushes] += $delta;
  $this->[capacity] = $new_capacity;
  return $delta;
}

noexport:; sub flush(+) {
  my ($this) = @_;
  my $cache = $this->[hash];

  # flush the entire cache
  my $n = sizeof($cache);
  $this->[flushes] += $n;
  %$cache = ( );
  return $n;
}

noexport:; sub get_hash(+) {
  my ($this) = @_;
  return $this->[hash];
}

#
# Returns a list of the form (value, key_exists_in_hash):
#
# - (value, 1) if the hash contains the key and the value is defined
# - (undef, 1) if the hash contains the key but the value is undefined
# - (undef, 0) if the hash lacks both the key and any value for it
#
# This is useful in situations where a valid key is assigned an undefined
# value to represent a distinct state different from the hash lacking
# that key at all, for instance when using the hash as a cache to map
# previously queried keys to their values, yet the hash should also
# record the lack of any value (if repeatedly querying some outside
# data source only to always receive a negative response is very
# time consuming or otherwise expensive).
#
sub query_hash(+$) {
  local (*hash, *key) = \ (@_);

  my $v = $hash->{$key};
  if (defined $v) { return ($v, 1); }	
  return (undef, ((exists $hash->{$key}) ? 1 : 0));
}

1;
