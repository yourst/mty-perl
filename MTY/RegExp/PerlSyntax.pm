#!/ usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::PerlSyntax
#
# Perl 5.x syntax matching patterns
#
# Copyright 2003-2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::RegExp::PerlSyntax;

use integer; use warnings; use Exporter qw(import);

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($noexport_re %perl_pragmas @perl_pragmas $perl_sigil_re %perl_keywords
     @perl_keywords $perl_pragma_re $perl_string_re %perl_operators
     @perl_operators $perl_comment_re $perl_pod_doc_re $perl_here_doc_re
     $perl_keywords_re $perl_q_string_re $perl_sub_decl_re $perl_var_decl_re
     $perl_end_block_re $perl_operators_re $perl_regexp_op_re
     $end_of_includes_re $perl_attributes_re $perl_identifier_re
     $perl_structural_re $perl_package_use_re $perl_package_decl_re
     $perl_package_deps_re $perl_package_name_re $auto_import_clause_re
     $perl_constant_decl_re $perl_package_decls_re $perl_quoted_string_re
     $perl_exports_clause_re $perl_var_identifier_re $perl_delimited_block_re
     %perl_built_in_functions @perl_built_in_functions
     $balanced_symbol_chars_re $not_prefixed_by_sigil_re
     $perl_qr_quoted_regexp_re $perl_scalar_identifier_re
     $perl_sub_decl_and_body_re $perl_comments_above_sub_re
     $perl_package_namespaces_re $perl_sub_argument_names_re
     $unbalanced_symbol_chars_re $perl_non_global_var_decl_re
     $perl_qw_quoted_word_list_re $perl_sub_proto_and_attrs_re
     $inside_perl_quoted_string_re $perl_delimited_block_pair_re
     $perl_double_quoted_string_re $perl_single_quoted_string_re
     $perl_identifier_decl_or_use_re $perl_package_decls_and_deps_re
     $perl_lhs_to_rhs_mapping_expr_re $perl_optional_exports_clause_re
     $perl_constant_to_value_mapping_re $perl_single_quoted_or_q_string_re
     $perl_double_quoted_or_qq_string_re $perl_program_first_line_shebang_re
     $perl_unbalanced_delimited_block_re $perl_identifier_sigil_and_symbol_re
     $perl_package_namespace_separator_re $strip_non_functional_perl_syntax_re
     %perl_keywords_and_built_in_functions
     @perl_keywords_and_built_in_functions
     $perl_keywords_and_built_in_functions_re
     $perl_identifier_sigil_and_symbol_nocap_re);

use MTY::Common::Common;
use MTY::RegExp::Define;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;
#pragma end_of_includes

#
# Miscellaneous Perl constructs
#

