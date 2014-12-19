#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Display::ColorCapabilityCheck
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#
# Colorize: ANSI console colors and attributes for any terminal
# (works with Linux console, XTerm, Mac OS X, BSD, Solaris, etc)
#

package MTY::Display::ColorCapabilityCheck;

use integer; use warnings; use Exporter::Lite;

nobundle:; our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(%consumer_command_color_capabilities %terminal_name_to_color_capabilities
     @color_capable_interactive_viewers
     @disable_color_when_piped_to_these_consumers ANSI_COLOR_CAPABLE
     ENHANCED_RGB_COLOR_CAPABLE NOT_COLOR_CAPABLE colorize_debug_log
     get_console_control_fd is_console_color_capable
     is_filehandle_color_capable is_stderr_color_capable
     is_stdout_color_capable);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Common::EnvVarDefaults;
use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::ProcFS;
use MTY::Filesystem::OpenFiles;
use MTY::System::Misc;
use MTY::Display::Colorize;

BEGIN {

# See notes below for how and when to add program names to this:
# Default is to use color when stdout is piped to one of these:
# (color usage can be forced by simply piping through cat):
our @color_capable_interactive_viewers = 
  qw(less more head tail pr fold cat tac colorize incolor nocolor-cond);

# Default is to disable color when stdout is piped to one of these:
our @disable_color_when_piped_to_these_consumers = 
  #
  # Rules for which consumer programs should not receive colorized input:
  #
  # - Piping ANSI color escape codes to grep and other text processing
  #   utilities (including perlre itself) often prevents it from matching 
  #   text that appears to obviously be there, but doesn't quite match
  #   because of the color codes (which will be confusingly hidden if
  #   the program consuming stdout itself highlights things in color).
  #
  # - Obviously anything thats used as input to a compiler
  #   is source code that cannot contain color escape codes
  #
  # - Only colorize the last instance of perlre in a pipeline
  #
  qw(perlre nocolor
     pcregrep grep fgrep egrep jrep
     awk sed subst find xargs
     patch diff diff3 sdiff
     gzip bzip2 xz
     fmt split csplit wc
     sum cksum md5sum sha1sum sha2
     sort shuf uniq comm ptx tsort
     cut paste join tr expand unexpand
     hex od
     g++ gcc cpp cc1 cc1plus clang clang++ as);

our %consumer_command_color_capabilities = ( );

foreach my $cmd (@color_capable_interactive_viewers) 
  { $consumer_command_color_capabilities{$cmd} = 1; }
foreach my $cmd (@disable_color_when_piped_to_these_consumers) 
  { $consumer_command_color_capabilities{$cmd} = 0; }

}; # (end of BEGIN block)

# Terminals which can handle at least the ANSI SGR 16-color escapes:
our %terminal_name_to_color_capabilities = (
  linux => 1,
  xterm => 2,
  konsole => 2,
  terminal => 2,
  gnometerminal => 2,
  rxvt => 2,
  vt420 => 1,
  putty => 1);

my @fd_color_capabilities = [ ];

use constant {
  NOT_COLOR_CAPABLE => 0,
  ANSI_COLOR_CAPABLE => 1,
  ENHANCED_RGB_COLOR_CAPABLE => 2,
};

my $debug_colorize = 0;
my $colorize_env_var = '';

sub colorize_debug_log($) {
  return if (!$debug_colorize);
  my ($message) = $_[0];
  chomp $message;
  $message =~ s{^}{[colorize debug] }oamsxg;
  print(STDERR $message.NL);
}

