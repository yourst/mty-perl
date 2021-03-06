# -*- cperl -*-
#
# MTY::MakeAnalyzer::Common
#
# Parse the database of make rules and recipes output of 'make -p' 
# so it can be saved and reloaded to accelerate make's performance
# on complex collections of many makefiles, or analyzed for many
# other useful applications
#
# Copyright 2003-2015 Matt T. Yourst <yourst@yourst.com>. All rights reserved.
#

package MTY::MakeAnalyzer::Common;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($cwd_re $make_rule_re $make_recipe_re $make_comment_re $phony_target_re
     $skip_empty_vars $special_rule_re format_file_path $path_prefixes_re
     %excluded_targets exclude_make_vars %excluded_variables
     @exclude_var_regexps exclude_make_targets include_all_make_vars
     @exclude_target_regexps include_all_make_targets
     subst_path_prefix_strings $make_variable_or_define_re
     print_summary_of_categories $make_variable_name_and_op_re
     $recipe_to_execute_comment_re $path_prefixes_to_replacements
     print_summary_of_make_database format_file_paths_within_string
     exclude_make_vars_matching_regexp exclude_make_targets_matching_regexp
     prepare_path_prefixes_to_replacements
     %known_strings_with_path_prefixes_replaced
     replace_file_path_with_formatted_file_path
     build_excluded_vars_and_targets_compound_regexps);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::PrefixStrings;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;
#pragma end_of_includes

my $slash_re = qr{/}oax;

sub format_file_path($;$) {
  my ($path, $include_quotes) = @_;
  $include_quotes //= 0;  

  # Only format strings that actually look like a path,
  # (i.e. with at least one directory delimited by "/"):
  return $path if ($path !~ /$slash_re/oax);

  my ($dir, $basename, $suffix) = split_path($path);
  $dir //= ''; $basename //= ''; $suffix //= '';
  my $slashrepl = $K.large_right_slash.$B;
  $dir =~ s{$slash_re}{$slashrepl}oamsxg;
  return ($include_quotes ? $K.left_quote : '').
    $B.$dir.$G.$basename.$C.$suffix.
    ($include_quotes ? $K.right_quote : '').$X;
}

