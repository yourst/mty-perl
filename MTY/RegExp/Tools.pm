#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::Tools
#
# Regular Expression Tools
#
# Copyright 2002 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::RegExp::Tools;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($regexp_chars_re adjust_default_regexp_modifiers condense_regexp
     count_matches finished generate_prefix_or_suffix_regexp
     generate_prefix_regexp generate_suffix_regexp get_cap_group
     get_cap_groups get_capture_group_types_names_contents get_entire_match
     get_match_length get_pattern_if_regexp get_regexp_capture_group_count
     get_regexp_modifiers get_regexp_pattern get_regexp_pattern_and_modifiers
     get_unmatched_remainder is_regexp_or_regexp_ref is_regexp_simple_literal
     matches_regexp_list matches_regexp_list_index
     optimize_all_compiled_regexps optimize_regexp parse_non_overlapping
     rewind simple_regexp_optimizer
     split_comma_delimited_list_with_parenthesized_sublists
     split_into_array_of_arrays_of_captured_groups
     split_into_array_of_hashes_of_captured_groups split_into_array_of_matches
     split_into_hash_of_key_sep_value_delim split_lines_into_keys_and_values
     split_using_prefix_regexp split_using_suffix_regexp
     subst_percent_prefixed_single_chars_using_hash_of_mappings
     valid_cap_group_count);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::RegExp::Define;
use MTY::RegExp::Blocks;
use MTY::Display::PrintableSymbols;
use re qw(is_regexp regexp_pattern regmust regname regnames regnames_count);

#
# Returns true if the argument is a regexp:
#
sub is_regexp_or_regexp_ref {
  my $re = $_[0];
  my $reftype = ref($re) // '';
  if ($reftype eq 'REF') { $re = $$re; }
  return re::is_regexp($re) || ($reftype eq 'Regexp');
}

