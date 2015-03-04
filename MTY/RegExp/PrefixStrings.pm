#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::PrefixStrings
#
# Generate regular expressions to match prefix strings, 
# and perform substitutions and matches using these regexps
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::RegExp::PrefixStrings;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(subst_prefix_strings prepare_prefix_string_subst_regexp
     subst_prefix_strings_and_return_parts);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::Strings;
#pragma end_of_includes
# use Regexp::Optimizer;

sub prepare_prefix_string_subst_regexp {
  my $list = &array_args;
  my $re = '\A('.generate_regexp_to_match_any_string_in_list($list).')';
  $re = qr{$re}oamsx;

#  use Regexp::Optimizer;
#  my $optimizer = Regexp::Optimizer->new;
#  $re = '\A('.$optimizer->optimize($re).')';
#  $re = qr{$re}oamsx;

  return $re;
}

sub subst_prefix_strings_and_return_parts($+;$) {
  my ($prefix_strings_to_replacements, $re) = @_[1,2];

  $before_replacement //= '';
  $after_replacement //= '';
  $re //= prepare_prefix_string_subst_regexp($prefix_strings_to_replacements);
  if ($_[0] =~ /$re/oamsx) {
    my $prefix = $1;
    my $prefix_length = $+[0] - $-[0];
    my $replacement = $prefix_strings_to_replacements->{$prefix} // '<unknown>';
    return ($replacement, substr($_[0], $prefix_length, length($_[0])-$prefix_length));
  } else {
    return (undef, $_[0]);
  }
}

sub subst_prefix_strings($+$;$$) {
  my ($replacement, $remainder) = subst_prefix_strings_and_return_parts($_[0], $_[1], $_[2]);

  if (!defined $replacement) { return $_[0]; }
  return ($_[3] // '').$replacement.($_[4] // '').$remainder;
}

1;
