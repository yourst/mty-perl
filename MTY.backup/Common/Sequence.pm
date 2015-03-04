#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::Sequence
#
# Generates a sequence of consecutive outputs each time the next()
# method is called, where the results are provided by iterating 
# through the specified array, then either repeating it from the
# start or repeating the last element indefinitely. This class
# also supports auto-incremented outputs and range compression.
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

sub switch($&) {
  my ($arg, $func) = @_;
}

do { print("OK!"); };
switch 123, do { print("ABC") };

__END__
package MTY::Common::Sequence;

use integer; use warnings; use Exporter qw(import);

use MTY::Common::Common;
#pragma end_of_includes

preserve:; our @EXPORT = qw( );

use constant enum (
  SEQ_LITERAL,
  SEQ_ADD,
  SEQ_MULTIPLY,
  SEQ_APPEND,
  SEQ_GOTO,
  SEQ_CALL_SEQ,
  SEQ_CALL_FUNC,
  SEQ_RETURN,

  SEQ_END_RETURN_UNDEF.
  SEQ_END_REPEAT_FROM_START,
  SEQ_END_REPEAT_LAST,
);

my @final_ops = (
  [ SEQ_RETURN, 0, undef ],  # SEQ_END_RETURN_UNDEF
  [ SEQ_GOTO,   0, 0     ],  # SEQ_END_REPEAT_FROM_START
  [ SEQ_GOTO,   0, -1,   ],  # SEQ_END_REPEAT_LAST
);

sub new(+;$$) {
  my ($class, $pattern, $repeat_mode, $start) = @_;
  $repeat_mode = SEQ_END_REPEAT_FROM_START;
  $start //= 0;

  my $final_op = $final_ops[$repeat_mode];
  if (!defined $final_op) { die("Invalid repeat mode ($repeat_mode)"); }

  $pattern = [
    (map {
      if (is_array_ref $_) {
        my ($action, $reps, $literal) = @$_;
        [ $action, ($reps // 1), ($literal // +1) ];
      } else {
        [ SEQ_LITERAL, 1, $_ ];
      }
    } ((is_array_ref $pattern) ? @$pattern : ($pattern))),
    $final_op,
  ];

  # my ($pattern, $index, $op, $value, $reps) = @$this;
  my $this = [ $pattern, $start, $pattern->[$start], 0, 1 ];

  return bless $this, $class;
}

sub switch {
sub next(+) :method {
  my ($this) = @_;

  alias my ($pattern, $index, $op, $value, $reps) = @$this;

  my ($action, $reps, $literal) = @$op;

  switch ($action),
    case {
  if ($action == SEQ_INCREMENT_)
      $reps //= 1;
      $_
      if ($action == SEQ_INCREMENT) {
      } elsif ($action == SEQ_MULTIPLY) {
        $out = $out * $value;
      } elsif ($action == SEQ_APPEND) {

      }


  $capacity //= (1 << 31); # i.e ~2 billion entries

  my $hash = { };
  my $this = [ $hash, $generator, $label, $capacity, undef, undef, 0, 0, 0 ];

}

sub parent($;$) {
  my ($this, $new_parent) = @_;

  return $this->[parent_ref] if (!defined $new_parent);

  $this->[parent_ref] = $new_parent;
  return $new_parent;
}

sub set_generator(+&) {
  my ($this, $generator) = @_;
  $this->[generator] = $generator;
  return $generator;
}

sub get_stats(+) {
  my ($this) = @_;
  my $hash = $this->[hash];
  return @{$_[0]}[hits, misses, flushes, scalar keys %$hash];
}

method:; sub disable_for_keys(++) {
  my ($this, $bypass) = @_;
  $bypass //= 1;

  $this->{bypass} = $bypass;
}

sub disable(+) {
  my ($this) = @_;
  $this->{bypass} = 1;
}

sub enable(+) {
  my ($this) = @_;
  $this->{bypass} = undef;
}

sub get_using(+$;$@) {
  my ($this, $key, $generator, @args) = @_;
  my $cache = $this->[hash];
  my $bypass = $this->[bypass];

  my $genobj = $this->[parent_ref] // $this;

  if (defined $bypass) {
    if ((is_hash_ref $bypass) ? (exists $bypass->{$key}) : $bypass) {
      return $generator->($genobj, $key, @args);
    }
  }

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
  my $v = $generator->($genobj, $key, @args);
  $cache->{$key} = $v;

  return (wantarray ? ($v, 0, \($cache->{$key})) : $v);
}

sub get(+$;@) { 
  my ($this, $key, @args) = @_;
  return $this->get_using($key, $this->[generator], @args);
}

sub probe(+$;@) { 
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

sub put(+$;$) {
  my ($this, $key, $value) = @_;
  my $h = $this->[hash];
  return undef if (!defined $key);
  my $existed = (exists $h->{$key});
  $this->[hash]->{$key} = $value;
  return $existed;
}

sub invalidate(+;$) {
  my ($this, $key) = @_;
  my $cache = $this->[hash];
  return undef if (!defined $key);

  my $existed = (exists $cache->{$key}) ? 1 : 0;
  delete $cache->{$key} if ($existed);
  $this->[flushes] += $existed;
  return $existed;
}

sub trim(+;$) {
  my ($this, $new_capacity) = @_;
  my $cache = $this->[hash];

  my $current_size = sizeof $cache;
  my $delta = $current_size - $new_capacity;
  return $delta if ($current_size <= $new_capacity);

  my @keys_to_evict = (keys %$cache)[$delta];
  foreach my $key (@keys_to_evict) { delete $cache->{$key}; }
  $this->[flushes] += $delta;
  $this->[capacity] = $new_capacity;
  return $delta;
}

sub flush(+) {
  my ($this) = @_;
  my $cache = $this->[hash];

  # flush the entire cache
  my $n = sizeof($cache);
  $this->[flushes] += $n;
  %$cache = ( );
  return $n;
}

sub get_hash(+) {
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