sub get_regexp_pattern_and_modifiers {
  my $re = $_[0];
  if ((ref($re) // '') eq 'REF') { $re = $$re; }
  if (ref($re) ne 'Regexp') { return ($re, ''); }
  return re::regexp_pattern($re);
}

sub get_regexp_pattern {
  my ($p, $m) = get_regexp_pattern_and_modifiers(@_);
  returnt $p;
}

sub get_regexp_modifiers {
  my ($p, $m) = get_regexp_pattern_and_modifiers(@_);
  returnt $m;
}

#
# Return the number of capture groups (both named and numbered)
# contained within the specified regexp, which may be either a
# string or a qr/.../ pre-compiled regexp:
#
sub get_regexp_capture_group_count($) {
  my $re = $_[0] || die;
  if (ref($re) eq 'REF') { $re = ${$re}; }

  no warnings;
  "" =~ m/(?:$re)|\Z/;
  return $#+;
}

#
# Determine if the specified regexp is guaranteed to be a simple literal,
# or if it is most likely a perl regular expression. 
#
# This function may conservatively return 1 for certain text strings
# even though they could actually be safely matched using simple 
# string comparisons rather than requiring a regexp, since this 
# function uses a simple heuristic that only tests for the presence
# of any special regexp symbols or backslashed characters which may
# also be present in normal text with punctuation like periods (.), 
# question marks (?), symbols like + or *, or backslashed escapes
# like '\\n' (but not true newline characters without backslashes). 
# The full set of regexp indicating characters is itself in the
# $regexp_chars_re regexp.
#
# This conservativeness is functionally harmless but may decrease
# performance in cases where the caller only uses regexp matching
# where this function claims it's required, while using simple
# string comparisons in all other cases.
#
our $regexp_chars_re = compile_regexp(qr{
 (?<! \\) (?: 
   (?: [\\\(\)\[\]\<\>\{\}\.\#\$\^\*\+\|\.\?]) | 
   (?: \\ [123456789AbBCdDEFgGhHkKlLnNpPQRsSuUvVwWXzZ]))}oamsx, 'regexp_chars');

sub is_regexp_simple_literal($;$) {
  my $re = $_[0];
  return ("$re" =~ /$regexp_chars_re/oamsx) ? 1 : 0;
}

#
# Reset the specified string's internal start-of-search offset (pos(<$string>))
# to the beginning of the string. Use this (or equivalently 'pos($x) = 0')
# before starting each new round of matching while using the /g or /c modifiers.
#
sub rewind { pos($_[0]) = 0; }

#
# Return 1 if all characters in the specified string have been successfully 
# matched by one or more regexp matches executed on the string, or 0 if there
# are still characters remaining which could not be matched. You can use
# get_unmatched_remainder($string) to get the unmatchable part of the string.
#
sub finished { (pos($_[0]) // 0) >= length($_[0]); }

sub get_match_length() {
  return (($+[0] // 0) - ($-[0] // 0));
}

sub get_unmatched_remainder($) {
  my $pos = pos($_[0]) // 0;
  my $chars_left = length($_[0]) - $pos;
  if ($chars_left == 0) { return undef; }
  return substr($_[0], $pos, $chars_left);
}

#
# Return the number of capture groups actually filled in by matches so far:
#
sub valid_cap_group_count() { return $#-; }

#
# Return an array (or array ref) of the actual string captured by each
# capture group (whether named or numbered) in the most recent match.
#
sub get_cap_groups($;+) {
  my @array;
  my $arrayref = $_[1] // \@array;
  my $n = $#-;
  $arrayref->[$n-1] = undef;

  for (my $i = 0; $i < $n; $i++) {
    $arrayref->[$i] = (defined($+[$i]) && defined($-[$i])) ?
      substr($_[0], $-[$i], $+[$i] - $-[$i]) : undef;
  }
  
  return (wantarray ? @$arrayref : $arrayref);
}

sub get_cap_group($$) {
  return substr($1, $-[$2], $+[$2] - $-[$2]);
}

sub get_entire_match($) {
  my ($s) = @_;

  return substr($s, $-[0], $+[0] - $-[0]);
}

sub get_capture_group_types_names_contents($) {
  my $re = $_[0];
  if (ref($re) eq 'REF') { $re = ${$re}; }
  $re = qq{$re};

  my $n = 0;
  my @grouplist = ( );

  while (my ($name, $contents) = $re =~ /$regexp_capture_group_re/oamsxg) {
    my $number = $n;
    $name //= '';
    prints('$'.$number.': name ['.$name.'], contents ['.$contents.']'.NL);
    $n++;
    push @grouplist, [ $number, $name, $contents ];
  }
  return (wantarray ? @grouplist : \@grouplist);
}

#
# @array = split_into_array_of_hashes_of_captured_groups($input, $regexp):
# $match_count = split_into_array_of_hashes_of_capture_groups($input, $regexp, \@arrayref):
#
# Constructs a array with one element per match of $regexp in $input,
# where each element is a hash which maps any capture groups
# in $regexp to the captured substrings within the scope of each
# separate match. A hash key is added for each named capture group
# ($+{name} => 'name'), if any capture groups were named. If none
# of the groups were named, an empty hash is added.
#
# If the third argument is a reference to a array, the hashes are
# added to that array, and the array reference is returned.
#
# If only two arguments are provided ($input and $regexp), a new
# array is created, and a reference to it is returned.
#
# $input and/or $regexp may optionally be references to a string
# and a regexp, respectively, but $arrayref (if present) must
# always be a reference to an array.
#
sub split_into_array_of_hashes_of_captured_groups($$;+\$) {
  my $input = (is_scalar_ref($_[0])) ? $_[0] : \$_[0];
  my $regexp = (is_regexp_ref($_[1])) ? $_[1] : \$_[1];

  my @list = ();
  my $arrayref = $_[2] // \@list;

  while ($$input =~ /$$regexp/gc) {
    my %h = %+;
    push @$arrayref, \%h;
  }

  if (defined($_[3])) { ${$_[3]} = get_unmatched_remainder($$input); }
  rewind($$input);

  return (wantarray ? @$arrayref : $arrayref);
}

sub split_into_array_of_arrays_of_captured_groups($$;+\$) {
  my $input = (is_scalar_ref($_[0])) ? $_[0] : \$_[0];
  my $regexp = (is_regexp_ref($_[1])) ? $_[1] : \$_[1];

  my @list = ();
  my $arrayref = $_[2] // \@list;

  while ($$input =~ /$$regexp/gc) {
    my @a = ();
    my $n = scalar(@-);
    for (my $i = 0; $i < $n; $i++) {
      push(@a, substr($$input, $-[$i], $+[$i] - $-[$i]));
    }
    push @$arrayref, \@a;
  }

  if (defined($_[3])) { ${$_[3]} = get_unmatched_remainder($$input); }
  rewind($$input);

  return (wantarray ? @$arrayref : $arrayref);
}

sub split_into_hash_of_key_sep_value_delim($;$$) {
  my %hash = ();
  my $re = $_[1];
  my $default_value = $_[2] // '';

  my $n = 0;
  while ($_[0] =~ /$re/gc) {
    my $key = $1 // ('undef_key_'.($n++));
    my $value = $2 // $default_value;
    $hash{$key} = $value;
  }

  my $remainder = get_unmatched_remainder($_[0]);
  if (is_there($remainder)) { $hash{''} = $remainder; }

  rewind($_[0]);

  return (wantarray ? %hash : \%hash);
}

sub split_into_array_of_matches($$;$+\$) {
  my $input = (is_scalar_ref($_[0])) ? $_[0] : \$_[0];
  my $regexp = (is_regexp_ref($_[1])) ? $_[1] : \$_[1];
  my $capgroup = $_[2] // 0;

  my @array = ();
  my $arrayref = $_[3] // \@array;

  while ($$input =~ /$$regexp/gc) {
    push @$arrayref, substr($$input, $-[$capgroup], $+[$capgroup] - $-[$capgroup]);
  }

  if (defined($_[4])) { ${$_[4]} = get_unmatched_remainder($$input); }
  rewind($$input);

  return (wantarray ? @$arrayref : $arrayref);
}

sub count_matches($$;+) {
  my $n = 0;
  local $REGMARK = undef;
  local $REGEXEC = undef;
  my $histogram = $3;

  rewind($_[0]);

  if (defined($histogram)) {
    while ($_[0] =~ /$_[1]/gc) {
      $n++;
      if (defined($REGMARK)) { $histogram->{$REGMARK}++; }
      $REGMARK = undef;
    }
  } else {
    while ($_[0] =~ /$_[1]/gc) {
      $n++;
    }
  }

  rewind($_[0]);

  return $n;
}

my $key_anysep_value_line_re =
  qr{^ ([^\t\:\=\>\?]+?) \s*+ [\t\:\=\>\?]++ \s*+ (\N*+) \n}oamsx,

my %key_sep_value_line_re_list = (
  ":" => qr/^ ([^\:]+?) \s*+ \: \s*+ (\N*+) \n/oamsx,
  "=" => qr/^ ([^\=]+?) \s*+ \= \s*+ (\N*+) \n/oamsx,
  "\t" => qr/^ ([^\t]+?) \s*+ \t \s*+ (\N*+) \n/oamsx
);

sub split_lines_into_keys_and_values($;$) {
  my %hash = ();

  my $sep = $_[1];
  my $re = (defined($sep)) ? 
    ($key_sep_value_line_re_list{$sep} // qr/^(.+?)\s*+$sep\s*+(\N*+)\n/amsx) :
      $key_anysep_value_line_re;
  
  while ($_[0] =~ /$re/oamsxgc) {
    $hash{$1} = $2;
  }
  
  return (wantarray ? %hash : \%hash);
}

sub matches_regexp_list_index($+) {
  my $list = $_[1];
  for ($i = 0; $i < scalar(@$list); $i++) {
    if ($_[0] =~ $list->[$i]) { return $i; }
  }
  return undef;
}

sub matches_regexp_list($+) {
  my $list = $_[1];
  foreach my $re (@$list) {
    if ($_[0] =~ $re) { return 1; }
  }
  return 0;
}

#
# @list = parse_non_overlapping($input, $regexp):
#
# Unlike the (@list = ($expr =~ /.../g) construct, this
# won't exhaustively recurse and return every possible
# match: it will only return the top level non-overlap
# matches (i.e. what we want for parsing purposes).
#
sub parse_non_overlapping($$) {
  my ($input, $regexp) = @_;

  my @list = ();
  while ($input =~ /$regexp/oamsgc) { push(@list, $1); }
  return @list;
}

sub split_comma_delimited_list_with_parenthesized_sublists {
  return parse_non_overlapping($1, $::comma_delimited_list_with_parenthesized_sublists_re);
}

noexport:; sub generate_prefix_or_suffix_regexp($;$$) {
  my ($is_for_suffix, $sep, $n) = @_;
  $sep //= '.';

  my $s = quotemeta($sep);
  my $not_s = '[^'.$s.']';
  $s = '['.$s.']' if ((length $sep) > 1);
  my $range = (defined $n) ? (($n == 1) ? '' : '{1,'.$n.'}') : '+';

  return (($is_for_suffix) 
    ? ((defined $n) 
       ? qr{((?: $s $not_s *+)$range) $}oax # <= $n suffixes (counted from end)
       : qr{^ $not_s* ($s .*) $}oax) # any and all suffixes
    # for prefixes:
    : qr{^ ($s? (?> $not_s*+ $s)$range+)}oax);
}

sub generate_prefix_regexp { return generate_prefix_or_suffix_regexp(0, @_[0,1]); }
sub generate_suffix_regexp { return generate_prefix_or_suffix_regexp(1, @_[0,1]); }

sub split_using_suffix_regexp($$) {
  my ($text, $re) = @_;
  if ($text =~ /$re/) {
    return (substr($text, 0, $-[1]), $1);
  } else {
    return ($text, '');
  }
}

sub split_using_prefix_regexp($$) {
  my ($text, $re) = @_;
  if ($text =~ /$re/) {
    return ($1, substr($text, $-[1]));
  } else {
    return ('', $text);
  }
}

sub subst_percent_prefixed_single_chars_using_hash_of_mappings($+) {
  my ($s, $h) = @_;

  $s =~ s{(?: \A | [^\\]) \K \%(.)}{$h->{$1} // ('%'.$1)}oamsxge;
  return interpolate_control_chars($s);
}

sub optimize_regexp {
  # use Regexp::Optimizer;
  # return Regexp::Optimizer->new->optimize($_[0]);
  return $_[0];
}

sub optimize_all_compiled_regexps {
  # use Regexp::Optimizer;

  # my @keylist = sort(keys %compiled_regexps);
  # foreach my $regexpname (@keylist) {
  # my $regexp = ${ $compiled_regexps{$regexpname} };
  # my $optimized_regexp = Regexp::Optimizer->new->optimize($regexp);
  # $compiled_regexps{$regexpname} = \$optimized_regexp;
  # }
}

my $redundant_group_modifiers_re = qr{\( \? \^ amsx: ($inside_parens_re) \) }oamsx;
my $group_modifiers_re = qr{\( \? ([adlupimsx\^\-]++) : }oamsx;
my $canonicalize_group_modifiers_re = qr{\( \? \K \^}oamsx;

my $expand_regexp_group_modifiers_re = qr{\( \? (\^?) ([a-z]*) (?> - ([a-z]+))? \:}oamsx;

sub get_pattern_if_regexp($) {
  my ($re) = @_;
  return (is_regexp_ref($re)) ? re::regexp_pattern($re) : $re;
}

sub simple_regexp_optimizer($) {
  my $re = get_pattern_if_regexp($_[0]);
  while ($re =~ s{$redundant_group_modifiers_re}{$1}oamsxg) { };
  return $re;
}

sub adjust_default_regexp_modifiers($$$;$) {
  my ($default, $enabled, $disabled, $for_pcre) = @_;
  $default //= '';
  $enabled //= '';
  $disabled //= '';
#print("adjust_default_regexp_modifiers([$default], [$enabled], [$disabled])\n");
  if ($default eq '^') {
    $enabled .= 'd' unless ($for_pcre);
    $disabled .= 'imsx';
  }

  $enabled =~ tr{adlup}{}d if ($for_pcre);

  if (length $enabled) { $disabled =~ s{[$enabled]}{}ag; }
#print("  => enabled [$enabled], disabled [$disabled]\n");

  $enabled .= '-'.$disabled if (length $disabled);
  return $enabled;
}

sub condense_regexp($;$) {
  my $re = get_pattern_if_regexp($_[0]);
  my $for_pcre = $_[1] // 1;
  # remove comments:
  $re =~ s{(?<! \\) \# \N*+ \n}{}oamsxg;
  # remove whitespace (unless escaped):
  $re =~ s{(?<! \\) \s++}{}oamsxg;
  # collapse redundant groups:
#  $re =~ s{$canonicalize_group_modifiers_re}{d-imsx}oamsxg;
#print("adjusting: $re\n");
  $re =~ s{$expand_regexp_group_modifiers_re}{'(?'.adjust_default_regexp_modifiers($1, $2, $3, $for_pcre).':'}oamsxge;
#  while ($re =~ s{$redundant_group_modifiers_re}{$1}oamsxg) { };
  return $re;
}

#print(STDOUT $perl_package_dependencies_re);
#print(STDOUT $perl_package_dependencies_re);
#print(STDOUT NL."-------------------".NL);
#print(STDOUT simple_regexp_optimizer($perl_package_dependencies_re));
#exit(255);

1;