our $perl_exports_clause_re = compile_regexp(
  qr{\b our \s*+ \@ EXPORT \s*+ = \s*+ (?: \# \N+ \n)? \s*+ qw \s*+ $parens_re \s*+ \;}oamsx,
  'perl_exports_clause');

our $perl_optional_exports_clause_re = compile_regexp(
  qr{\b our \s*+ \@ EXPORT_OK \s*+ = \s*+ qw \s*+ \( ($inside_parens_re) \)}oamsx,
  'perl_optional_exports_clause');

our $auto_import_clause_re = 
  qr{^ \#\! \s* autoimport \s* { \N* \n
     (?: ^ \N* \n)*
     ^ \#\! \s* } \N* \n
    }oamsx;

my %sigil_to_description = 
  ('$' => 'Scalars',
   '@' => 'Arrays',
   '%' => 'Hashes',
   '=' => 'Constants',
   '' => 'Subroutines');

my %sigil_to_makefile_prefix = 
  ('$' => '',
   '@' => 'array_',
   '%' => 'hash_',
   '=' => 'sub_',
   ''  => 'sub_');

our $unbalanced_symbol_chars_re = qr{[\~\`\!\@\#\$\%\^\&\*\-\=\+\|\\\;\:\'\"\,\.\/\\\?]}oamsx;
our $balanced_symbol_chars_re = qr{[\(\)\[\]\{\}\<\>]}oamsx;

our $not_prefixed_by_sigil_re = compile_regexp(
  qr{(?<! [\$\@\%\&\\]) \b}oamsx, 'not_prefixed_by_sigil');

our $perl_unbalanced_delimited_block_re = compile_regexp(
  qr{($unbalanced_symbol_chars_re)
      ( 
        (?: 
          (?> \\ .) | 
          (?> (?! \g{-2}) .)
        )* 
      )
      \g{-2}
      }oamsx, 'perl_unbalanced_delimited_block');

our $perl_delimited_block_re = compile_regexp(
  qr{(?|
        (?> (\() ($inside_parens_re) \) ) |
        (?> (\{) ($inside_braces_re) \} ) |
        (?> (\[) ($inside_square_brackets_re) \] ) |
        (?> (\<) ($inside_angle_brackets_re) \> ) |
        $perl_unbalanced_delimited_block_re
      )
     }oamsx, 'perl_delimited_block'); 

our $perl_delimited_block_pair_re = compile_regexp(
  qr{(?|
        (?> \( $inside_parens_re \) \( $inside_parens_re \) ) |
        (?> \{ $inside_braces_re \} \{ $inside_braces_re \} ) |
        (?> \[ $inside_square_brackets_re \] \[ $inside_square_brackets_re \] ) |
        (?> \[ $inside_angle_brackets_re \] \[ $inside_angle_brackets_re \] ) |
        (?> ($unbalanced_symbol_chars_re) .*? \g{-1} .*? \g{-1})
      )
     }oamsx, 'perl_delimited_block_pair'); 

our $perl_qr_quoted_regexp_re = compile_regexp(
  qr{\b $not_prefixed_by_sigil_re 
      qr ($perl_delimited_block_re)
      (?> \w*) \b          # (optional modifiers, i.e. qr{...}oamsx)
     }oamsx, 'Perl qr/.../ quoted precompiled regular expression');

our $perl_regexp_op_re = compile_regexp(
  qr{\=\~ \s*+
      (?|
        (?> (?> m|qr)? ($perl_delimited_block_re)) |
        (?> (?> s|tr) ($perl_delimited_block_pair_re))
      ) 
      (?> \w*) \b
     }oamsx, 'Perl regular expression operator and right hand side operand, '.
       'i.e. =~ m/.../xyz (or qr) or s/.../.../xyz (or tr)');

our $perl_qw_quoted_word_list_re = compile_regexp(
  qr{\b $not_prefixed_by_sigil_re qw ($perl_delimited_block_re)
     }oamsx, 'Perl qw(...) quoted word list');

our $perl_double_quoted_or_qq_string_re = compile_regexp(
  qr{(?|
        (?> \" ((?> [^\"\\]++ | \\ .)*+) \") |
        (?> $not_prefixed_by_sigil_re qq ($perl_delimited_block_re))
      )
     }oamsx, 'Perl double quoted string with either quotes (") or in '.
       'qq-form with an arbitrary delimiter symbol (e.g. qq!abc!)');

our $perl_single_quoted_or_q_string_re = compile_regexp(
  qr{(?|
        (?> ' ((?> [^\'\\]++ | \\ .)*+) ') |
        (?> $not_prefixed_by_sigil_re q ($perl_delimited_block_re))
      )
     }oamsx, 'Perl single quoted string with either quotes (\') or in '.
       'q-form with an arbitrary delimiter symbol (e.g. q!abc!)');

our $perl_q_string_re = compile_regexp(
  qr{$not_prefixed_by_sigil_re q ($perl_delimited_block_re)
     }oamsx, 'Perl q(...) style non-interpolated quoted string');

our $perl_double_quoted_string_re = compile_regexp(
  qr{" (?> [^\"\\]++ | \\ .)*+ "
     }oamsx, 'Perl double quoted string with double quotes (")');

our $perl_single_quoted_string_re = compile_regexp(
  qr{' (?> [^\'\\]++ | \\ .)*+ '
     }oamsx, 'Perl single quoted string with single quotes (\')');

# The list above may be faster than using back-references (?):           
# \~ ((?> [^\~\\]++ | \\ .)*+) \~ |
# \` ((?> [^\`\\]++ | \\ .)*+) \` |
# \! ((?> [^\!\\]++ | \\ .)*+) \! |
# \@ ((?> [^\@\\]++ | \\ .)*+) \@ |
# \# ((?> [^\#\\]++ | \\ .)*+) \# |
# \$ ((?> [^\$\\]++ | \\ .)*+) \$ |
# \% ((?> [^\%\\]++ | \\ .)*+) \% |
# \^ ((?> [^\^\\]++ | \\ .)*+) \^ |
# \& ((?> [^\&\\]++ | \\ .)*+) \& |
# \* ((?> [^\*\\]++ | \\ .)*+) \* |
# \- ((?> [^\-\\]++ | \\ .)*+) \- |
# \= ((?> [^\=\\]++ | \\ .)*+) \= |
# \+ ((?> [^\+\\]++ | \\ .)*+) \+ |
# \| ((?> [^\|\\]++ | \\ .)*+) \| |
# \\ ((?> [^\\\\]++ | \\ .)*+) \\ |
# \; ((?> [^\;\\]++ | \\ .)*+) \; |
# \: ((?> [^\:\\]++ | \\ .)*+) \: |
# \' ((?> [^\'\\]++ | \\ .)*+) \' |
# \" ((?> [^\"\\]++ | \\ .)*+) \" |
# \, ((?> [^\,\\]++ | \\ .)*+) \, |
# \. ((?> [^\.\\]++ | \\ .)*+) \. |
# \/ ((?> [^\/\\]++ | \\ .)*+) \/ |
# \? ((?> [^\?\\]++ | \\ .)*+) \?


our $perl_quoted_string_re = compile_regexp(
  qr{(?|
       (?> \" ((?> [^\"\\]++ | \\ .)*+) \") |
       (?> \' ((?> [^\'\\]++ | \\ .)*+) \') |
       (?: q[qwr]? (?|
           \{ ((?> [^\}\\]++ | \\ .)*+) \} |
           \( ((?> [^\)\\]++ | \\ .)*+) \) |
           \[ ((?> [^\]\\]++ | \\ .)*+) \] |
           \< ((?> [^\>\\]++ | \\ .)*+) \> |
           (([\~\`\!\@\#\$\%\^\&\*\-\=\+\|\\\;\:\'\"\,\.\/\\\?]) .*? \g{-1})
         )
       )
     )
  }oamsx, 'perl_quoted_string', 
  'Any Perl string: single quoted, double quoted, q, qq, qr, qw '.
  'with any duplicated or paired delimiters');

our $inside_perl_quoted_string_re = compile_regexp(
  qr{(?|
       (?> \" \K ((?> [^\"\\]++ | \\ .)*+) ) |
       (?> \' \K ((?> [^\'\\]++ | \\ .)*+) ) |
       (?: q[qwr]? (?|
           \{ \K ((?> [^\}\\]++ | \\ .)*+) |
           \( \K ((?> [^\)\\]++ | \\ .)*+) |
           \[ \K ((?> [^\]\\]++ | \\ .)*+) |
           \< \K ((?> [^\>\\]++ | \\ .)*+) |
           (
             ([\~\`\!\@\#\$\%\^\&\*\-\=\+\|\\\;\:\'\"\,\.\/\\\?]) 
             \K
             .*? (?= \g{-1})
           )
         )
       )
     )
  }oamsx, 'inside_perl_quoted_string', 
  'Inside any Perl quoted string (suitable for substituting or removing all such strings)');

our $perl_string_re = compile_regexp(
  qr{$perl_single_quoted_or_q_string_re|
      $perl_double_quoted_or_qq_string_re|
      $perl_qw_quoted_word_list_re}oamsx, 'perl_string',
      'Any Perl string (single quoted, double quoted, q, qq, qw)');

our $perl_structural_re = compile_regexp(
  qr{[\(\)\{\}\[\]\;]}oamsx, 'perl_structural');

our $perl_sigil_re = compile_regexp(
  qr{[\$\@\%]}oamsx, 'perl_sigil');

our $perl_identifier_re = compile_regexp(
  qr{[A-Za-z\_] \w*+}oamsx, 'perl_identifier');

our $perl_var_identifier_re = compile_regexp(
  qr{(?<! \\) [\$\@\%] 
     (?|
       \{ $perl_identifier_re \} |
       $perl_identifier_re 
     )
    }oamsx, 'perl_var_identifier');

our $perl_scalar_identifier_re = compile_regexp(
  qr{(?<! \\) \$ 
      (?|
        \{ ($perl_identifier_re) \} |
        ($perl_identifier_re)
      )
     }oamsx, 'perl_scalar_identifier');

our $end_of_includes_re = compile_regexp(
  qr{(?> ^ \# (pragma) \s++ (end_of_includes) \b
     .*+ \Z)}oamsx,
  'end_of_includes');

our $perl_comment_re = compile_regexp(
  qr{(?<! [\\\$]) \# \N*+ \n}oamsx, 'perl_comment');

#
# Technically this will stop at EOF characters (0x1A)
# to facilitate bulk grepping of many files catted
# together separated by EOFs:
#
# our $perl_end_block_re = compile_regexp(
#   qr{^ (__(?> DATA | END)__) [^\x1A]*+}oamsx,  'perl_end_block');

our $perl_end_block_re = compile_regexp(
  qr{^ (__(?> DATA | END)__) \n .* \Z}oamsx, 'perl_end_block');

our $perl_pod_doc_re = compile_regexp(
  qr{^ = (pod | head([1-4]) | over | item | b(?:ack|egin) | for | en(?:d|coding))
     \N*+ \n
     (?> ^ (?! =cut) \N*+ \n)*+
     ^ =cut \n
  }oamsx,  'perl_pod_doc_re',
  'Perl POD documentation chunk, starting at a line beginning with "=pod" or another '.
  'supported tag, and ending after a line containing only "=cut"');

our $perl_here_doc_re = compile_regexp(
  qr{<< 
     (?|
       (?> " ([^"]+) ") |
       (?> ' ([^']+) ') |
       (?> ` ([^`]+) `) |
       (\S+)
     ) \N* \n
     # (?> ^ (?! \g{-1}) \N*+ \n)*+
     .*?   # this is theoretically less efficient than the code above,
           # but it lets the regexp engine backtrack without recursion...
     ^ \g{-1} \n
  }oamsx, 'perl_here_doc', 
  'Perl "here-doc" quoted multi-line string (see "man perlop" for syntax details)');

our $perl_lhs_to_rhs_mapping_expr_re = compile_regexp(
  qr{\A \s*+ 
     ([^=] | (?: = (?! >)))+
     \s*+ => \s*+ 
     (.++) \Z}oamsx,
  'perl_lhs_to_rhs_mapping_expr',
  'Perl left-hand-side to right-hand-side mapping expression '.
  'of the form: "lhs => rhs" (use on a pre-extracted list entry '.
  'or equivalent expression only). Captures lhs and rhs into ($1, $2).');

our @perl_keywords = 
  qw(BEGIN CHECK END INIT __DATA__ __END__ __FILE__ __LINE__ __PACKAGE__
     and bless caller case continue defined delete do each else elsif eval
     exists for foreach goto if keys last length local m my next no our
     pos q qq qw qx redo ref require return s scalar sub state tie tr undef
     unless untie until use values wantarray while);

our %perl_keywords = map { $_ => 1 } @perl_keywords;

our $perl_keywords_re = compile_regexp(
  qr{\b (?>
       BEGIN|CHECK|END|INIT|__(?>DATA|END|FILE|LINE|PACKAGE)__|
       and|bless|c(?>a(?>ller|se)|ontinue)|d(?>e(?>fined|lete)|o)|
       e(?>ach|ls(?>e|if)|val|xists)|for(?>each)?|goto|if|keys|
       l(?>ast|ength|ocal)|my?|n(?>ext|o(?>ur)?)|pos|q[qwx]?|
       re(?>do|f|quire|turn)|s(?>calar|ub|tate)?|t(?>ie|r)|
       u(?>n(?>def|less|ti[el])|se)|values|w(?>antarray|hile)
     ) \b}oamsx,
  'perl_keywords', 'Highly optimized non-backtracking recognition of '.
    'Perl 5.x keywords (excluding built-in functions or variables)');

our @perl_operators =
  (qw(<=> ... <<= >>= ||= //= **= &&= and cmp not xor
     ~~ << <> =~ => >> ** && || ++ -- // ..
     ^= <= == >= |= != /= .= *= &= %= += -= x=
     -> !~
     eq ge gt le lt ne or
     ^ ~ < > | - : ! ? / . * & % + x), ',');

our %perl_operators = map { $_ => 1 } @perl_operators;

our $perl_operators_re = compile_regexp(
  qr{(?> 
       \< (?> \= \>?+ | \< =?+ | \>)?+ | \. (?> \= | \.{1,2})?+ | \>{1,2} =?+ | 
       \|{1,2} \=?+ | \/{1,2} =?+ | \*{1,2} \=?+ | \&{1,2} \=?+ | 
       \~[\~\=]?+ | \=[\~\>\=]?+ | \+[\+\=]?+ | \-[\-\=\>]?+ | 
       \![\~\=]?+ | [\^\%]=?+ | [\,\:\?] | \b x(?>or \b | \=)?+ |
       \b (?> and | cmp | eq | [gl][et] | n(?>e|ot) | or) \b
     )}oamsx, 'perl_operators',
  'Highly optimized non-backtracking recognition of Perl 5.x operators');

our @perl_built_in_functions = 
  qw(ARGV ARGVOUT ENV FALSE INC SIG STDERR STDIN STDOUT TRUE abs accept
     alarm atan2 bind binmode chdir chmod chomp chop chown chr chroot close
     closedir connect cos crypt dbmclose dbmopen die dump endgrent
     endhostent endnetent endprotoent endpwent endservent eof exec exit exp
     fcntl fileno flock fork format formline getc getgrent getgrgid
     getgrnam gethostbyaddr gethostbyname gethostent getlogin getnetbyaddr
     getnetbyname getnetent getpeername getpgrp getppid getprotobyname
     getprotobynumber getprotoent getpwent getpwnam getpwuid getservbyname
     getservbyport getservent getsockname getsockopt glob gmtime
     getpriority grep hex index int ioctl join kill lc lcfirst link listen
     localtime lock log lstat map mkdir msgctl msgget msgrcv msgsnd oct
     open opendir ord pack package pipe pop print printf push quotemeta
     rand read readdir readlink recv rename reset reverse rewinddir rindex
     rmdir seek seekdir select semctl semget semop send setgrent sethostent
     setnetent setpgrp setpriority setprotoent setpwent setservent
     setsockopt shift shmctl shmget shmread shmwrite shutdown sin sleep
     socket socketpair sort splice split sprintf sqrt srand stat study
     substr symlink syscall sysopen sysread sysseek system syswrite tell
     telldir time times truncate uc ucfirst umask unlink unpack unshift
     utime vec wait waitpid warn write);

our %perl_built_in_functions = map { $_ => 1 } @perl_built_in_functions;

our @perl_keywords_and_built_in_functions = (@perl_keywords, @perl_builtin_functions);

our %perl_keywords_and_built_in_functions = map { $_ => 1 } @perl_keywords_and_built_in_functions;

our $perl_keywords_and_built_in_functions_re = compile_regexp(
 qr{ARGV(?>OUT)?|BEGIN|CHECK|E(?>NV|ND)|FALSE|IN(?>C|IT)|S(?>IG|TD(?>ERR|IN|OUT))|
     TRUE|__(?>DATA|END|FILE|LINE|PACKAGE)__|
     a(?>bs|ccept|larm|nd|tan2)|
     b(?>in(?>d|mode)|less)|
     c(?>a(?>ller|se)|h(?>dir|mod|omp|op|own|r(?>oot)?)|lose(?>dir)?|mp|o(?>n(?>nect|tinue)|s)|rypt)|
     d(?>bm(?>close|open)|e(?>fined|lete)|ie|o|ump)|
     e(?>ach|ls(?>e|if) | nd(?>gr|host|net|proto|pw|serv)ent|of|q|val|x(?>ec|i(?>sts|t)|p)) |
     f(?>cntl|ileno|lock|or(?>each|k|mat|mline)?) |
     g(?>(?>e(?>t(?>c|gr(?>ent|gid|nam)|host(?>by(?>addr|name)|ent)|login|net(?>by(?>addr|name)|ent)|
       p(?>eername|grp|pid|r(?>iority|oto(?>by(?>name|number)|ent))|w(?>ent|nam|uid))|
       s(?>erv(?>by(?>name|port)|ent))|(?>ock(?>name|opt))))?)|t|lob|mtime|oto|rep)|
     hex |
     i(?>f|n(?>dex|t)|octl) |
     join |
     k(?>eys|ill) |
     l(?>ast|c(?>first)?|e(?>ngth)?|i(?>nk|sten)|o(?>cal(?>time)?|ck|g)|stat|t) |
     m(?>ap|kdir|sg(?>ctl|get|rcv|snd)|y)? |
     n(?>e(?>xt)?|o(?>t?)) | 
     o(?>ct|pen(?>dir)?|r(?>d)?|ur) | 
     p(?>ack(?>age)?|ipe|o(?>p|s)|rintf?|ush) |
     q(?>q|uotemeta|w|x)? | 
     r(?>and|e(?>ad(?>dir|link)?|cv|do|f|name|require|set|turn|verse|winddir)|index|rmdir) |
     s(?>calar|e(?>ek(?>dir)?|lect|m(?>ctl|get|op)|nd|t(?>(?>gr|host|net)ent|p(?>grp|r(?>iority|(?>oto|pw|serv)ent))|sockopt))|
       h(?>ift|m(?>ctl|get|read|write)|utdown)|in|leep|o(?>cket(?>pair)?|rt)|p(?>lice|lit|rintf)|qrt|rand|t(?>at|udy)|
       ub(?>str)?|y(?>mlink|s(?>call|open|read|seek|tem|write))) |
     t(?>ell(?>dir)?|i(?>e|mes?)|r(?>uncate)?) | 
     u(?>c(?>first)?|mask|n(?>def|less|link|pack|shift|tie|til)|se|time) |
     v(?>alues|ec) |
     w(?>a(?>it(?>pid)?|ntarray|rn|)|hile|rite) |
     xor |
     \$(?>_|\d++) | [\@\%](?>EXPORT(?>_OK)?)
    }oamsx, 'perl_keywords_and_built_in_functions',
    'Highly optimized non-backtracking recognition of Perl 5.x keywords, '.
    'built-in functions and various special pre-defined variables.');

our @perl_pragmas = 
  qw(arybase attributes autodie autodie::exception
     autodie::exception::system autodie::hints autouse base bigint bignum
     bigrat blib bytes charnames constant deprecate diagnostics encoding
     encoding::warnings feature fields filetest if inc::latest integer
     less lib locale mro open ops overload overloading parent re sigtrap
     sort strict subs threads threads::shared utf8 vars version vmsish
     warnings warnings::register);

our %perl_pragmas = map { $_ => 1 } @perl_pragmas;

our $perl_pragma_re = 
  qr{a(?> rybase | ttributes | uto (?> (?> die (?: :: [\w\:]++)?) | use)) |
     b(?> ase | ig (?> int | num | rat) | lib | ytes) |
     c(?> harnames | onstant) | d(?> eprecate | iagnostics) |
     encoding (?> :: warnings)? | f(?> eature | i (?> elds | letest)) |
     i(?> f | n (?> c::latest | teger)) | l(?> ess | ib | ocale) |
     mro | o(?> ps | verload(?>ing)?) | parent | re | 
     s(?> igtrap | ort | trict | ubs) | threads (?> ::shared)? | utf8 |
     v(?> ars | ersion | msish) | warnings(?> ::register)?}oamsx;

our $perl_non_global_var_decl_re = compile_regexp(
  qr{\b local|state|my \s*+
     (?>
       $perl_var_identifier_re |
       \( (?> $perl_var_identifier_re [\s\,]*+)++ \)
     )}oamsx, 'perl_non_global_var_decl');

our $noexport_re = 
  qr{(?= [^\#\n]* \#\! \s*+ (noexport))?}oamsx;

our $perl_var_decl_re = compile_regexp(
  qr{\b (local|state|our|my) \s*
         (?|
           ($perl_var_identifier_re) (*:var_decl) |
           \( ((?: $perl_var_identifier_re [\s\,]*)+) \) (*:var_decl_list)
         )
         ()
         $noexport_re
     }oamsx, 'perl_var_decl');

our $perl_constant_to_value_mapping_re = compile_regexp(
  qr{\s*+ 
      (\w++) \s*+ 
      => 
      ((?>
          [^\,\;\(\)\{\}\[\]\'\"]++ |
          $nested_parens_braces_brackets_quoted_re
        )++)
      (?= [\,\;\}] | \Z)
     }oamsx, 'perl_constant_to_value_mapping');

our $perl_constant_decl_re = compile_regexp(
  qr{\b use \s+ (constant) \s*
      (?|
        (?: \{ ($inside_braces_re) \} ; (*:const_decl_list)) |
        (?: ([^;]+) ; (*:const_decl))
      )
     }oamsx, 'perl_constant_decl');

our $perl_attributes_re = compile_regexp(
  qr{(?> : \s*+ \w++ \s*+)*+}oamsx,
  'perl_attributes_re',
  'Attribute list for a Perl subroutine, variable, etc. of the form '.
  '":attrname :attrname2 ..."');

our $perl_sub_proto_and_attrs_re = compile_regexp(
  qr{\s*+ (?> \( ([^\)]*+) \) \s*+)? # prototype (optional)
     ((?> \s*+ : \s*+ \w++)*+) # attributes (optional)
     }oamsx, 'perl_sub_proto_and_attrs',
     'Prototype and attributes of Perl subroutine, '.
     'without the preceeding "sub name" portion. Useful '.
     'within a containing regexp which also matches one '.
     'or more subroutine names.');

our $perl_sub_decl_re = compile_regexp(
  qr{\b (sub) \s++ (\w*+)
     $perl_sub_proto_and_attrs_re
     (*:sub_decl)
  }oamsx, 'perl_sub_decl');

our $perl_sub_decl_and_body_re = compile_regexp(
  qr{$perl_sub_decl_re \s*+
     \{ ($inside_braces_re) \} \s*+ 
     (*:sub_decl_and_body)
  }oamsx, 'perl_sub_decl_and_body');

our $perl_comments_above_sub_re = compile_regexp(
  qr{(?> 
       ((?> ^ \s*+ \# \N*+ \n)+)
       (?> ^ \s*+ \n)* 
       (?= ^ \s*+ 
         # allow for any perl-mod-deps style tags like "noexport:; sub ..."
         (?> (?! sub) \w*+ \: \;? \s*+)*+  
         \b sub \s++ (\w*+)
       )
     )}oamsx, 'perl_comments_above_sub',
  'Block of one or more consecutive perl comment lines (\#...) immediately '.
  'above a subroutine declaration (sub ...) with only optional blank lines '.
  'between them. Captures these comments (as a multi-line string) into $1 '.
  'and the subroutine name into $2 (but does not consume the sub keyword). '.
  'Useful for extracting documentation comments associated with each sub '.
  'prior to stripping all comments.');

our $perl_identifier_sigil_and_symbol_re = compile_regexp(
  qr{(([\$\@\%\=\*]?)(\w++))}oax,
  'perl_identifier_sigil_and_symbol');

our $perl_identifier_sigil_and_symbol_nocap_re = compile_regexp(
  qr{[\$\@\%\=\*]? \w++}oax,
  'perl_identifier_sigil_and_symbol_nocap');

# This regexp applies to the body of each subroutine inside the { ... }:
our $perl_sub_argument_names_re = compile_regexp(
  qr{\b my \s*+ 
     (?|
       (?> \( 
         ((?> \s*+ $perl_identifier_sigil_and_symbol_nocap_re
             \s*+ (?> , | (?= \)))
           )++) \s*+ \) 
       ) | 
       ($perl_identifier_sigil_and_symbol_nocap_re)
     )
     \s*+ = \s*+ 
     (?|
       (\@ \_) | 
       (?> \$ \_ \s*+ \[ \s*+ 
         ( (?> \d++ \s*+ (?> , | (?= \])))++ )
       \])
   )
   \s*+ ;
  }oamsx, 'perl_sub_argument_names',
  'List of variable name(s) (in $1) corresponding to the arguments of the '.
  'enclosing subroutine body this regexp is matched against. This matches '.
  'the "my ($varname, ...) = @_;" construct, as well as any individual '.
  'assignments of the form "my $varname = $_[1]", with the argument '.
  'index returned in $2. To handle both cases, callers should iteratively '.
  'find every match in the subroutine body (or use get_sub_argument_names() '.
  'as shown below).');

our $perl_package_namespace_separator_re = compile_regexp(
  qr{(?> :: | \')}oax, 'perl_package_namespace_separator',
  'Perl package namespace separators ("::" or the legacy "\'")');

our $perl_package_name_re = compile_regexp(
  qr{\b [A-Za-z\_] \w*+ 
     (?> $perl_package_namespace_separator_re \w++)*+
  }oamsx, 'perl_package_name');

our $perl_package_namespaces_re = compile_regexp(
  qr{((?> \w++ $perl_package_namespace_separator_re)*+)
     (\w++)}oamsx, 'perl_package_namespaces');

our $perl_package_decl_re = compile_regexp(
  qr{(?> \b (package) \s++ ($perl_package_name_re) \s*+ [\;\{])}oamsx,
  'perl_package_decl');

our $perl_package_use_re = compile_regexp(
  qr{(?> \b (use | require) \s++ 
       (
         $perl_package_name_re |
         #
         # The quoted string case must come last since
         # a package name containing "'" is also legal,
         # as in My'Strange'Separators'Package'Name vs
         # My::Strange::Separators::Package::Name.
         #
         $perl_quoted_string_re
       ) )
  }oamsx, 'perl_package_use');

our $perl_identifier_decl_or_use_re = compile_regexp(
  qr{(?|
       (?: $perl_package_decl_re (*:package_decl)) |
       (?: \b (use) \s+ # imported module
         # make sure it's not erroneously mis-parsed as a constant or pragma
         (?! constant) ([A-Za-z\_][\w\:]*)
         (?: \s+ [^;]*)? ; 
         (*:use_module)
       ) |
       $perl_constant_decl_re |
       $perl_var_decl_re |
       $perl_sub_decl_re |
       (?: () 
         ($perl_var_identifier_re) 
         (*:var_use)
       ) |
       (?: ()
         (?<! $perl_sigil_re) ($perl_identifier_re) \s*
         ((?: $parens_re)?)
         (*:sub_call)
       )
     )
     }oamsx, 'perl_identifier_decl_or_use');

our $perl_program_first_line_shebang_re = compile_regexp(
  qr{^ \#\! \s*+ \S*? perl \b}oamsx, 'perl_program_first_line_shebang');

our $strip_non_functional_perl_syntax_re = compile_regexp(
  qr{(?> (?> $perl_comment_re) | 
     (?> $perl_end_block_re) |
     (?> $perl_here_doc_re) |
     (?> $perl_pod_doc_re) |
     (?>
       (?<! \b require \s) 
       $perl_quoted_string_re
     )
  )}oamsx, 'strip_non_functional_perl_syntax',
  'Matches any non-functional elements in Perl source code, '.
  'including comments, any text after "__END__", POD documentation '.
  'blocks and any type of quoted strings, including here-docs. '.
  'These should all be stripped or ignored when searching for '.
  'identifiers in Perl code, to prevent such identifiers within '.
  'e.g. comments or strings from being erroneously matched.');

our $perl_package_decls_and_deps_re = compile_regexp(
  qr{(?|
       (?> $end_of_includes_re) |
       # We use two empty capture groups before the parts we strip
       # to ensure no capture groups within the stripping regexps
       # erroneously get returned as if they were the 'use' or
       # 'require' keyword and a package name:
       (?> ( ) ( ) $strip_non_functional_perl_syntax_re) |
       (?> $perl_package_use_re) |
       (?> $perl_package_decl_re)
     )}oamsx, 'perl_package_decls_and_deps',
  'Captures into $2 each Perl package used or required by the input Perl code; '.
  'if a match is found but $2 is empty, the match should be ignored (this is an '.
  'artifact of how this regexp ignores spurious appearances of "use" or "require" '.
  'inside strings, comments, POD documentation, after an __END__ marker, etc. '.
  'Also captures each package namespace declaration.');

our $perl_package_decls_re = compile_regexp(
  qr{(?|
       (?> $end_of_includes_re) |
       (?> ( ) ( ) $strip_non_functional_perl_syntax_re) |
       (?> $perl_package_decl_re)
     )}oamsx, 'perl_package_decls',
     'Variant of perl_package_decls_and_deps_re which only captures package declarations.');

our $perl_package_deps_re = compile_regexp(
  qr{(?|
       (?> $end_of_includes_re) |
       (?> ( ) ( ) $strip_non_functional_perl_syntax_re) |
       (?> $perl_package_use_re)
     )}oamsx, 'perl_package_deps',
     'Extension of perl_package_deps_re which only captures dependencies ("use <package>" statements).');

1;
