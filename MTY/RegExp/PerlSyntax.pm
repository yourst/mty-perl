#!/ usr/bin/perl -w
# -*- cperl -*-
#
# MTY::RegExp::PerlSyntax
#
# Perl 5.x syntax matching patterns
#
# Copyright 2003-2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::RegExp::PerlSyntax;

use integer; use warnings; use Exporter::Lite;

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($auto_import_clause_re $balanced_symbol_chars_re $noexport_re
     $not_prefixed_by_sigil_re $perl_constant_decl_re
     $perl_constant_to_value_mapping_re $perl_delimited_block_pair_re
     $perl_delimited_block_re $perl_double_quoted_or_qq_string_re
     $perl_double_quoted_string_re $perl_exports_clause_re
     $perl_identifier_decl_or_use_re $perl_identifier_re
     $perl_identifier_sigil_and_symbol_re
     $perl_keywords_and_built_in_functions_re
     $perl_lhs_to_rhs_mapping_expr_re $perl_non_global_var_decl_re
     $perl_optional_exports_clause_re $perl_or_sh_comment_re
     $perl_package_decl_re $perl_package_name_re $perl_pragma_re
     $perl_program_first_line_shebang_re $perl_q_string_re
     $perl_qr_quoted_regexp_re $perl_qw_quoted_word_list_re
     $perl_regexp_op_re $perl_scalar_identifier_re $perl_sigil_re
     $perl_single_quoted_or_q_string_re $perl_single_quoted_string_re
     $perl_string_re $perl_sub_decl_re $perl_unbalanced_delimited_block_re
     $perl_var_decl_re $perl_var_identifier_re $unbalanced_symbol_chars_re
     %perl_keywords_and_built_in_functions %perl_pragmas
     @perl_keywords_and_built_in_functions @perl_pragmas);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::RegExp::Define;
use MTY::RegExp::Blocks;
use MTY::RegExp::Strings;
use MTY::RegExp::Numeric;

#
# Miscellaneous Perl constructs
#

