#!/ usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::PerlSourceTools
#
# Perl 5.x source code processing tools
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::PerlSourceTools;

use integer; use warnings; use Exporter qw(import);

use MTY::Common::Common;
use MTY::Common::Misc;
use MTY::RegExp::PerlSyntax;
use MTY::RegExp::Define;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
use MTY::Display::Colorize;
use MTY::Display::PrintableSymbols;
#pragma end_of_includes

preserve:; nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(EXTRACT_PERL_SUB_CODE EXTRACT_PERL_SUB_LINE_NUMBERS
     EXTRACT_PERL_SUB_COMMENTS_AND_POD_DOCS EXTRACT_PERL_SUB_ARG_NAMES
     EXTRACT_PERL_SUB_RETURN_TYPES EXTRACT_PERL_SUB_INCLUDING_ANONYMOUS_SUBS
     format_perl_package_name tokenize_perl_source 
     tokenize_perl_source_into_tokens_and_types format_perl_module_source
     parse_perl_source_and_extract_subs remove_perl_subs);

sub format_perl_package_name($;$$$) {
  my ($name, $color, $leading_namespaces_color, $separator) = @_;
  $color //= Y;
  $leading_namespaces_color //= $color;
  
  $separator //= scale_rgb_fg($leading_namespaces_color, RATIO_2_3).double_colon;

  return '' if (is_empty $name);

  my @namespaces = split $perl_package_namespace_separator_re, $name;
  my $final = pop @namespaces;
  
  return join('', (map { $leading_namespaces_color.$_.$separator } @namespaces)).$color.$final;
}

#
# Returns the enclosing parent namespace one level above the specified module,
# i.e. "A::B::C::D" returns A::B::C, or only "A" returns "".
#
sub parent_package_name($) {
  my ($package) = @_;
  if (!defined $package) { return ''; }

  my $removed_level = ($package =~ s{:: \w++ \Z}{}oax);
  return ($removed_level) ? $package : '';
}

my $return_statement_re = 
  qr{\b return \s*+ \(? ($inside_parens_re) \)? \s*+ \;? \s*+}oamsx;

my $implied_return_re =
  qr{(?> \A | (?<= [\;\{])) \s*+
     \(? ($inside_parens_re) \)? \s*+ \;? \s*+
     (?> \} | \Z)
  }oamsx;

my $perl_identifier_with_refs_sigil_and_name_re = 
  qr{(\\*+) ([\$\@\%\&\*]) \{? (\w++) \}?}oax;

my $returned_item_re =
  qr{/\A \s*+ ((?|
       (?> $perl_identifier_with_refs_sigil_and_name_re (*:IDENT)) |
       (?> $perl_quoted_string_re (*:STRING_LITERAL)) |
       (?> $numeric_literal_nocap_re (*:NUMERIC_LITERAL)) |
       (?> [A-Za-z_]\w++ (*:FUNCTION_CONST_OR_BAREWORD))
   ))}oamsx;

my $perl_subs_ignore_non_code_except_sub_comments_re = 
  qr{(?|
       (?> $perl_comments_above_sub_re) |
       (?> ( ) (?> $strip_non_functional_perl_syntax_re)) |
       $perl_package_decl_re |
       $perl_sub_decl_and_body_re
     )}oamsx;

my $perl_subs_ignore_non_code_re = 
  qr{(?|
       (?> ( ) (?> $strip_non_functional_perl_syntax_re)) |
       $perl_package_decl_re |
       $perl_sub_decl_and_body_re
     )}oamsx;

