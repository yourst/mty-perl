#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::Define
#
# Regular Expression Common Definition Functions
#
# Copyright 2002 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::RegExp::Define;

use integer; use warnings; use Exporter::Lite;

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($always_fail_re $regexp_capture_group_re %compiled_regexp_capture_groups
     %compiled_regexp_descriptions %compiled_regexps @compiled_regexp_names
     compile_regexp compile_regexp_ext compile_regexp_list_of_alternatives
     generate_balanced_char_pair_re generate_inside_of_balanced_char_pair_re
     generate_regexp_to_match_any_string_in_list make_regexp_non_capturing
     sort_by_descending_length_then_alphabetical);

#
# Pre-compile common yet complicated regexps:
#
our %compiled_regexps = ();
our %compiled_regexp_descriptions = ();
our %compiled_regexp_capture_groups = ();
our @compiled_regexp_names;

my $compiled_regexp_count = 0;

sub compile_regexp($;$$+) {
  my ($regexp_ref, $name, $description, $capture_groups) = @_;
  # local (*regexp_ref, *name, *description, *capture_groups) = \ (@_);

  $name = $name // ('regexp'.$compiled_regexp_count);
  $compiled_regexps{$name} = $regexp_ref;
  push @compiled_regexp_names,$name;
  $compiled_regexp_descriptions{$name} = $description // '';
  $compiled_regexp_capture_groups{$name} = $capture_groups if (defined($capture_groups));
  $compiled_regexp_count++;
  return ${$regexp_ref};
}

# For more on these functions, see: https://metacpan.org/pod/Regexp::Common
# (Note: as of Perl 5.012's recursion extensions, Regexp::Common is no longer 
# required, since we can do balanced matching of ()/{}/[]/<> natively now).

# For more on these functions, see: https://metacpan.org/pod/Text::Balanced
# This may also be useful in the future (but not in our current version):
#use Text::Balanced qw (extract_delimited extract_bracketed extract_quotelike extract_codeblock extract_variable extract_tagged extract_multiple gen_delimited_pat gen_extract_tagged);

sub generate_balanced_char_pair_re($$) {
  my $left = '\\'.$_[0];
  my $right = '\\'.$_[1];

  return (qr/
  (?>
    ($left                     # Start of block marker '(' must be here so recursion will find it
      (?>
        (?> [^$left$right]++) |    # anything other than (...), or:
        (?-1)               # recurse to containing (i.e. top level) capture group
      )*+      
    $right)                     # End of block marker ')'
  )/amsx);  
}

sub generate_inside_of_balanced_char_pair_re($$) {
  my $left = '\\'.$_[0];
  my $right = '\\'.$_[1];

  return (qr/
  (?> 
    [^$left$right] | 
    (
      $left                      # Start of block marker '(' must be here so recursion will find it
      (?>
        (?> [^$left$right]++) | # anything other than (...), or:
        (?-1)                   # recurse to containing (i.e. top level) capture group
      )*+      
      $right
    )                     # End of block marker ')' 
  )*+
  /amsx);  
}

#
# Change any capture groups (named or numbered) in the specified regexp
# into non-capturing structural groups, which may allow faster matching.
# This may be useful for providing both a capturing version of a regexp 
# and an equivalent matching-only version without rewriting the regexp.
#
our $regexp_capture_group_re = compile_regexp (qr{
  \(
  (?:
    (?: \? ['<] (\w+) ['>]) | # named group (?'name') or (?<name>)
    (?! \?) # anonymous numbered group
  )
  # Contents within the parentheses, with optional nested parens:
  ((?> [^\(\)] | ( \( (?> (?> [^\(\)]++) | (?-1) )*+ \) ) )*+)
  \)
  }oamsx, 'regexp_capture_group', 
  'Capture group (named or numbered) within a perl regular expression',
  \('1' => '(optional) name of capture group, if specified',
    '2' => 'contents of capture group between the parentheses, '.
    'excluding the "?<name>" part, if present)'));