my $may_be_fully_qualified_path_re = 
  qr{ \K ( [\w\-\.\:\~\@\%\*\?\;\,]+? / [^\/\"\'\.\s]+ \. [^\/\"\'\s]+ ) }oax;

# Only apply special formatting to strings that
# refer to real existing files and directories:
my %existing_dir_path_cache = ( );

noexport:; sub replace_file_path_with_formatted_file_path($) {
  my ($path) = @_;
  my $dir = directory_of($path);
  my $is_real_dir = query_and_update_cache(%existing_dir_path_cache, $dir, sub { (-e $_[0]) ? 1 : 0; });
  return ($is_real_dir ? format_file_path($path) : $path);
}

sub format_file_paths_within_string($) {
  my ($s) = @_;

  #prints(STDERR '[format_file_paths_within_string ['.$s.'] ]'.NL);
  $s =~ s{$filesystem_path_including_directory_re}{replace_file_path_with_formatted_file_path($1)}oamsxge;
  return $s;
}

our $make_variable_name_and_op_re = compile_regexp(qr{
  ([^\s\:\#]+) \s+
  ((?: [\+\?\:]? \=)?)
  }oax, 'make_variable_name_and_op');

our $make_variable_or_define_re = compile_regexp(qr{
  ^ (?! \#)
  (?|
    (?:
      (define) \s+
      ([^\s\:\#]+)
      (?: \s+ ([\+\?\:]? \=))?
      ()
    ) |
    (?:
      () # (in lieu of "define" to make the capture group numbers line up)
      ([^\s\:\#]+) \s+ 
      ([\+\?\:]? \=) \s*+
      (.*+)
    )
  ) $
  }oax, 'make_variable');

our $make_rule_re = compile_regexp(qr{
  ^ ([^\#\s\:]++) \: \s*+ 
  ([^\|]*+) 
  (?: \| \s* (.+))?+ $
  }oax, 'make_rule');

our $make_comment_re = compile_regexp(qr{^\#\s++(.++)$}oax, 'make_comment');

our $make_recipe_re = compile_regexp(qr{^\t(.++)$}oax, 'make_recipe');

our $recipe_to_execute_comment_re = compile_regexp(qr{
  ^\# \s*+ recipe \s to \s execute \s \( 
  from \s '([^\']+)'(?: , \s line \s (\d+))?
  }oax, 'make_recipe_to_execute_comment');

our $phony_target_re = compile_regexp(qr{^\#\s+Phony}oax, 'phony_target');

#  \# \s+ Phony target
our $special_rule_re = compile_regexp(qr{
  ^\.\w+$
  }oax, 'special_rule');

our $path_prefixes_to_replacements = { };
our $path_prefixes_re = $always_fail_re;
our %known_strings_with_path_prefixes_replaced = ( );

sub prepare_path_prefixes_to_replacements(+) {
  my ($mapping) = @_;


  $path_prefixes_re = prepare_prefix_string_subst_regexp(keys %$mapping);
  $path_prefixes_to_replacements = $mapping;
  %known_strings_with_path_prefixes_replaced = ( );
  
  my $DEBUG = 1;
  if ($DEBUG) {
    my $longest_key = maxlength(keys %$mapping);
    printfd(STDERR, NL.$G.$U.'Mapping of path prefixes to replacements:'.$X.NL.NL);

    foreach my $key (keys %$mapping) {
      my $repl = $path_prefixes_to_replacements->{$key};
      printfd(STDERR, $Y.padstring($key, $longest_key).$K.' => '.$G.$repl.$X.NL);
      my $k = $key;
      die if ($k !~ /$path_prefixes_re/oax);
    }
    printfd(STDERR, NL);
  }

  return $path_prefixes_re;
}

sub subst_path_prefix_strings($;$$) {
  my ($v, $color, $uniqifier) = @_;

  my $key = $v;
  $v .= $uniqifier if (defined $uniqifier);
  my $repl = $known_strings_with_path_prefixes_replaced{$key};
  if (defined $repl) { return $repl; }

  $color //= $X;
  my $remainder;
  ($repl, $remainder) = subst_prefix_strings_and_return_parts
    ($v, $path_prefixes_to_replacements, $path_prefixes_re);

  $repl = ((defined $repl) ? $R.$U.$repl.$UX.$B.'/'.$color : '').
    format_file_path($remainder);

  $known_strings_with_path_prefixes_replaced{$key} = $repl;
  return $repl;
}

our $skip_empty_vars = 0;

our %excluded_variables;
our %excluded_targets;

our @exclude_var_regexps;
our @exclude_target_regexps;

my $excluded_vars_compound_regexp = undef;
my $excluded_targets_compound_regexp = undef;

sub exclude_make_vars {
  if (!scalar(@_)) {
    # Empty list means reset the exclusions to accept everything:
    %excluded_variables = ( );
    @exclude_var_regexps = ( );
    $excluded_vars_compound_regexp = undef;
    return;
  }

  foreach $exclude (@_) { $excluded_variables{$exclude} = 1; }
}

sub exclude_make_targets {
  if (!scalar(@_)) {
    # Empty list means reset the exclusions to accept everything:
    %excluded_targets = ( );
    @exclude_target_regexps = ( );
    $excluded_targets_compound_regexp = undef;
    return;
  }

  foreach $exclude (@_) { $excluded_targets{$exclude} = 1; }
}

sub exclude_make_vars_matching_regexp {
  my $re = $_[0];
  die('Expected regexp for excluded vars') if (!is_regexp_ref($re));
  push @exclude_var_regexps,$re;
}

sub exclude_make_targets_matching_regexp {
  my $re = $_[0];
  die('Expected regexp for excluded targets') if (!is_regexp_ref($re));
  push @exclude_target_regexps,$re;
}

sub include_all_make_vars {
  %excluded_vars = ( );
  @exclude_var_regexps = ( );
  $excluded_vars_compound_regexp = undef;
}

sub include_all_make_targets {
  %excluded_targets = ( );
  @exclude_target_regexps = ( );
  $excluded_targets_compound_regexp = undef;
}

sub build_excluded_vars_and_targets_compound_regexps() {
  $excluded_targets_compound_regexp = 
    compile_regexp_list_of_alternatives(@excluded_target_regexps);
  $excluded_vars_compound_regexp = 
    compile_regexp_list_of_alternatives(@excluded_var_regexps);
}

our $cwd_re;

sub print_summary_of_categories(+$;$) {
  my ($categories, $targets_or_variables, $fd) = @_;


  my $cwd = getcwd();
  $cwd_re = qr{^$cwd/?};

  my $dark_gold_color = fg_color_rgb(128, 128, 0);

  my $is_for_targets = ($targets_or_variables =~ /target/) ? 1 : 0;
  my $c1 = ($is_for_targets) ? $R : $B;
  my $c2 = ($is_for_targets) ? $Y : $C;

  printfd($fd, NL.NL.text_in_a_box(
    $c2.' '.dot_in_circle.' '.$c2.
      expand_with_spacers(uc($targets_or_variables), ' '.$dark_gold_color.star.' '.$c2.' ').
        $c2.' '.dot_in_circle.' '.$X, 0, $c1, 'rounded', undef, 20, 60).NL.NL);

  return if (!defined $categories);

  printfd($fd, $Y.$U.'Summary of categories for '.$targets_or_variables.':'.$X.NL.NL);
  foreach my $category (sort keys %{$categories}) {
    my $tgtlist = $categories->{$category};
    printfd($fd, $K.' '.dot.' '.$Y.padstring($category, 30).
            ' '.$B.'('.scalar(@$tgtlist).')'.$X.NL); 
  }
  printfd($fd, NL.NL);
}

sub print_summary_of_make_database(++;++$) {
  my ($variables, $targets, $variable_categories, $target_categories, $fd) = @_;

  $fd //= STDOUT;
  print_summary_of_targets($targets, $target_categories, $fd);
  print_summary_of_variables($variables, $variable_categories, $fd);
}

1;