our $perl_exports_clause_re = 
  qr{\b our \s*+ \@ EXPORT \s*+ = \s*+ (?: \# [^\n]+ \n)? \s*+ qw \s*+ $parens_re \s*+ \;}oamsx;

our $perl_optional_exports_clause_re = 
  qr{\b our \s*+ \@ EXPORT_OK \s*+ = \s*+ qw \s*+ \( ($inside_parens_re) \)}oamsx;

our $auto_import_clause_re = 
  qr{^ \#\! \s* autoimport \s* { [^\n]* \n
     (?: ^ [^\n]* \n)*
     ^ \#\! \s* } [^\n]* \n
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
  qr{(?<! [\$\@\%]) \b}oamsx, 'not_prefixed_by_sigil');

our $perl_unbalanced_delimited_block_re = compile_regexp(
  qr{($unbalanced_symbol_chars_re)
      ( 
        (?: 
          (?: \\ .) | 
          (?: (?! \g{-2}) .)
        )* 
      )
      \g{-2}
      }oamsx, 'perl_unbalanced_delimited_block');

our $perl_delimited_block_re = compile_regexp(
  qr{(?|
        (?: (\() ($inside_parens_re) \) ) |
        (?: (\{) ($inside_braces_re) \} ) |
        (?: (\[) ($inside_square_brackets_re) \] ) |
        (?: (\<) ($inside_angle_brackets_re) \> ) |
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
        (?> \" ((?: [^\"\\] | \\ .)*+) \") |
        (?> $not_prefixed_by_sigil_re qq ($perl_delimited_block_re))
      )
     }oamsx, 'Perl double quoted string with either quotes (") or in '.
       'qq-form with an arbitrary delimiter symbol (e.g. qq!abc!)');

our $perl_single_quoted_or_q_string_re = compile_regexp(
  qr{(?|
        (?> ' ((?: [^\'\\] | \\ .)*+) ') |
        (?> $not_prefixed_by_sigil_re q ($perl_delimited_block_re))
      )
     }oamsx, 'Perl single quoted string with either quotes (\') or in '.
       'q-form with an arbitrary delimiter symbol (e.g. q!abc!)');

our $perl_q_string_re = compile_regexp(
  qr{$not_prefixed_by_sigil_re q ($perl_delimited_block_re)
     }oamsx, 'Perl q(...) style non-interpolated quoted string');

our $perl_double_quoted_string_re = compile_regexp(
  qr{" (?> [^\"\\]*+ | \\ .)*+ "
     }oamsx, 'Perl double quoted string with double quotes (")');

our $perl_single_quoted_string_re = compile_regexp(
  qr{' (?> [^\'\\]*+ | \\ .)*+ '
     }oamsx, 'Perl single quoted string with single quotes (\')');

our $perl_string_re = compile_regexp(
  qr{$perl_single_quoted_or_q_string_re|
      $perl_double_quoted_or_qq_string_re|
      $perl_qw_quoted_word_list_re}oamsx, 'perl_string',
      'Any Perl string (single quoted, double quoted, q, qq, qw)');

our $perl_sigil_re = 
  qr{[\$\@\%]}oamsx;

our $perl_identifier_re =
  qr{[A-Za-z\_] \w*}oamsx;

our $perl_var_identifier_re = 
  qr{(?<! \\) [\$\@\%] 
     (?|
       \{ $perl_identifier_re \} |
       $perl_identifier_re 
     )
    }oamsx;

our $perl_scalar_identifier_re = compile_regexp(
  qr{(?<! \\) \$ 
      (?|
        \{ ($perl_identifier_re) \} |
        ($perl_identifier_re)
      )
     }oamsx, 'perl_scalar_identifier');

our $perl_or_sh_comment_re = compile_regexp(
  qr{^ [^\#]*+ \K \# [^\n]*+ \n}oamsx, 'perl_or_sh_comment',
  'Perl or shell script single line comment starting with "#"');

our $perl_lhs_to_rhs_mapping_expr_re = compile_regexp(
  qr{\A \s*+ 
     ([^=] | (?: = (?! >)))+
     \s*+ => \s*+ 
     (.++) \Z}oamsx,
  'perl_lhs_to_rhs_mapping_expr',
  'Perl left-hand-side to right-hand-side mapping expression '.
  'of the form: "lhs => rhs" (use on a pre-extracted list entry '.
  'or equivalent expression only). Captures lhs and rhs into ($1, $2).');

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

our $perl_pragma_re = 
  qr{a(?> rybase | ttributes | uto (?> (?> die (?: :: [\w\:]++)?) | use)) |
     b(?> ase | ig (?> int | num | rat) | lib | ytes) |
     c(?> harnames | onstant) | d(?> eprecate | iagnostics) |
     encoding (?> :: warnings)? | f(?> eature | i (?> elds | letest)) |
     i(?> f | n (?> c::latest | teger)) | l(?> ess | ib | ocale) |
     mro | o(?> ps | verload(?>ing)?) | parent | re | 
     s(?> igtrap | ort | trict | ubs) | threads (?> ::shared)? | utf8 |
     v(?> ars | ersion | msish) | warnings(?> ::register)?}oamsx;

our %perl_pragmas = 
  array_to_hash_keys(\@perl_pragmas, 1);

our @perl_keywords_and_built_in_functions =
  qw(ARGV ARGVOUT BEGIN CHECK ENV END FALSE INC INIT SIG STDERR STDIN STDOUT 
     TRUE __DATA__ __END__ __FILE__ __LINE__ __PACKAGE__ abs accept alarm 
     and atan2 bind binmode bless caller case chdir chmod chomp chop chown chr 
     chroot close closedir cmp connect continue cos crypt dbmclose dbmopen 
     defined delete die do dump each else elsif endgrent endhostent endnetent 
     endprotoent endpwent endservent eof eq eval exec exists exit exp fcntl 
     fileno flock for foreach fork format formline ge getc getgrent getgrgid 
     getgrnam gethostbyaddr gethostbyname gethostent getlogin getnetbyaddr 
     getnetbyname getnetent getpeername getpgrp getppid getprotobyname 
     getprotobynumber getprotoent getpwent getpwnam getpwuid getservbyname 
     getservbyport gt getservent getsockname getsockopt glob gmtime getpriority 
     goto grep hex if index int ioctl join keys kill last lc lcfirst le length 
     link listen local localtime lock log lstat lt m map mkdir msgctl msgget 
     msgrcv msgsnd my ne next no not oct open opendir or ord our pack package
     pipe pop pos print printf push q qq quotemeta qw qx rand read readdir 
     readlink recv redo ref rename require reset return reverse rewinddir 
     rindex rmdir s scalar seek seekdir select semctl semget semop send 
     setgrent sethostent setnetent setpgrp setpriority setprotoent setpwent 
     setservent setsockopt shift shmctl shmget shmread shmwrite shutdown sin 
     sleep socket socketpair sort splice split sprintf sqrt srand stat study
     sub substr symlink syscall sysopen sysread sysseek system syswrite tell
     telldir tie time times tr truncate uc ucfirst umask undef unless unlink
     unpack unshift untie until use utime values vec wait waitpid wantarray
     warn while write xor
     $_ @_ %_ $0 $1 $2 $3 $4 $5 $6 $7 $8 $9
     @EXPORT @EXPORT_OK);

our %perl_keywords_and_built_in_functions = 
  array_to_hash_keys(\@perl_keywords_and_built_in_functions, 1);

our $perl_non_global_var_decl_re = 
  qr{\b local|state|my \s*+
     (?>
       $perl_var_identifier_re |
       \( (?> $perl_var_identifier_re [\s\,]*+)++ \)
     )}oamsx;

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

#our $my_nested_parens_braces_brackets_quoted_re = compile_regexp(
#  \qr/(?>
#  (
#    (?> \{ (?> (?> [^\{\}]++) | (?-1))*+ \}) |
#    (?> \[ (?> (?> [^\[\]]++) | (?-1))*+ \]) |
#    (?> \( (?> (?> [^\(\)]++) | (?-1))*+ \)) |
#    " (?> (?> [^\"\\] | \\ .)*+ ") |
#    ' (?> (?> [^\'\\] | \\ .)*+ ')
#  ))/oamsx, 'my_nested_parens_braces_brackets_quoted');

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

our $perl_sub_decl_re = compile_regexp(
  qr{\b (sub) \s+
      (\w+) \s* 
      (?: ($parens_re))? \s*
      (?= [^\#\n]* \#\! \s*+ (noexport))?
      (*:sub_decl)
     }oamsx, 'perl_sub_decl');

our $perl_identifier_sigil_and_symbol_re = qr{(([\$\@\%\=]?)(\w++))}oax;

our $perl_package_name_re = qr{(?> [A-Za-z\_] \w*+ (?> \:\: \w++)*+)}oamsx;

our $perl_package_decl_re = qr{^ \s*+ (package) \s++ ($perl_package_name_re) \s*+ ;}oamsx;

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


1;