noexport:; sub deduce_sub_return_type($$+$) {
  my ($name, $proto, $attrs, $body) = @_;
  $body =~ s{$strip_non_functional_perl_syntax_re}{}oamsxg;

  my %seen_return_prototypes = ( );

  my @return_contents = ( );
  while ($body =~ /$return_statement_re/oamsxg) { push @return_contents, $1; }

  if (!@return_contents) {
    my ($last_statement) = ($body =~ /$implied_return_re/oamsx);
    push @return_contents, $last_statement if (is_there $last_statement);
  }

  foreach my $contents (@return_contents) {
    my @returned_items = split_comma_delimited_list_with_parenthesized_sublists($contents);

    my $return_prototype = join(' ', map { 
      $REGMARK = undef;
      my ($item, $refs, $sigil, $ident, $string) = ($_ =~ /$returned_item_re/oamsx);
      ((!defined $REGMARK) ? '?' :
       ($REGMARK eq 'IDENT') ? ($refs.$sigil) :
       ($REGMARK eq 'STRING_LITERAL') ? '""' :
       ($REGMARK eq 'NUMERIC_LITERAL') ? '#' :
       ($REGMARK eq 'FUNCTION_CONST_OR_BAREWORD') ? '*' : '?');
    } @returned_items);

    if ((scalar @returned_items) > 1) { $return_prototype = '('.$return_prototype.')'; }
    $seen_return_prototypes{$return_prototype} = [ @returned_items ];
  }

  my @unique_protos = sort keys %seen_return_prototypes;

  return @unique_protos;
}