sub make_regexp_non_capturing($) {
  my $re = $_[0];
  if (ref($re) eq 'REF') { $re = ${$re}; }
  $re = qq{$re};
  $re =~ s/$regexp_capture_group_re/(?:$2)/oamsxg;
  return qr/$re/;
}

our $always_fail_re = compile_regexp(qr{(?!)}oax, 'always_fail',
  'Regular expression which never matches anything and always fails '.
  '(this may seem useless, but it can be used as a placeholder when '.
  'user specified parameters only known at runtime prevent all possible '.
  'matches, yet some regexp is still required in cases where the code '.
  'cannot easily just skip attempting to match the regexp.');

sub sort_by_descending_length_then_alphabetical(+) {
  my ($list) = @_;

  return sort {
    my $r = length($b) <=> length($a);
    return ($r) ? $r : ($a cmp $b);
  } @$list;
}

sub generate_regexp_to_match_any_string_in_list(+) {
  my ($listref) = @_;
  if (!scalar @$listref) { return $always_fail_re; }
  my $re = join('|', map { quotemeta($_) } sort_by_descending_length_then_alphabetical($listref));
  return $re;
}

#
# Enhancements and simplifications to Perl regexp syntax
# (many inspired by Perl 6's improvements and proposals):
#
# `...`        => \Q...\E    # quoted literal without clutter of \Q and \E
# ( ... )      => (?: ... )  # groups are non-capturing by default
# (# ...)      => (...)      # automatically numbered capture group
# _            => \s++       # one or more whitespace characters
#

#my $regexp_backticks_to_Q_E_pair_re = qr{\` ((?: [^\`] | \\ \`)*+) \`}oamsx;
#my $regexp_braces_to_paren_q_c_re = qr{\{ ($inside_of_braces_re) \}}oamsx;
#my $regexp_lt_num_a_b_gt_to_braces_re = qr{\<\# ([0-9\,]+) \>}oamsx;

sub compile_regexp_ext($;$$+) {
  my ($regexp_ref, $name, $description, $capture_groups) = @_;
  # local (*regexp_ref, *name, *description, *capture_groups) = \ (@_);

  my $regexp = ${$regexp_ref};

  $name = $name // ('regexp'.$compiled_regexp_count);

  #$regexp =~ s/$regexp_backticks_to_Q_E_pair_re/quotemeta($1)/oamsxge;
  #$regexp =~ s/$regexp_braces_to_paren_q_c_re/(?:$1)/oamsxg;
  #$regexp =~ s/$regexp_lt_num_a_b_gt_to_braces_re/{$1}/oamsxg;

  $compiled_regexps{$name} = \$regexp;
  $compiled_regexp_descriptions{$name} = $description // '';
  $compiled_regexp_capture_groups{$name} = $capture_groups if (defined($capture_groups));
  $compiled_regexp_count++;
  return ${$regexp_ref};
}

sub compile_regexp_list_of_alternatives(+;$$$$+) {
  my ($regexp_list, $prefix, $toplevel_label, $name, $description, $capture_groups) = @_;
  # local (*regexp_list, *prefix, *toplevel_label, *name, *description, *capture_groups) = \ (@_);

  $name //= ('regexp'.$compiled_regexp_count);
  $prefix //= '';

  $topre = $prefix.
    (defined($toplevel_label) 
       ? ((length($toplevel_label) == 0) 
            ? '('       # (numbered group $1)
            : ('(?\''.$toplevel_label.'\''))
       : '(?:');  # non-capturing group

  for (my $i = 0; $i < scalar(@{$regexp_list}); $i++) {
    $topre .= '|' if ($i > 0);
    # set $REGMARK = $i if alternative $i was captured
    $topre .= '(?>'.$regexp_list->[$i].'(*:'.$i.'))';
  }

  $topre .= ')';
  return compile_regexp(\$topre, $name, $description, $capture_groups);
}

1;