sub is_filehandle_color_capable($) {
  my ($handle_or_fd) = @_;
  my $fd = get_native_fd($handle_or_fd) // -1;
  if ($fd < 0) { return 0; }

  if (defined $fd_color_capabilities[$fd])
    { return $fd_color_capabilities[$fd]; }

  #
  # Only use color mode and fancy symbols if the specified file descriptor
  # for this process is actually connected to one of the following:
  #
  # 1. an actual interactive terminal (e.g. /dev/pts/*) which is of a type
  #    known to support ANSI color escapes. The terminal type is preferably
  #    obtained from the REMOTE_TERMINAL environment variable, which your
  #    system's shell scripts should set to the title of the terminal's X11
  #    window itself. The get-terminal-window-title script and the $WINDOWID
  #    environment variable will be useful for this - just make sure ssh
  #    forwards $WINDOWID to the remote host using SendEnv and AcceptEnv!).
  #    If $REMOTE_TERMINAL isn't set, we fall back to $TERM instead, but
  #    this may under-represent the remote terminal's capabilities.
  #
  #    The %color_capable_terminals hash should have a lower-case string
  #    for any terminal types that can handle at least ANSI SGR 16 color
  #    mode, and optionally also in %enhanced_color_capable_terminals if
  #    the terminal can handle 256 color mode or true R/G/B mode. This
  #    code will automatically use 16 color ANSI SGR mode if the terminal
  #    name contains '-16color', or 256 color RGB mode if it contains
  #    '-256color'.
  #
  # ... *OR* the file descriptor must be connected to:
  #
  # 2. a pipe leading to a so-called "interactive viewer" process "P" which
  #    satisfies both of the following criteria:
  #
  #    - we can accurately identify P's PID and command name using 
  #      MTY::Filesystem::ProcFS::get_pid_of_first_consumer_of_stdout() (see the 
  #      comments on that function for more details). Our definition of the
  #      "command name" is the executable file name, or if the command is a
  #      perl script, shell script or other interpreted code, the command
  #      name is the name of the script rather than the interpreter itself.
  #
  #    - P's command name is found on our pre-defined list of well known 
  #      "interactive viewer" commands, represented by the 
  #      %color_capable_interactive_viewers hash.
  #
  #      In this hash, each element (or regexp pattern) is the command name 
  #      only (without its full path). Before checking this hash, the command
  #      name is converted to lower case and stripped of any characters not
  #      in the class [\w] (i.e. only word characters are retained). The key
  #      for scripts (perl, sh, etc) using '#!/path/to/interpreter' is the
  #      name of the script itself, not its interpreter binary. 
  #
  #      In contrast, the %disable_color_when_piped_to_these_consumers hash
  #      should match any commands that are *not* color capable so colorized 
  #      output should be disabled. 
  #
  #      If the command matches neither hash, we assume it is NOT color capable.
  #
  #      This approach presently considers utilities like 'less', 'head', 'tail',
  #      'watch', etc. to be color capable (all mapped to a value of 1), whereas 
  #      most other consumers expect straight uncolorized output and are
  #      obviously not going to tolerate color escape codes gracefully, 
  #      so color will be disabled if we're piped to them.
  #
  #      To force color codes to be retained, simply pipe the output through 'cat',
  #      which is in %color_capable_interactive_viewers (since there is no other
  #      practical reason for piping anything through cat, this is a convenient
  #      way of telling this module to enable the color codes unconditionally).
  #

  my $colorterm = $ENV{'COLORTERM'} // '';
  if ($colorterm =~ /^\d+$/oax) { $colorterm = 'xterm-256color'; }

  my $origterminal = lc(first_specified($ENV{'REMOTE_TERMINAL'}, $ENV{'TERM'}, $ENV{'COLORTERM'}, 'dumb'));
  # normalize the command names by removing
  # versions (e.g. name-2.3) and all but A-Z:
  my $terminal = ($origterminal =~ s/[\d\W\_]|color//roamsxg);

  my $terminal_color_capabilities = $terminal_name_to_color_capabilities{$terminal};
  if (!defined($terminal_name_to_color_capabilities)) {
    # exact match not found, so try to search for known terminal type names
    # as a substring of the full terminal name:
    foreach my $k (keys %terminal_name_to_color_capabilities) {
      my $v = $terminal_name_to_color_capabilities{$k};
      if (contains($terminal, $k)) { $terminal_color_capabilities = $v; last; }
    }
    # if (!defined($terminal_color_capabilities)) { print(STDERR '[colorize debug] not def for fd'.NL); }
    $terminal_color_capabilities //= 0;
  }

  if ((!$terminal_color_capabilities) && ($origterminal =~ /(\d+)-?color/oamsxg))
    { $terminal_color_capabilities = ($1 eq '256') ? 2 : 1; }

  if ($debug_colorize) {
    my %fd_to_description = (0 => 'stdin', 1 => 'stdout', 2 => 'stderr');
    colorize_debug_log(
      ('-' x 60).NL.
      'Checking color capabilities of fd '.$fd.' ('.($fd_to_description{$fd} // 'non-stdio').'):'.NL.
      ('-' x 60).NL.
      'REMOTE_TERMINAL env var = "'.($ENV{REMOTE_TERMINAL} // '<undef>').'"'.NL.
      'COLORTERM env var = "'.($ENV{COLORTERM} // '<undef>').'"'.NL.
      'TERM env var = "'.($ENV{TERM} // '<undef>').'"'.NL.
      'effective terminal type = "'.$origterminal.'"'.NL.
      'terminal_color_capabilities = '.$terminal_color_capabilities.NL);
  }

  my $fdtype = get_fd_type($fd);

  if (isatty($fd)) {
    colorize_debug_log('fd '.$fd.' is a terminal => capabilities = '.
                   $terminal_color_capabilities);
    $fd_color_capabilities[$fd] = $terminal_color_capabilities;
  } elsif ($fdtype == FILE_TYPE_FILE) {
    colorize_debug_log('fd '.$fd.' is redirected into a file: color disabled');
    # fd is redirected to an ordinary file: don't use color (unless we force it on)
    $fd_color_capabilities[$fd] = 0;
  } elsif ($fdtype == FILE_TYPE_PIPE) {
    # find the pid of the next command in the pipeline after us:
    my $consumer_pid = get_pid_of_first_consumer_of_fd($fd);
    colorize_debug_log('fd '.$fd.' is piped to '.
                   'stdin of pid '.($consumer_pid // '<unknown>')); 
    # fd is a pipe, but no one seems to be reading from it (very unusual but possible):
    if (!defined($consumer_pid)) {
      colorize_debug_log('cannot determine consumer pid at end '.
                     'of pipe connected to fd '.$fd.': color disabled');

      $fd_color_capabilities[$fd] = 0;
      return 0;
    }
    
    my $origcmd = lc(get_real_command_name_of_pid($consumer_pid));

    # normalize the command names by removing
    # versions (e.g. name-2.3) and all but A-Z:
    my $shortcmd = ($origcmd =~ s/[\d\W\_]//roamsxg);
    my $c = $consumer_command_color_capabilities{$shortcmd} // 0;

    colorize_debug_log(
      'command or executable with consumer pid '.
      $consumer_pid.' = '.$origcmd.' (short form "'.$shortcmd.'") => '.
      'capabilities = '.$c);

    $fd_color_capabilities[$fd] = ($c) ? $terminal_color_capabilities : 0;
  } else {
    colorize_debug_log('fd '.$fd.' is neither a terminal, '.
      'nor a file, nor a pipe: color disabled');
    
    $fd_color_capabilities[$fd] = 0;
  }

  colorize_debug_log('returning capabilities '.$fd_color_capabilities[$fd].
                 ' for fd '.$fd.NL);

  return $fd_color_capabilities[$fd];
}

my $console_fd = undef;
my $console_dev_path = undef;

sub get_console_control_fd() {
  if (defined $console_fd) 
    { return ($console_fd >= 0) ? $console_fd : undef; }

  $console_dev_path = get_terminal_char_dev_path();

  if (!is_there($console_dev_path)) { 
    colorize_debug_log('get_console_control_fd(): get_terminal_char_dev_path() '.
      'failed to return the console device node path');
    $failed_to_open_console_fd = 1; return undef;
  }

  colorize_debug_log('get_console_control_fd(): current terminal\'s '.
    'character device node path = '.$console_dev_path);

  colorize_debug_log('STDOUT refers to '.(path_of_open_fd(STDOUT_FD) // '<closed>'));
  colorize_debug_log('STDERR refers to '.(path_of_open_fd(STDERR_FD) // '<closed>'));

  $console_fd = sys_open($console_dev_path, O_RDWR);

  if (!defined $console_fd) {
    colorize_debug_log('get_console_control_fd(): cannot open '.$console_dev_path);
    $console_fd = -1;
    return undef;
  }

  return $console_fd;
}

my $console_color_capabilities = undef;

sub is_console_color_capable() {
  if (defined $console_color_capabilities) {
    return $console_color_capabilities;
  }

  $console_color_capabilities = 0;
  my $fd = get_console_control_fd();
  if (!defined $fd) { return 0; }
  $console_color_capabilities = is_filehandle_color_capable($fd);
  return $console_color_capabilities;
}

sub is_stdout_color_capable() { return is_filehandle_color_capable(STDOUT); }
sub is_stderr_color_capable() { return is_filehandle_color_capable(STDERR); }

INIT {
  my $disable = undef;
  my $enable = undef;
  my $enhanced = undef;

  my %colorize_defaults = get_defaults_from_env({ 
    debug => \$debug_colorize,

    disable => \$disable,
    disabled => \$disable,
    nocolor => \$disable,
    off => \$disable,
    no => \$disable,

    enable => \$enable,
    color => \$enable,
    on => \$enable,
    yes => \$enable,

    enhanced => \$enhanced,
  }, 'COLORIZE');

  if (scalar keys %colorize_defaults) {
    colorize_debug_log('COLORIZE environment variable set to "'.$colorize_defaults{''}.'":');
    while (my ($key, $value) = each %colorize_defaults) { colorize_debug_log('  '.$key.' = '.$value); }

    if ($debug_colorize) { colorize_debug_log('enabled debugging of color capabilities checking'); }

    $disable = (defined $disable) ? ($boolean_words{$disable} // 1) : 0;

    if ($disable) {
      foreach my $fd (STDOUT_FD, STDERR_FD) 
        { $fd_color_capabilities[$fd] = 0; }

      for (my $i = 255; $i >= 0; $i--) { $fd_color_capabilities[$i] = 0; }
        colorize_debug_log('COLORIZE environment variable has unconditionally '.
                           'disabled color output on all file descriptors');
    }

    $enable = (defined $enable) ? ($boolean_words{$enable} // 1) : 0;

    $enhanced = (defined $enhanced) ? ($boolean_words{$enhanced} // 1) : 0;
    $enable |= $enhanced;

    if ($enable || $disable) {
      foreach my $fd (STDOUT_FD, STDERR_FD) 
        { $fd_color_capabilities[$fd] = ($enable) ? (($enhanced) ? 2 : 1) : ($disable) ? 0 : undef; }
      colorize_debug_log('COLORIZE environment variable has unconditionally '.
                           ($enable ? 'enabled' : $disable ? 'disabled' : undef).
                           ($enhanced ? ' enhanced' : '').
                           ' color output on all file descriptors');
    }
  }
};

1;