#
# Returns an array of sigil-prefixed variable identifiers corresponding to each
# named argument declared within the specified subroutine body. The array entry
# at index i is either a sigil-prefixed variable name or undef if no name was
# found for argument number i. 
#
# (This is a wrapper around the $perl_sub_argument_names_re regexp above).
#
noexport:; sub get_sub_argument_names($) {
  my ($body) = @_;
  my @arg_index_to_name = ( );

  my $found_arg_to_name_mappings = 0;

  while ($body =~ /$perl_sub_argument_names_re/oamsxg) {
    my ($names, $args) = ($1, $2);

    my @to_names = split(/\s*+ , \s*+/oamsx, $names);
    $found_arg_to_name_mappings += scalar(@to_names);
    my @from_args = split(/\s*+ , \s*+/oamsx, $args);
    my $from_all_args = ((scalar @from_args == 1) && ($from_args[0] eq '@_'));
    my $from_arg_index = 0;

    my @from_arg_indices = ( );
    if ((scalar @from_args == 1) && ($from_args[0] eq '@_')) {
      push @from_arg_indices, (0 .. $#to_names);
    } else {
      foreach my $arg (@from_args) {
        my ($start_index, $end_index) = split(/\s*+ \. \. \s*+/oamsx, $arg);
        $end_index //= $start_index;
        push @from_arg_indices, ($start_index .. $end_index);
      }
    }

    for my $i (0..$#to_names) {
      my $index = $from_arg_indices[$i];
      $arg_index_to_name[$index] = $to_names[$i];
    }
  }

  for my $i (0..$#arg_index_to_name) { $arg_index_to_name[$i] //= '$_['.$i.']'; }

  return (($found_arg_to_name_mappings > 0)
            ? (wantarray ? @arg_index_to_name : \@arg_index_to_name)
              : (wantarray ? ( ) : undef));
}

use constant enumbits (
  EXTRACT_PERL_SUB_CODE,
  EXTRACT_PERL_SUB_LINE_NUMBERS,
  EXTRACT_PERL_SUB_COMMENTS_AND_POD_DOCS,
  EXTRACT_PERL_SUB_ARG_NAMES,
  EXTRACT_PERL_SUB_RETURN_TYPES,
  EXTRACT_PERL_SUB_INCLUDING_ANONYMOUS_SUBS
);

use constant EXTRACT_PERL_SUB_ALL_INFO => (
  EXTRACT_PERL_SUB_CODE |
  EXTRACT_PERL_SUB_LINE_NUMBERS |
  EXTRACT_PERL_SUB_COMMENTS_AND_POD_DOCS |
  EXTRACT_PERL_SUB_ARG_NAMES |
  EXTRACT_PERL_SUB_RETURN_TYPES);

sub parse_perl_source_and_extract_subs($;$$) {
  my ($code, $flags, $anonymous_sub_counter_ref) = @_;
  $flags //= EXTRACT_PERL_SUB_ALL_INFO;

  my %comments_above_sub = ( );

  my $subs_in_file = [ ];
  
  my $anonymous_sub_counter = (defined $anonymous_sub_counter_ref)
    ? ${$anonymous_sub_counter_ref} : 0;

  my $line_to_offset_map = ($flags & EXTRACT_PERL_SUB_LINE_NUMBERS)
    ? create_line_offset_map($code) : undef;

  my $package = 'main';   # default until we see a package declaration

  while ($code =~ /$perl_subs_ignore_non_code_except_sub_comments_re/oamsxg) {
    my ($keyword, $name, $proto, $attrs, $body) = ($1, $2, $3, $4 // '', $5 // '');

    next if (!length $keyword);

    if ($keyword =~ /\#/oamsx) {
      my $comments = $keyword; # it just happens to be in that regexp match slot...
      $comments_above_sub{$name} = $comments if ($flags & EXTRACT_PERL_SUB_COMMENTS_AND_POD_DOCS);
      next;
    }

    if ($keyword eq 'package') { $package = $name; next; }

    my $offset = $-[0];

    if (!length $name) {
      next if (!($flags & EXTRACT_PERL_SUB_INCLUDING_ANONYMOUS_SUBS));
      $name = 'anonymous_sub_'.$anonymous_sub_counter++;
    }

    $attrs = [ split(/[\s\:]++/, $attrs) ];

    my ($line, $col) = (defined $line_to_offset_map) 
      ? find_line_containing_offset($code, $offset, $line_to_offset_map) : (undef, undef);

    my $return_types = ($flags & EXTRACT_PERL_SUB_RETURN_TYPES)
      ? [ deduce_sub_return_type($name, $proto, $attrs, $body) ] : undef;

    my $arg_names = ($flags & EXTRACT_PERL_SUB_ARG_NAMES) 
      ? get_sub_argument_names($body) : undef;

    my $comments = ($flags & EXTRACT_PERL_SUB_COMMENTS_AND_POD_DOCS)
      ? $comments_above_sub{$name} : undef;

    my $info = {
      name => $name, 
      proto => $proto,
      attrs => $attrs, 
      returns => $return_types, 
      args => $arg_names, 
      code => $body, 
      comments => $comments,
      package => $package, 
      filename => $filename, 
      offset => $offset, 
      line => $line // 0, 
      column => $col // 0
    };

    push @$subs_in_file, $info;
  }

  if (defined $anonymous_sub_counter_ref) { ${$anonymous_sub_counter_ref} = $anonymous_sub_counter; }

  return (wantarray ? @$subs_in_file : $subs_in_file);
}

sub remove_perl_subs {
  my $code = shift;
  my $sub_names = &array_args;

  my $include_comments_above_subs = 1;

  return $code =~ s{($perl_subs_ignore_non_code_except_sub_comments_re)}{
    my ($match, $keyword, $name) = ($1, $2, $3);
    my $keep = 
      (!length $keyword) || # pass through all comments, strings, etc.
        ($keyword eq 'package');   # pass through package declarations
    
    my $remove_sub =
      ($keyword eq 'sub') && (length $name) && exists $sub_names->{$name};
    
    my $remove_sub_comment =
      $include_comments_above_subs && ($keyword =~ /\#/oamsx) && 
        (length $name) && exists $sub_names->{$name};
    
    ((!$keep) && ($remove_sub || $remove_sub_comment)) ? '' : $match;
  }roamsxge;
}

my $perl_syntax_highlighting_re = 
  qr{((?|
       (?> $perl_comment_re (*:COMMENT)) | 
       (?> $perl_end_block_re (*:END)) |
       (?> $perl_here_doc_re (*:HEREDOC)) |
       (?> $perl_pod_doc_re (*:POD)) |
       (?> $perl_operators_re (*:OPERATOR)) |
       (?> $perl_keywords_re (*:KEYWORD)) |
       (?> $perl_var_identifier_re (*:VAR)) |
       (?> $perl_identifier_re (*:IDENT)) |
       (?> $perl_string_re (*:STRING)) |
       (?> $numeric_literal_nocap_re (*:NUMBER)) |
       (?> $perl_structural_re (*:STRUCTURAL)) |
       (?> \s++ (*:SPACE)) |
       (?: .+? (*:OTHER))
     ))
  }oamsx;

my %perl_syntax_highlighting_colors = (
  COMMENT => fg_color_rgb(176, 152, 240),
  END => fg_color_rgb(240, 176, 152),
  HEREDOC => fg_color_rgb(128, 192, 255),
  POD => fg_color_rgb(176, 152, 240),
  KEYWORD => fg_color_rgb(255, 255, 255),
  OPERATOR => fg_color_rgb(255, 255, 255),
  VAR => fg_color_rgb(64, 255, 128),
  IDENT => fg_color_rgb(255, 255, 128),
  STRING => fg_color_rgb(128, 192, 255),
  NUMBER => fg_color_rgb(255, 180, 224),
  STRUCTURAL => fg_color_rgb(180, 180, 180),
  SPACE => fg_color_rgb(0, 0, 0),
  OTHER => fg_color_rgb(192, 192, 192),
);

#-----------------------------------------------------------------------------
# print_perl_module_source($code):
#
# Print the specified perl code with colorized syntax highlighting
#-----------------------------------------------------------------------------
sub tokenize_perl_source($) {
  my ($code) = @_;
  local $REGMARK = undef;
  my @out = ( );
  while ($code =~ /$perl_syntax_highlighting_re/oamsxg) { push @out, $1; }
  return @out;
}

sub tokenize_perl_source_into_tokens_and_types($) {
  my ($code) = @_;
  local $REGMARK = undef;
  my @out = ( );
  while ($code =~ /$perl_syntax_highlighting_re/oamsxg) { push @out, ($1, $REGMARK); }
  return @out;
}

sub format_perl_module_source($;+$) {
  my ($code, $colormap, $show_token_boundaries) = @_;
  $colormap //= \%perl_syntax_highlighting_colors;
  $show_token_boundaries //= 0;
  # local $outfd = open_scrollable_stream() // STDOUT;
  # printfd($outfd, $_[0]);
  # close($outfd);
  # return 0;

  my @tokens_and_types = tokenize_perl_source_into_tokens_and_types($code);

  my $pod_chunk = undef;
  my $pod_chunk_tab_label = undef;

  my $out = '';
  my $scalar_color = $colormap->{VAR};
  my %sigil_colors = ('$' => G_3_4, '%' => M_3_4, '@' => Y_3_4, '&' => R_3_4, '*' => B_3_4);
  my %type_colors = ('$' => G, '%' => M, '@' => Y, '&' => R, '*' => B);

  my $next_token_color_override = undef;

  my @out = pairmap {
    if ($b eq 'SPACE') { return $a; }
    my $color_override = $next_token_color_override // '';
    my $color = $colormap->{$b // 'OTHER'}.$color_override;
    $next_token_color_override = (($b eq 'KEYWORD') && ($a eq 'sub' || $a eq 'our')) 
      ? U : undef;
    my $out = ((($b eq 'VAR') && ($a =~ /\A([\$\@\%\&\*])(.+)\Z/oax)) 
      ? ($sigil_colors{$1}.$1.$type_colors{$1}.$color_override.$2) 
        : ($color.($a =~ s{\n}{\n$color}roamsxg)));
    if ($color_override eq U) { $out .= UX; }
    $out;
  } @tokens_and_types;

  my $sep = ($show_token_boundaries) ? dashed_vert_bar_4_dashes : '';
  return (wantarray ? @out : join($sep, @out));
}

1;
