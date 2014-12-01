#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::CxxREs
#
# C++ Parser grammar regexps for relevant portions of the C++ language
# (i.e. class/struct/union definitions, templates, typedefs, operators, etc.)
#
# Copyright 2008-2014 Matt T. Yourst <yourst@yourst.com>. All rights reserved.
#

package MTY::RegExp::CxxREs;

use integer; use warnings; use Exporter::Lite;

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($backslash_newline_re $c_comment_re $c_cxx_comment_re
     $class_struct_union_re $cxx_assignment_operators_except_simple_equals_re
     $cxx_assignment_operators_re $cxx_balanced_structural_chars_re
     $cxx_binary_arith_logic_compare_operators_re $cxx_comment_re
     $cxx_extended_assignment_operators_except_simple_equals_re
     $cxx_extended_assignment_operators_re $cxx_extended_operators_re
     $cxx_identifier_re $cxx_keywords_re $cxx_operators_re $cxx_opt_space_re
     $cxx_preprocessor_define_directive_arguments_re
     $cxx_preprocessor_directive_names_re $cxx_preprocessor_directive_re
     $cxx_preprocessor_include_directive_arguments_re
     $cxx_preprocessor_include_directive_re $cxx_space_re $cxx_token_re
     $cxx_unary_postfix_operators_re $cxx_unary_prefix_operators_re
     $declaration_or_block_re $enum_def_re $field_decl_re
     $function_decl_argument_list_item_re $function_type_name_args_body_re
     $identifier_chars $if_or_ifdef_endif_re
     $inside_if_or_ifdef_optional_else_endif_re
     $line_with_optional_backslash_newlines_re $non_identifier_syms
     $preprocessor_define_re $preprocessor_line_info_re $preprocessor_re
     $ptr_or_ref_re $rvalue_expression_re $standalone_type_spec_nocap_re
     $template_spec_re $template_type_list_re $type_spec_re $typedef_decl_re
     %cxx_assignment_operator_to_name %cxx_keywords %cxx_operator_to_name
     @all_capture_group_names @cxx_keyword_list CXX_TOKEN_COMMENT
     CXX_TOKEN_IDENTIFIER CXX_TOKEN_NUMERIC CXX_TOKEN_OPERATOR
     CXX_TOKEN_PREPROCESSOR CXX_TOKEN_QUOTED CXX_TOKEN_STRUCTURAL
     CXX_TOKEN_WHITESPACE join_backslash_newline_escaped_lines);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::RegExp::Define;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;

#
# ONLY use these if input has been preprocessed to remove redundant whitespace:
#
our $cxx_space_re = '\s';
our $cxx_opt_space_re = '\s?'; # optional whitespace

our $backslash_newline_re = compile_regexp(
  qr{(?<! \\) \\ \n}oamsx, 'backslash_newline',
  'Backslash ("\") followed by a newline character (\n), used to denote the '.
  'continuation of the current logical source line onto the next input line.'.
  'Will not match a double backslash (i.e. a literal backslash, not an escape).');

our $line_with_optional_backslash_newlines_re = compile_regexp(
  qr{((?> [^\n\\] | \\ .)*+) (?> \n | \z)}oamsx,
  'line_with_optional_backslash_newlines',
  'Line of text terminated by a newline (\n) character, optionally including '.
  'a backslash followed by a newline (\\ \n) which continues the same logical '.
  'line, which this regexp captures into $1 (including any embededded \\ \n '.
  'sequences, which should be removed using '.
   '"<var> =~ s{$backslash_newline_re}{}oamsxg"');

sub join_backslash_newline_escaped_lines($) {
  return $_[0] =~ s{$backslash_newline_re}{}roamsxg;
}

our $identifier_chars = 'A-Za-z0-9_\$';
# Remember that '$' is a valid identifier character in C/C++ (and of course in perl :-)
our $non_identifier_syms = '\:\;\,\.\=\+\-\*\/\%\&\|\^\~\!\?\@\#\(\)\{\}\[\]\<\>\'\`\"';

our $cxx_identifier_re = compile_regexp(
  qr{[A-Za-z_\$] [A-Za-z0-9_\$]*+ \b}oamsx, 'cxx_identifier',
  'C++ identifier (starts with a letter, _, or $, optionally followed by '.
  'any number of letters, numbers, _, or $ symbols');

