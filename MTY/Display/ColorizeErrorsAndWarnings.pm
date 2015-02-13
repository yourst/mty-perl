# -*- cperl -*-
#
# MTY::Display::ColorizeErrorsAndWarnings
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#
# Colorize: ANSI console colors and attributes for any terminal
# (works with Linux console, XTerm, Mac OS X, BSD, Solaris, etc)
#

package MTY::Display::ColorizeErrorsAndWarnings;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw($abort_on_warnings $die_error_message $include_stack_backtrace
     $max_warning_count $max_warning_line_count
     $print_function_args_in_backtrace $warning_count_so_far
     $warning_line_count_so_far $warning_message
     %already_printed_warning_messages die_and_print die_in_color
     die_or_warn_in_color format_stack_backtrace warn_in_color
     warn_without_stack_trace warning warning_string);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Common::StackTrace;
use MTY::Filesystem::Files;
use MTY::RegExp::Define;
use MTY::RegExp::Blocks;
use MTY::RegExp::FilesAndPaths;
use MTY::Display::Colorize;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;

our $abort_on_warnings = 3;
our $die_error_message = '(unknown)';
our $warning_message = '(unknown)';

our $include_stack_backtrace = 1;
our $print_function_args_in_backtrace = 1;
our $max_warning_count = 10;
our $max_warning_line_count = undef;

our $warning_count_so_far = 0;
our $warning_line_count_so_far = 0;

our %already_printed_warning_messages = ( );

sub warning_string {
  my $text = format_all_auto_quoted(join('', @_), ORANGE);
  return Y.' '.warning_sign.' '.U.'WARNING:'.X.' '.ORANGE.$text.X.NL;
}

sub warning {
  printfd(STDERR, warning_string(@_));
}

my $perl_package_and_identifier_re = qr{((?: \w+ ::)*) (\w+)}oax;

sub format_stack_backtrace(;$+) {
  my ($max_width, $raw_callstack) = @_;

  $max_width //= get_terminal_width_in_columns() - 5;
  $raw_callstack //= [ get_stack_backtrace() ];

  my $cwd = getcwd();

  my $longest_module_and_function_name = 0;

  my @callstack = ( );

  foreach my $entry (@$raw_callstack) {
    my ($filename, $line, $package, $function, @args) = @$entry;

    next if ((exists $skip_packages_and_functions_in_stack_backtrace{$package}) ||
              (exists $skip_packages_and_functions_in_stack_backtrace{$function}));

    $package =~ s{::$}{}oax;          # remove trailing '::' if present

    # no package name but full path (which implies the package name):
    if (ends_with($filename, '/'.($package =~ s{::}{/}roaxg).'.pm') || ($package eq 'main')) { 
      $function = remove_from_start($function, $package.'::');
      $package = ''; 
    }

    # Don't print the current directory in the path:
    $filename = remove_from_start($filename, $cwd.'/');

    # Shorten package paths within the system wide Perl library directories:
    $filename =~ s{/usr/lib/perl5/(?: (site|vendor)_perl/)? (?: 5\.[\d\.]+/)? }
                  {B.double_left_angle_bracket.(is_there($1) ? $1 : 'perl').double_right_angle_bracket.'/'.Y}oamsxge;

    push @callstack, [ $filename, $line, $package, $function, @args ];
      
    set_max($longest_package_and_function_name, (is_there($package) ? length($package.'::') : 0) + length($function));
  }

  my $out = '';

  foreach my $entry (@callstack) {
    my ($filename, $line, $package, $function, @arglist) = @$entry;
    my $args = '';

    if ($print_function_args_in_backtrace && scalar(@arglist)) {

      foreach my $arg (@arglist) {
        my $argtype = typeof($arg);
        if ($argtype == UNDEF) {
          $arg = $undef_placeholder;
        } elsif (is_ref_typeid($argtype)) {
          my $sigil = $ref_type_index_to_symbol[$argtype];
          my $refaddr = refaddr($arg);
          # avoid problems with '%' being interpreted as a formatting escape:
          if ($sigil eq '%') { $sigil = '%%'; }
          $arg = M.$sigil.B.((defined $refaddr) ? sprintf('0x%lx', $refaddr) : '<?>');
        } elsif (($argtype == STRING) || ($argtype == DUAL)) {
          $arg = format_quoted(C.$arg);
        } else {
          $arg = G.$arg;
        }
      }

      $args = K.' ('.G.join(K.', '.C, @arglist).K.')';
    }
      
    my $package_and_function = B.(is_there($package) ? $package.'::' : '').C.$function;

    my $filename_sep = Y_1_2.large_right_slash.Y;
    $filename =~ s{/}{$filename_sep}oamsxg;

    my $s = 
      K.' '.dot.' '.B.padstring($package_and_function, $longest_package_and_function_name).
        K.' from '.Y.$filename.K.':'.M.$line;

    if ((printed_length($s) + printed_length($args)) <= $max_width) { $s .= $args; }
    $s .= X.NL;
    $out .= $s;
  }
    
  return $out;
}

sub die_or_warn_in_color($$;@) {
  my $type = shift;
  my $do_include_stack_backtrace = shift;

  $do_include_stack_backtrace //= $include_stack_backtrace;
  my $is_warn = ($type eq 'WARNING') ? 1 : 0;
  $warning_count_so_far += $is_warn;

  if ($is_warn && (defined $abort_on_warnings) && ($warning_count_so_far >= $abort_on_warnings)) {
    $type = 'ERROR';
    $is_warn = 0;
  }

  if (!$is_warn) { $do_include_stack_backtrace = 1; }

  my $m = $_[0] // '(unknown)';
  chomp $m;

  my $warning_line_count = 0;
  
  if ($is_warn) {
    $max_warning_line_count //= get_terminal_height_in_lines();

    $already_printed_warning_messages{$m}++;
    my $repeats = $already_printed_warning_messages{$m};

    if (($warning_count_so_far >= $max_warning_count) ||
          ($warning_line_count_so_far >= $max_warning_line_count) ||
            ($repeats > 1)) {
      my $excess = max($warning_count_so_far - $max_warning_count, 0);
      my $divisor = 
        ($excess < $max_warning_count) ? 1 : 
        ($excess < $max_warning_count*10) ? 10 :
        ($excess < $max_warning_count*50) ? 50 : 100;

      if (($warning_count_so_far % $divisor) == 0) {
        printfd(STDERR, $R.'('.$U.'Warning:'.$UX.' '.$warning_count_so_far. ' '.$Y.$U.
                'WARNING'.$UX.$R.' messages silenced)'.$X.NL);
      }
      goto update_warning_counts;
    }
  }

  if (!is_stderr_color_capable()) {
    if ($is_warn) { 
      $warning_line_count = ((scalar @_) > 0) ? count_lines(@_) : 1;
      warn @_;
      goto update_warning_counts; 
    } else { 
      die @_; 
    }
  }

  # This is redundant in the error message 
  # since it's also in the stack backtrace:
  $m =~ s{\s at \s ((?: (?> \( [^\)]+ \)) | \S+)) \s line \s (\d+)\.?}{\n${K}in $Y$1$K:$M$2$K}oamsxg;
  $m =~ s{\$ $perl_package_and_identifier_re \b}{${B}${1}${G}\$${2}${R}}oamsxg;

  my $backtrace = ($do_include_stack_backtrace) ? format_stack_backtrace() : undef;

  my $warning_color = fg_color_rgb(255, 255, 0);
  my $error_color = fg_color_rgb(255, 192, 0); # bright red-orange

  my $prefix = 
    (($is_warn) ? $warning_color.warning_sign : $error_color.x_symbol) . ' ';

  my $message = '%{tab}'.$prefix.($is_warn ? $warning_color : $error_color).$type;

  # if ($is_warn && ($max_warning_line_count < INT_MAX))
  #   { $message .= '  '.$R.'#'.$warning_line_count_so_far; }
  $message .= ' '.NL;
  $message .= R.$m.X.NL;
  if (!$is_warn) { $message .= NL.K.'('.G.$0.R.' has been terminated.'.$K.')'.NL; }

  if (defined $backtrace) {
    $message .= '%{div=dashed}'.NL.
      G.U.'Stack backtrace'.$X.$K.' (after point of origin shown above):'.X.NL.
        $backtrace.NL;
  }

  my $boxtype = ($is_warn) ? 'rounded' : 'heavy';

  my $divtype = 
    ($is_warn) ? 'single' : 'double';

  $message = text_in_a_box($message, ALIGN_LEFT, ($is_warn ? Y : R), $boxtype, $divtype, ' ', $box_width).X.NL;

  $warning_line_count = count_lines($message);
  printfd(STDERR, $message);

  update_warning_counts:
  if ($is_warn) {
    $warning_line_count_so_far += $warning_line_count;
    
    if (($warning_count_so_far == $max_warning_count) ||
          ($warning_line_count_so_far == $max_warning_line_count)) {
      printfd(STDERR, NL.R.'(Warning: '.R.$warning_count_so_far.
              ' '.Y.U.'WARNING'.$UX.R.' messages occupying '.
                $warning_line_count_so_far.
                ' lines have already been reported; '.Y.U.
                'silencing any subsequent warnings'.UX.R.')'.X.NL.NL);
    }
  }

  if (!$is_warn) { exit(255); }
  return 1;
}

sub die_in_color {
  die @_ if $^S; # if we're called from inside an eval { ... }
  die_or_warn_in_color('ERROR', $include_stack_backtrace, @_);
}

sub warn_in_color {
  die @_ if $^S; # if we're called from inside an eval { ... }
  die_or_warn_in_color('WARNING', $include_stack_backtrace, @_);
}

sub warn_without_stack_trace { 
  die_or_warn_in_color('WARNING', 0, @_); 
}

sub die_and_print($$;$) {
  die @_ if $^S; # if we're called from inside an eval { ... }
  my ($primary_error, $postmortem_message, $include_backtrace) = @_;

  die_or_warn_in_color('ERROR', $include_backtrace // 1, $primary_error);
  printfd(STDERR, $postmortem_message);
  exit(255);
}

INIT {
  my $this_package = __PACKAGE__;
  my $env_var_name = $this_package =~ s/::/_/roaxg;
  my $config = $ENV{$env_var_name};
  my $disabled = 0;

  if (is_there($config)) {
    my $options = parse_list_of_key_equals_value_into_hash($config);
    if (($options->{enabled} // 1) == 1) { $disabled = 0; }
    if (exists $options->{disabled}) { $disabled = 1; }
    my $aow = $options->{max_warning_count} // $options->{abort_on_warnings};
    if (defined $aow) { $abort_on_warnings = $aow; }
  }
  
  $skip_packages_and_functions_in_stack_backtrace{$this_package} = 1;

  if (!$disabled) {
    $SIG{__DIE__} = \&die_in_color;
    $SIG{__WARN__} = \&warn_in_color;
  }
};