our @cxx_keyword_list =
  ('alignas', 'alignof', 'and', 'and_eq', 'asm', 'auto', 'bitand', 'bitor', 
   'bool', 'break', 'case', 'catch', 'char', 'char16_t', 'char32_t', 'class',
   'compl', 'const', 'const_cast', 'constexpr', 'continue', 'decltype', 
   'default', 'delete', 'do', 'double', 'dynamic_cast', 'else', 'enum', 
   'explicit', 'export', 'extern', 'false', 'final', 'float', 'for', 'friend', 
   'goto', 'if', 'inline', 'int', 'long', 'mutable', 'namespace', 'new', 
   'noexcept', 'not', 'not_eq', 'nullptr', 'operator', 'or', 'or_eq', 
   'override', 'private', 'protected', 'public', 'register', 'reinterpret_cast', 
   'return', 'short', 'signed', 'sizeof', 'static', 'static_assert', 
   'static_cast', 'struct', 'switch', 'template', 'this', 'thread_local', 
   'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned', 
   'using', 'virtual', 'void', 'volatile', 'wchar_t', 'while', 'xor', 'xor_eq');

our %cxx_keywords = array_to_hash_keys(@cxx_keyword_list);

our $cxx_keywords_re = compile_regexp(qr{
  \b (?>
  a(?>lign(?>as|of) | nd(?>_eq)? | sm | uto) |
  b(?>it(?>and|or) | ool | reak) | 
  c(?>ase | atch | har(?>16_t|32_t)? | lass | ompl | onst(?>_cast|expr)? | ontinue) |
  de(?>cltype | fault | lete) | d(?>o(?>uble)?) | dynamic_cast | 
  e(?>lse | num | (?>xp(?>licit|ort)) | xtern) |
  f(?>alse | inal | loat | or | riend) | 
  (?> goto) | i(?>f | n(?>line|t)) | (?> long) | 
  (?> mutable) | n(?>amespace | ew | oexcept | ot(?>_eq)? | ullptr) |
  o(?>perator | r(?>_eq)? | verride) | 
  p(?>rivate | rotected | ublic) | 
  re(?>gister | interpret_cast | turn) | 
  s(?>hort | igned | izeof | tatic(?>_assert|_cast)? | truct | witch) | 
  t(?>emplate | h(?>is | read_local | row) | r(?>ue|y) | ype(?>def|id|name)) |
  un(?>ion|signed) | using | 
  v(?>irtual | oid | olatile) | 
  w(?>char_t | hile) | xor(?>_eq)?) \b}oamsx,
  'cxx_keywords',
  'C++ keywords, in a regexp highly optimized for fast matching');

# (less optimized alternative): our $cxx_keywords_re = compile_regexp_list_of_alternatives(@cxx_keywords, 'cxx_keywords');

#our $rvalue_expression_re = compile_regexp(
#  \qr/(?> [^\(\)\,\;\"\']++ | $parens_re | $quoted_re )+/oamsx,
#  'rvalue_expression', '');


our $rvalue_expression_re = compile_regexp(
 qr{(?> [^\(\)\,\;\"\'] | $parens_re | $quoted_re )++}oamsx,
  'rvalue_expression', '');

our $c_comment_re = compile_regexp(
  qr{
    \Q/*\E
    (?: [^\*] | \* (?! \/))*+
    \Q*/\E
  }oamsx, 
  'c_comment', 'C comment /* ... */');

our $cxx_comment_re = compile_regexp(qr{// [^\n]*+ (?= \n)}oamsx, 
  'cxx_comment', 'C++ comment // ...');

our $c_cxx_comment_re = compile_regexp(qr{
  (?> / (?>
    (?>
      \* (?> [^\*] | \* (?! \/))*+ \* \/
    ) |
    (?> \/ [^\n]*+ (?= \n)) 
  ) )
                                        }oamsx,
  'c_cxx_comment_re', 'C or C++ comments (// ... or /* ... */)');

our $preprocessor_re = compile_regexp
  (qr{^\# (?> (?> \\ \n) | [^\n])*+ (?= \n)}oamsx,
  'preprocessor', 'Preprocessor lines starting with "#"');

our $preprocessor_define_re = compile_regexp
  (qr{^\# \s*+ define [\ \t]++ 
       (\w++)
       (?> \( ([^\(\)]*+) \))? 
       [\ \t]*+ 
       ((?> (?> \\ \n) | [^\n])*+) \n}oamsx,
   'preprocessor', 
   'Preprocessor #define directive with symbol name, '.
   'optional argument list (arg1, arg2, ...) and optional '.
   'value to assign to that symbol (captured as $1, $2, $3, '.
   'respectively.');

our $preprocessor_line_info_re = compile_regexp(
  qr{^ \# (?: line)? \s*+
      (?'line' \d++) \s++
      \" (?'filename' [^\"]*+) \" \s*+
      (?'extra' [^\n]*+)
      \n
  }oamsx, 'preprocessor_line_info', 
  'Preprocessor line info # 123 "filename" extra-numbers');

our $cxx_preprocessor_directive_names_re = compile_regexp(
  qr{(?>
        assert | define |
        e (?> l (?> if | se) | ndif | rror) |
        i (?> dent | f (?> def | ndef)? | mport |
          nclude (?> _next)?) |
        line | pragma | sccs | un (?> assert | def) |
        warning)
      }oax, 'cxx_preprocessor_directive_names',
  'Names of all valid C/C++ standard preprocessor directives '.
  '(i.e. "#directivename ..."). Only for matching (no captures)');

our $cxx_preprocessor_directive_re = compile_regexp(
  qr{^\# [\ \t]*+ ($cxx_preprocessor_directive_names_re) [\ \t]++ 
      $line_with_optional_backslash_newlines_re}oamsx,
  'cxx_preprocessor_directive',
  'C/C++ preprocessor directive line (i.e. "#directive args..."), '.
  'which captures any valid standard directive names into $1 and '.
  'the remainder of the line (or lines, if "\" and newline was used).');

our $cxx_preprocessor_include_directive_arguments_re = compile_regexp(
  qr{([\<\"]?) ([^\>]++) [\>\"]?}oamsx,
  'cxx_preprocessor_include_directive_arguments',
  'Argument to #include directive, of the form "dir/included.h" or '.
  '<dir/included.h>');

our $cxx_preprocessor_include_directive_re = compile_regexp(
  qr{^\# [\ \t]*+ include [\ \t]++ ([\<\"]?) ([^\>]++) [\>\"]?}oamsx,
  'cxx_preprocessor_include_directive',
  'C/C++ preprocessor include directive line, provided as a faster '.
  'alternative to $cxx_preprocessor_directive_re for cases where only '.
  'the included header filenames are needed (but note that this may be '.
  'a superset of what the compiler would really include, since ifdefs '.
  'are not considered and thus cannot suppress some inclusions). Captures '.
  'the same fields as $cxx_preprocessor_include_directive_arguments_re.');

our $cxx_preprocessor_define_directive_arguments_re = compile_regexp(
  qr{^ ([\w\_\$]++) (?> \( ($inside_of_parens_re) \))? \s++ (.++) $}oamsx,
  'cxx_preprocessor_define_directive_arguments',
  'Arguments to #define directive, in the form "#define SYMBOL value" or '.
  '"MACRO(macro_arg1, ...) contents_to_expand"');

#$cxx_binary_arith_logical_operators_re = qr{(?:[\+\-\*\/\%\&\|\^]=?|\&\&|\|\||
#$cxx_arithmetic_logical_assignment_operators_re = qr}(?:(?:[\=\+\-\&\|\<\>]{1,2})|[\*\/\%\^])/oa;

#
# Operators defined by Standard C++ 11
#   == ++ --       && || << >> ::
#   =  +  -  *  /  &  |  <  >     !  ^  %  ~  ,  .
#   += -= *= /= %= &= |= ^= <= >= != 
#   -> ->* .* ?: () []
#   <<= >>= sizeof throw
#   new delete new[] delete[]
#
# (Note that this does't use \Q...\E literals as much as normally possible
# since this breaks emacs cperl highlighting and indenting, but fortunately
# it doesn't affect the performance of the compiled regexp).
# 
our $cxx_operators_re = compile_regexp(qr{
  (?>
    \<\<\= | \>\>\= | \.\.\. |
    \-\>\*? | \.\* | 
    [\=\+\-\*\/\%\&\|\^\<\>\!] \=? |
    (?: ([\+\-\&\|\<\>\:\.\#]) \g{-1}?) |
    [\~\,\?] | \(\) | \[\] |
    (?: \b (?: new|delete) \b (?: \s? \[\])?) |
    (?: \b (?: size|length|offset|align)of \b) | \b throw \b
  )}oamsx, 'cxx_operators', '');

our $cxx_extended_operators_re = compile_regexp(qr{
  (?>
    \<\<[\=\<] | \>\>[\=\>] | \.\.\. | \-\>\*? |
    \.\* | \=\> | 
    (?: (?<= operator \s) (?: \(\) | \[\])) |
    \[\[ | \]\] | [\(\[\]\)] |
    (?>
      ([\=\+\-\&\|\^\<\>\:\.\#\?\%\@\~])
      (?> = | \g{-1})?
    ) |
    (?> [\*\/\!] =?) | [\,\;] |
    (?> \b (?: new|delete) \b (?: \s? \[\])?) |
    (?> \b (?: size|length|offset|align)of \b) | \b throw \b
  )}oamsx, 'cxx_extended_operators', '');

#
# Overloadable C++ operators:
# Nearly the same as $cxx_operators_re, but excludes
# the following non-overloadable operators: . :: .* ?:
#

# ++ --
# +  -  !  ~  &  *  (where & and * are used on pointers)
our $cxx_unary_prefix_operators_re = compile_regexp(qr{
  \+\+ | \-\- | [\+\-\!\~\&\*]   
  }oamsx, 'cxx_unary_prefix_operators');

our $cxx_unary_postfix_operators_re = compile_regexp(qr{
  \+\+ | \-\-          # ++ --
  }oamsx, 'cxx_unary_postfix_operators');

#  <= >= ==
#  &  |  <  >  &&  ||  <<  >>
#  +  -  *  /  %   ^   ,   .  ?  :
our $cxx_binary_arith_logic_compare_operators_re = compile_regexp(qr{
  [\<\>\=]\= |             
  && | \|\| | << | >> | [\&\|\<\>] |
  [\+\-\*\\\/\%\^\,\.\:\?] | 
  \-\>\*?}oamsx, 'cxx_binary_arith_logic_compare_operators'); 

our $cxx_assignment_operators_re = compile_regexp(qr{
  (?>
    \<\<\= | \>\>\= | \+\+ | \-\- |
    (?> [\+\-\*\/\%\&\|\^]?+ \=)
  )}oamsx, 'cxx_assignment_operators', '');

our $cxx_assignment_operators_except_simple_equals_re = compile_regexp(qr{
  (?>
    \<\<\= | \>\>\= | \+\+ | \-\- |
    (?> [\+\-\*\/\%\&\|\^] \=)
  )}oamsx, 'cxx_assignment_operators_except_simple_equals', '');

our $cxx_extended_assignment_operators_re = compile_regexp(qr{
  (?>
    \<\<\= | \>\>\= | \+\+ | \-\- | \=\> |
    (?> [\+\-\*\/\%\&\|\^\:\.\?\@\~]?+ \=)
  )}oamsx, 'cxx_extended_assignment_operators', '');

our $cxx_extended_assignment_operators_except_simple_equals_re = compile_regexp(qr{
  (?:
    \<\<\= | \>\>\= | \+\+ | \-\- | \=\>
    (?> [\+\-\*\/\%\&\|\^\:\.\?\@\~] \=)
  )}oamsx, 'cxx_extended_assignment_operators_except_simple_equals', '');

our %cxx_operator_to_name = (
  '+' => 'add',
  '-' => 'sub',
  '*' => 'mul',
  '/' => 'div',
  '%' => 'mod',
  '&' => 'and',
  '|' => 'or',
  '^' => 'xor',
  '=' => 'assign',
  '==' => 'eq',
  '!=' => 'ne',
  '>' => 'gt',
  '<' => 'lt',
  '>=' => 'ge',
  '<=' => 'le',
  #...todo
  );

our %cxx_assignment_operator_to_name = (
  '=' => 'set',
  '+=' => 'add',
  '-=' => 'sub',
  '*=' => 'mul',
  '/=' => 'div',
  '%=' => 'mod',
  '&=' => 'and',
  '|=' => 'or',
  '^=' => 'xor',
  '<<=' => 'shl',
  '>>=' => 'shr',
  '++' => 'inc',
  '--' => 'dec'
  );

#
# Remove any whitespace which is unnecessary in syntactically correct C/C++ code.
# Specifically, whitespace will only be retained where it:
#
# - separated two word characters (i.e. \w+ $cxx_opt_space_re \w+)
# - separated two operators (e.g. to prevent 'x + +3 from becomming x++3)
# - appeared inside of a string literal ("... words with spaces ...")
#
# In all of these cases (except for string literals), multiple consecutive spaces
# will be condensed into a single space character. Note that this also removes
# intervening newlines, tabs and any and all other unnecessary whitespace.
#
# This dramatically simplifies and accelerates many of our regular expressions,
# which would otherwise have to include countless instances of '$cxx_opt_space' patterns
# to handle cases wher the original code had gratuitous spaces where they
# weren't really needed, i.e.:
#
#   original: void   myfunc ( int x , int y ) ;
#   becomes:  void myfunc(int x,int y);
#

our $ptr_or_ref_re = compile_regexp(
  qr{(?> \* \s){0,256} \&{0,2}+}oamsx, 'ptr_or_ref',
  'Pointer (*) and/or reference type extension, with arbitrary '.
  'indirection (*, **, ***, etc) followed by either lvalue '.
  'reference (&) or rvalue reference (&&)');

#our $template_type_list_item_re = compile_regexp(
#  \qr/\G (?'typename_or_class_or_type_or_template) ( (?: [^\<\>\,]+ | $angle_brackets_re)+ )
#    (?: , | \Z)
#  /oamsx,

our $template_type_list_re = compile_regexp(
  qr{(?> [^\<\>\(\)\;\{\}] | $angle_brackets_re | $parens_re){0,1024}+}oamsx,
  'template_type_list_re',
  'Template type specification list, excluding angle brackets');

our $template_spec_re = compile_regexp(qr{
  template \s \< (?> \s $template_type_list_re \s \>)
  }oamsx, 'template_spec_re');

our $type_spec_re = compile_regexp(
  qr{(?'type_attributes' 
        (?> \b (?: constexpr | const | volatile | mutable | static) \s)*+
      )
      (?'type_specifier'
        (?>
          \b (?'type_alias_operator' decltype | typeof) \s
          \( (?'expr_of_type' (?> $inside_of_parens_re)) \) \s
        ) |
        (?'fundamental_type_name' \b
          (?>
            (?: # note: this will match erroneous repeats or conflicts like 
              # 'int int', 'short long', 'unsigned signed long long long', etc.
              # but these will still be properly caught by the compiler itself.
              # Unfortunately C and C++ let these reserved words appear in any
              # order while still specifying a valid non-ambiguous type:
              unsigned | signed | double |
              short | float | bool | char | void | long | int 
            ) \s
          ){1,4}
        ) |
        (?:
          (?'type_name' $cxx_identifier_re \s)
          (?: \< (?> 
            \s 
            (?'type_template_params' (?> $template_type_list_re)) 
            \s? \> \s)
          )?+
        )
      )
      (?> (?'type_ptr_or_ref' (?> $ptr_or_ref_re)) \s)?+
     }oamsx, 'type_spec', 'C++ type specification, including attributes, type name '.
                          '(or decltype alias), optional template parameters, and '.
                          'pointer and/or reference specifiers');

our $standalone_type_spec_nocap_re = compile_regexp(
  qr{
      #
      # In C++, all declarations of any kind must follow either a preceeding 
      # semicolon (if after any kind of declaration or a statement), or a
      # right brace (if after any kind of function or block definition).
      #
      # The inclusion of this constraint *dramatically* speeds up this regexp:
      #
      (?> (?<= [\;\}] \s) | \A)
      (?> \b (?> const(?:expr)? | volatile | mutable | static) \s){0,5}
      (?:
        (?>
          \b (?> decltype | typeof) \s
          $parens_re \s
        ) |
        (?>
          (?>
            (?> (?:un)?signed | double | short | float | bool | char | void | long | int) \s
          )++
        ) |
        (?> 
          (?> $cxx_identifier_re) \s
          (?> \< \s (?> $template_type_list_re) \s?+ \> \s)?+
        )
      )
      (?> $ptr_or_ref_re \s)?+
     }oamsx, 'type_spec_nocap', 'C++ type specification, including attributes, type name '.
                                         '(or decltype alias), optional template parameters, and '.
                                         'pointer and/or reference specifiers');

our $field_decl_re = compile_regexp(
  qr{\G 
     (?'field_name'
       (?> $cxx_identifier_re) |    # simple identifier for field name
       (?= \s? \: \s \d+)      # ...or nameless padding field but (lookahead) followed by :123 field width
     ) \s?
     (?:
       (?:
         \: \s (?'bitwidth' \d++) |                 # name:123, (bitfield)
         (?: \[ (?'array_size' $inside_of_square_brackets_re) \])      # name[123],  (array)
       )
       \s
     )?
     (?: \= \s
       (?'init_value'
         $braces_re |                 # = {1, 2, 3, ...}
         $rvalue_expression_re        # = anything-else-incl-nested-parens
       )
     )?
     \s? [,;] \s?}oamsx, 'field_decl', '');

our $typedef_decl_re = compile_regexp(
  qr{(?'typedef_decl'
       (?'type_ptr_or_ref' $ptr_or_ref_re) \s
       (?'typedef_new_type_name' $cxx_identifier_re)
       (?: \s \[ (?'array_size' $inside_of_square_brackets_re) \] )?
     )
     \s (?: [,;] | \Z)
    }oamsx, 'typedef_decl', '');

our $function_type_name_args_body_re = compile_regexp(
  qr{(?> $template_spec_re \s)?
     (?'function_attributes'
       (?: \b (?: const(?>expr)? | static | volatile |
           inline | explicit | noexcept | virtual |
           friend | atomic) \s ){0,10}
     )
     (?:
       (?'function_name'
         (?'constructor_name' $cxx_identifier_re) |
         (?'destructor_name' \~ \s $cxx_identifier_re) |
         (?: \b operator \s (?'casting_operator_name' (?> $type_spec_re)))
       ) |
       (?:
         (?'return_type' $type_spec_re)
         (?'function_name'
           (?> 
             operator \s
             (?'operator_name' $cxx_extended_operators_re)
           ) |
           $cxx_identifier_re
         )
       )
     ) \s
     \( (?'argument_list' $inside_of_parens_re) \) \s
     (?'trailing_function_attributes'
       (?:
         (?: && | const | volatile | noexcept (?> \s $parens_re)?) \s 
       ){0,4}
     )
     (?:
       (?: \= \s \b (?'default_or_delete_or_purevirt_suffix' default | delete | 0))? \s ; |
       (?:
         (?: \: (?'constructor_initializer_list' (?: \s $cxx_identifier_re \s $parens_re \s \,?){1,1024}))?
         \{ (?'function_body' $inside_of_braces_re) \} \s ;?
       )
     )}oamsx, 'function_type_name_args_body', '');

our $function_decl_argument_list_item_re = compile_regexp(
  qr{\G \s?
      (?:
        (?'variadic_arg' (?> $cxx_identifier_re)? \s \.\.\.) |
        (?:
          (?> $type_spec_re)
          (?> (?'arg_name' $cxx_identifier_re))?
          (?'default_arg_value' \s \= \s $rvalue_expression_re)?
        )
      )
      \s? (?: , | \Z)
     }oamsx, 'function_decl_argument_list_item_re', '');

our $enum_def_re = compile_regexp(
  qr{\b enum
     (?> \s (?'enum_name' $cxx_identifier_re))?
     (?> \s \: \s (?'enum_datatype' $cxx_identifier_re))?
     \s \{ (?'enum_list' $inside_of_braces_re) \} \s ; 
     }oamsx, 'enum_def', '');

our $declaration_or_block_re = compile_regexp(
  qr{\G (?> \s*+)
      (?:
        $enum_def_re |  # enum { ... }
        (?: \b (?'access_spec' public|protected|private) \s \:) |
        (?: 
          \b typedef \s
          (?'typedef_base_type' (?> $type_spec_re))
          (?'typedef_decl_list' [^\;]+) \s ;
         ) |
         (?'function_chunk' $function_type_name_args_body_re) |
         (?> $type_spec_re) (?'field_decl_list' [^;]+ \s ;) # field declaration
     ) \s*+}oamsx, 'declaration_or_block', '');

our $class_struct_union_re = compile_regexp(
  qr{(?> $template_spec_re \s)? # (optional) template specification
      (?: \w+ \s)*+              # (optional) attributes, e.g. autogen, etc.
      (struct|union|class) \s    # class, struct or union
      (?> ($cxx_identifier_re))     # name
      (?> \s \: \s [^\{\;]*+)?  # (optional) inheritance specification
      \s \{ ($inside_of_braces_re) \} \s \;
     }oamsx, 'class_struct_union');

# regex to match any C/C++ token, from http://www.perlmonks.org/?node_id=1049222
#our $old_cxx_token_re = compile_regexp(
#  \qr/(((\?+|(\?\/|\/)(\?\/)*\?*)|([^\'\"\/\s\?]|((\?|\/)\?+[^\s\?\"])|((\?\/|\/)(\?\/)*([^\'\"\/\s\?\*]|\?(\?+[^\?\"\s]|[^\'\"\/\s\?]))))([^\'\"\/\s\?]|\?\?+[^\?\"\s]|(\/|\?\/)(\?\/)*([^\'\"\/\s\?\*]|\?(\?+[^\?\"\s]|[^\'\"\/\s\?])))*((\?+|(\/|\?\/)(\?\/)*\?*)?))|((\'([^\'?\\]|\\.|\?(\?+(\/.|[^?\/])))*(\'|\?\'))|(\"([^\"\\?]|\\.|\?\?+(\/.|[^\?\"\/]))*(\"|\?+\"))))/oamsx,
#  'cxx_token');

our $if_or_ifdef_endif_re = compile_regexp(
  qr{((?:
    \#if(?:def)?
    (?:
      (?> [^\#]+) | \# (?! if (?:def)?) (?! endif) | (?-1)
    )*
    \#endif
  ))}oamsx, 'if_or_ifdef_endif_re',
  '#if or #ifdef with enclosed text optionally including nested #if/#ifdef '.
  ' blocks, #else clauses, or #elif clauses, and terminated by properly '.
  ' balanced #endif',
  \('1' => 'entire matched block including balanced delimiters'));

our $inside_if_or_ifdef_optional_else_endif_re = compile_regexp(
  qr{(?:
    \# (?'if_or_ifdef' if(?:def)?) \s (?'if_condition' (?: \\\n | [^\n])+) \n
    (?'if_contents' (?: 
      $if_or_ifdef_endif_re | \# (?! endif) | \# (?! else) | [^\#]+
    )*)
    (?: \# (?'else' else) \b (?'else_comment' [^\n]*) \n)?
    (?'else_contents' (?: 
      $if_or_ifdef_endif_re | \# (?! endif) | [^\#]+
    )*)
    \# endif \s? (?'endif_comment' [^\n]*) \n
  )}oamsx, 'inside_if_or_ifdef_optional_else_endif_re');

our $cxx_balanced_structural_chars_re = compile_regexp(
  qr{([\{\(\[\<])|([\}\)\]\>])}oamsx, 'cxx_balanced_structural_chars');

# e.g. use constant { ... => ..., ... => ...
use constant {
  CXX_TOKEN_WHITESPACE   => 1,
  CXX_TOKEN_COMMENT      => 2,
  CXX_TOKEN_QUOTED       => 3,
  CXX_TOKEN_NUMERIC      => 4,
  CXX_TOKEN_OPERATOR     => 5,
  CXX_TOKEN_IDENTIFIER   => 6,
  CXX_TOKEN_STRUCTURAL   => 7,
  CXX_TOKEN_PREPROCESSOR => 8,
};

our $cxx_token_re = compile_regexp(
  qr{\G
      (                                           # entire token is $1
        (?>
          $c_cxx_comment_re (*:2) |
          $cxx_identifier_re (*:6) |
          $quoted_literal_nocap_re (*:3) |             # $2 embedded within quoted_literal_nocap_re, for the raw string backref)
          $numeric_literal_nocap_re (*:4) |
          $preprocessor_re (*:8)|
          $cxx_extended_operators_re (*:5) |           # $3 embedded within cxx_extended_operators_re, for the repeated operators backref e.g. ++ -- && || << >> etc.
          [\(\)\{\}\[\]\;\,] (*:7)
        )
      )
      (?'whitespace' (?> \s | (?: \\ \n))*+)
      }oamsx, 'cxx_token');

our @all_capture_group_names = 
  qw(access_spec 
     alias_to_type
     argument_list
     array_size
     bitwidth
     casting_operator_name
     constructor_initializer_list
     constructor_or_destructor_name
     default_or_delete_or_purevirt_suffix
     enum_datatype
     enum_list
     enum_name
     field_decl_list
     field_decl_rest
     field_name
     function_attributes
     function_body
     function_chunk
     function_name
     trailing_function_attributes
     init_value
     operator_name
     type_attributes
     type_name
     type_ptr_or_ref
     type_specifier
     typedef_base_type
     typedef_decl_rest
     typedef_new_type_name);

1;




#------------------------------------------------------------------------------

#our $cxx_normalize_token_separators_re = compile_regexp(
#  \qr/(?:
#        $c_comment_re | 
#        $cxx_comment_re |
#        $quoted_literal_nocap_re |
#        $numeric_literal_nocap_re |
#        $cxx_operators_re |
#        $cxx_extended_operators_re |
#        $cxx_identifier_re |
#        (?: [\(\)\{\}\[\]\;\,])
#      )
#      \K
#      (\n)?+
#      \s*+
#      /oamsx, 'normalize_cxx_token_separators');

#use Regexp::Common qw /balanced/;

#our $preproc_bal_re = qr{$RE{balanced}{-begin => 'ifdef'}{-end => 'endif'}}oamsx;
#print($preproc_bal_re);
#exit 0;
#qr/(
#     (?:ifdef
#       (?:
#         (?>[^ie]+) | i(?!fdef) | e(?!ndif)|(?-1))*endif))/

#our $preprocessor_if_endif_else_re = compile_regexp(qr{
#  \# $cxx_opt_space_re
#  (?:
#    (?'start_token' ifdef | ifndef | else | elif) |
#    (?: (?'start_token' if) $cxx_opt_space_re \( (?'if_condition' $inside_of_parens_re) \) )
#  )
#  (?'after_start_token' [^\n]*) \n
#  (?'body' .
#  .+
#    \# (?'if_or_ifdef' if(?:def)?) $cxx_space_re (?'if_condition' (?: \\\n | [^\n])+) \n
#    (?'if_contents' (?: 
#      $if_or_ifdef_endif_re | \# (?! endif) | \# (?! else) | [^\#]+
#    )*)
#    (?: \# (?'else' else) \b (?'else_comment' [^\n]*) \n)?
#    (?'else_contents' (?: 
#      $if_or_ifdef_endif_re | \# (?! endif) | [^\#]+
#    )*)
#    \# endif $cxx_opt_space_re (?'endif_comment' [^\n]*) \n
#  )}oamsx, 'inside_if_or_ifdef_optional_else_endif_re');

#our $inside_if_or_ifdef_else_or_elif_or_endif_re = compile_regexp(
#  \qr/(?:
#    \# (if(def)?) \s+ ((?: \\\n | [^\n])+) \n
#    (?'if_contents' (?: 
#      $if_or_ifdef_endif_re | \# (?! endif) | \# (?! else|elif) | [^\#]+
#    )*)
#    (?: \# (?'else_or_elif' esle | elif) (?'else_or_elif_cond' (?: \\\n | [^\n])+) \n
#    (?'else_or_elif_contents' (?: 
#      $if_or_ifdef_endif_re | \# (?! endif) | \# (?! else|elif) | [^\#]+
#    )*)
#    \# endif \s* [^\n]* \n
#  )
#| el \#[^\<\>\"\'] | $quoted_re | $angle_brackets_re)*/oamsx,
#  'inside_of_angle_brackets');

#$else_or_elif_within_ifdef_block_re 

#([\ \t]*+ \n \s*+)? (?(1)\s*+
#(([\t\ ]*) | ([\t\ ]*\n\r\f]*))

