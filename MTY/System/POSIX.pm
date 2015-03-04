#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::System::POSIX
#
# Copyright 2002 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::System::POSIX;

use integer; use warnings; use Exporter qw(import);
use Symbol;
require 'syscall.ph';

my @POSIX_symbols;
my @POSIX_2008_symbols;
my @Fcntl_symbols;

BEGIN {
  @POSIX_symbols = 
    qw(clock ctermid cuserid difftime isatty mktime nice
       setpgid rewinddir setsid tcsetpgrp times uname strftime getgroups
       ARG_MAX B0 B110 B1200 B134 B150 B1800 B19200 B200 B2400 B300
       B38400 B4800 B50 B600 B75 B9600 BRKINT BUFSIZ CHAR_BIT CHAR_MAX
       CHAR_MIN CHILD_MAX CLK_TCK CLOCAL CLOCKS_PER_SEC CREAD CS5 CS6 CS7
       CS8 CSIZE CSTOPB DBL_DIG DBL_EPSILON DBL_MANT_DIG DBL_MAX
       DBL_MAX_10_EXP DBL_MAX_EXP DBL_MIN DBL_MIN_10_EXP DBL_MIN_EXP EOF
       EXIT_FAILURE EXIT_SUCCESS FD_CLOEXEC FILENAME_MAX FLT_DIG
       FLT_EPSILON FLT_MANT_DIG FLT_MAX FLT_MAX_10_EXP FLT_MAX_EXP FLT_MIN
       FLT_MIN_10_EXP FLT_MIN_EXP FLT_RADIX FLT_ROUNDS F_DUPFD F_GETFD
       F_GETFL F_GETLK F_OK F_RDLCK F_SETFD F_SETFL F_SETLK F_SETLKW
       F_UNLCK F_WRLCK HUGE_VAL HUPCL ICANON ICRNL IEXTEN IGNBRK IGNCR
       IGNPAR INLCR INPCK INT_MAX INT_MIN ISIG ISTRIP IXOFF IXON LC_ALL
       LC_COLLATE LC_CTYPE LC_MESSAGES LC_MONETARY LC_NUMERIC LC_TIME
       LDBL_DIG LDBL_EPSILON LDBL_MANT_DIG LDBL_MAX LDBL_MAX_10_EXP
       LDBL_MAX_EXP LDBL_MIN LDBL_MIN_10_EXP LDBL_MIN_EXP LINK_MAX LONG_MAX
       LONG_MIN L_ctermid L_cuserid L_tmpname MAX_CANON MAX_INPUT
       MB_CUR_MAX MB_LEN_MAX NAME_MAX NCCS NGROUPS_MAX NOFLSH NULL
       OPEN_MAX OPOST O_ACCMODE O_APPEND O_CREAT O_EXCL O_NOCTTY O_NONBLOCK
       O_RDONLY O_RDWR O_TRUNC O_WRONLY PARENB PARMRK PARODD PATH_MAX
       PIPE_BUF RAND_MAX R_OK SA_NOCLDSTOP SA_NOCLDWAIT SA_NODEFER
       SA_ONSTACK SA_RESETHAND SA_RESTART SA_SIGINFO SCHAR_MAX SCHAR_MIN
       SEEK_CUR SEEK_END SEEK_SET SHRT_MAX SHRT_MIN SIGABRT SIGALRM SIGBUS
       SIGCHLD SIGCONT SIGFPE SIGHUP SIGILL SIGINT SIGKILL SIGPIPE SIGPOLL
       SIGPROF SIGQUIT SIGRTMAX SIGRTMIN SIGSEGV SIGSTOP SIGSYS SIGTERM
       SIGTRAP SIGTSTP SIGTTIN SIGTTOU SIGURG SIGUSR1 SIGUSR2 SIGVTALRM
       SIGXCPU SIGXFSZ SIG_BLOCK SIG_DFL SIG_ERR SIG_IGN SIG_SETMASK
       SIG_UNBLOCK SSIZE_MAX STDERR_FILENO STDIN_FILENO STDOUT_FILENO
       STREAM_MAX S_IRGRP S_IROTH S_IRUSR S_IRWXG S_IRWXO S_IRWXU S_ISGID
       S_ISUID S_IWGRP S_IWOTH S_IWUSR S_IXGRP S_IXOTH S_IXUSR TCIFLUSH
       TCIOFF TCIOFLUSH TCION TCOFLUSH TCOOFF TCOON TCSADRAIN TCSAFLUSH
       TCSANOW TMP_MAX TOSTOP TZNAME_MAX UCHAR_MAX UINT_MAX ULONG_MAX
       USHRT_MAX VEOF VEOL VERASE VINTR VKILL VMIN VQUIT VSTART VSTOP VSUSP
       VTIME WNOHANG WUNTRACED W_OK X_OK _PC_CHOWN_RESTRICTED _PC_LINK_MAX
       _PC_MAX_CANON _PC_MAX_INPUT _PC_NAME_MAX _PC_NO_TRUNC _PC_PATH_MAX
       _PC_PIPE_BUF _PC_VDISABLE _POSIX_ARG_MAX _POSIX_CHILD_MAX
       _POSIX_CHOWN_RESTRICTED _POSIX_JOB_CONTROL _POSIX_LINK_MAX
       _POSIX_MAX_CANON _POSIX_MAX_INPUT _POSIX_NAME_MAX _POSIX_NGROUPS_MAX
       _POSIX_NO_TRUNC _POSIX_OPEN_MAX _POSIX_PATH_MAX _POSIX_PIPE_BUF
       _POSIX_SAVED_IDS _POSIX_SSIZE_MAX _POSIX_STREAM_MAX
       _POSIX_TZNAME_MAX _POSIX_VDISABLE _POSIX_VERSION _SC_ARG_MAX
       _SC_CHILD_MAX _SC_CLK_TCK _SC_JOB_CONTROL _SC_NGROUPS_MAX
       _SC_OPEN_MAX _SC_PAGESIZE _SC_SAVED_IDS _SC_STREAM_MAX
       _SC_TZNAME_MAX _SC_VERSION); 

  @POSIX_2008_symbols = 
    qw(basename clock_getcpuclockid clock_getres clock_gettime
       clock_nanosleep clock_settime dirname ffs getdate getdate_err
       gethostid gethostname getitimer getpriority getsid killpg
       mkdtemp mkstemp nanosleep pread ptsname pwrite setegid
       setitimer setpriority setregid setreuid mkdir mkdirat acos
       acosh asin asinh atan2 atan atanh atof atoi atol cbrt ceil cos
       cosh div erand48 erf exp2 expm1 fdim fegetround fesetround
       floor fma fmax fmin fmod fnmatch fpclassify hypot ilogb isinf
       isnan jrand48 ldexp ldiv lgamma log2 logb lrand48 mrand48
       nearbyint nextafter nrand48 remainder round scalbn seed48
       copysign signbit sinh srand48 srandom tan tanh getgid getuid
       getegid geteuid fchdir 
       AT_EACCESS AT_EMPTY_PATH AT_FDCWD AT_NO_AUTOMOUNT AT_REMOVEDIR
       AT_SYMLINK_FOLLOW AT_SYMLINK_NOFOLLOW BOOT_TIME CLOCK_MONOTONIC
       CLOCK_MONOTONIC_RAW CLOCK_PROCESS_CPUTIME_ID CLOCK_REALTIME
       CLOCK_THREAD_CPUTIME_ID DEAD_PROCESS FNM_CASEFOLD FNM_FILE_NAME
       FNM_LEADING_DIR FNM_NOESCAPE FNM_NOMATCH FNM_PATHNAME FNM_PERIOD
       FP_INFINITE FP_NAN FP_NORMAL FP_SUBNORMAL FP_ZERO INIT_PROCESS
       ITIMER_PROF ITIMER_REAL ITIMER_VIRTUAL LOGIN_PROCESS NEW_TIME
       OLD_TIME O_CLOEXEC O_TMPFILE TIMER_ABSTIME
       USER_PROCESS UTIME_NOW UTIME_OMIT _CS_GNU_LIBC_VERSION
       _CS_GNU_LIBPTHREAD_VERSION _CS_PATH ); 

  @Fcntl_symbols = 
    qw(DN_ACCESS DN_ATTRIB DN_CREATE DN_DELETE DN_MODIFY DN_MULTISHOT
       DN_RENAME FAPPEND FASYNC FCREAT FDEFER FDSYNC FD_CLOEXEC FEXCL
       FLARGEFILE FNDELAY FNONBLOCK FRSYNC FSYNC FTRUNC F_ALLOCSP
       F_ALLOCSP64 F_COMPAT F_DUP2FD F_DUPFD F_EXLCK F_FREESP F_FREESP64
       F_FSYNC F_FSYNC64 F_GETFD F_GETFL F_GETLEASE F_GETLK F_GETLK64
       F_GETOWN F_GETSIG F_NODNY F_NOTIFY F_POSIX F_RDACC F_RDDNY F_RDLCK
       F_RWACC F_RWDNY F_SETFD F_SETFL F_SETLEASE F_SETLK F_SETLK64
       F_SETLKW F_SETLKW64 F_SETOWN F_SETSIG F_SHARE F_SHLCK F_UNLCK
       F_UNSHARE F_WRACC F_WRDNY F_WRLCK LOCK_EX LOCK_MAND LOCK_NB
       LOCK_READ LOCK_RW LOCK_SH LOCK_UN LOCK_WRITE O_ACCMODE O_ALIAS
       O_APPEND O_ASYNC O_BINARY O_CREAT O_DEFER O_DIRECT O_DIRECTORY
       O_DSYNC O_EXCL O_EXLOCK O_IGNORE_CTTY O_LARGEFILE O_NDELAY O_NOATIME
       O_NOCTTY O_NOFOLLOW O_NOINHERIT O_NOLINK O_NONBLOCK O_NOTRANS
       O_RANDOM O_RAW O_RDONLY O_RDWR O_RSRC O_RSYNC O_SEQUENTIAL O_SHLOCK
       O_SYNC O_TEMPORARY O_TEXT O_TRUNC O_WRONLY SEEK_CUR SEEK_END
       SEEK_SET S_ENFMT S_IEXEC S_IFBLK S_IFCHR S_IFDIR S_IFIFO S_IFLNK
       S_IFREG S_IFSOCK S_IFWHT S_IREAD S_IRGRP S_IROTH S_IRUSR S_IRWXG
       S_IRWXO S_IRWXU S_ISGID S_ISTXT S_ISUID S_ISVTX S_IWGRP S_IWOTH
       S_IWRITE S_IWUSR S_IXGRP S_IXOTH S_IXUSR _S_IFMT 
       S_ISREG S_ISDIR S_ISLNK S_ISSOCK S_ISBLK S_ISCHR S_ISFIFO
       S_ISWHT S_ISENFMT);
};

use POSIX (@POSIX_symbols);
use POSIX::2008 (@POSIX_2008_symbols);
use Fcntl (@Fcntl_symbols);
use Errno (@Errno::EXPORT, @Errno::EXPORT_OK);
use IO::Dirent qw(readdirent);
# use IO::Dir::Dirfd qw(fileno);

#pragma end_of_includes

# Determine if the Perl environment uses 32-bit or 64-bit data types:
use constant {
  NATIVE_BIT_WIDTH => (((~0) == 0xffffffff) ? 32 : 64),
};

use constant {
  PLATFORM_32_BIT => (NATIVE_BIT_WIDTH == 32),
  PLATFORM_64_BIT => (NATIVE_BIT_WIDTH == 64),
};


# Defined by the latest Linux kernels but not yet in the Perl definitions:
use constant O_PATH => 010000000;

# These are subject to masking by the current umask:
use constant {
  DEFAULT_DIR_PERMS  => 0755, # i.e. drwxr-xr-x
  DEFAULT_FILE_PERMS => 0644, # i.e. -rw-r--r--
};

my $absolute_path_re = qr{\A /}oamsx;

#
# Perl will cache the value returned by getpid(), and will also keep
# this cached pid up to date even across forks, so we use it instead
# of calling POSIX::getpid() ourselves:
#
sub getpid() { return $$; }

sub is_file_handle {
  return (defined fileno($_[0])) ? 1 : 0;
}

sub dirfd {
  # return IO::Dir::Dirfd::fileno($_[0]);
}

sub get_native_fd {
  return (defined $_[0]) ? (fileno($_[0]) // $_[0]) : undef;
}

#
# Work around broken POSIX::2008 readlink bug (doesn't add null terminator
# at the end of the returned symlink target, but the readlink()/readlinkat()
# syscalls don't null terminate it either, thus resulting in possible
# memory corruption or even an exploitable buffer overflow.
#
# Since there's no easy way to detect if the POSIX::2008 module lacks the
# fix for this bug, this workaround must be manually enabled below via
# the typeglob alias to readlink() and readlinkat() below:
#
sub readlinkat_via_direct_syscall($$) {
  my ($fd, $path) = @_;
  my $buf = chr(0) x PATH_MAX;
  my $rc = syscall(&SYS_readlinkat, $fd, $path, $buf, PATH_MAX-1);
  if ($rc < 0) { return undef; }
  # force it to be null terminated the perl way:
  $buf = substr($buf, 0, $rc);
  return $buf;
}

#
# Quickly determines the type of the filesystem object specified by
# $relative_path relative to the path of $base_dir_fd if specified,
# or relative to the current directory otherwise, unless $relative_path
# is absolute (i.e. it starts with "/").
#
# Returns:
# +1 if the target is a symlink,
#  0 if it is a regular file, directory or any other non-symlink type
# -1 if it doesn't even exist
#
sub path_is_symlink($;$) {
  my ($relative_path, $base_dir_fd) = @_;
  $relative_path //= '';
  my $symlink = sys_readlinkat($base_dir_fd // AT_FDCWD, $relative_path);
  my $rc = (defined $symlink) ? 0 : -$!;
  
  #
  # If the errno from readlinkat was EINVAL (Invalid argument), 
  # this explicitly means the file did in fact exist, but was
  # not a symbolic link (i.e. it was a regular file, directory
  # or some other type that doesn't provide path redirection). 
  #
  # All other error codes mean the specified path didn't exist
  # or at least the caller cannot access it.
  #
  $rc = ($rc >= 0) ? +1 : ($rc == -(EINVAL)) ? 0 : -1;
  return (wantarray ? ($rc, $symlink) : $rc);
}

my $strip_last_path_component_re =
  qr{(?> \A / \K | /?) [^/]++ /*+ \Z}oamsx;

sub clock_gettime_nsec() {
  my ($sec, $nsec) = POSIX::2008::clock_gettime();
  return ($sec * 1000000000) + $nsec;
}

sub clock_nanosecs() {
  my ($sec, $nsec) = clock_gettime(CLOCK_REALTIME);
  return ($sec * 1000000000) + $nsec;
}

sub inode_and_type_of_dir_entry($) {
  my ($e) = @_;
  return (
    ($e & ((1 << 60) - 1)), 
    (($e >> 60) & 0xf),
  );
}
 
sub sys_readdir_ext($) {
  my ($fd) = @_;
  return (map { $_->{name} => (($_->{inode} & ((1 << 60) - 1)) | ($_->{type} << 60)) } readdirent($fd));
}

my $open_path_default_flags = O_PATH | O_RDONLY | O_CLOEXEC;

my @path_of_open_fd_cache;

sub sys_open_path($;$$) {
  my ($dir, $basefd, $flags) = @_;

  $basefd //= AT_FDCWD;
  $flags //= O_DIRECTORY; # O_PATH is most commonly used on directories

  #
  # First try to open the path with O_PATH, then fall back
  # to opening it without O_PATH if O_PATH isn't supported:
  #
  my $fd = POSIX::2008::openat($basefd, $dir, $flags | $open_path_default_flags) // -$!;

  #
  # This kernel version doesn't seem to support O_PATH, so 
  # don't try to use this performance optimization next time:
  #

  if ($fd == -(EINVAL)) {
    warn('sys_open_path: O_PATH not supported by this kernel version; reverting to openat() instead');
    $open_path_default_flags ^= O_PATH;
    $fd = POSIX::2008::openat($basefd, $dir, $flags | $open_path_default_flags) // -$!;
  }

  if ($fd < 0) {
    if (($fd == -(EMFILE)) || ($fd == -(ENFILE))) 
      { die("sys_open_path: too many open file descriptors"); }
    
    return undef;
  }
  
  #
  # Only determine this if we later query it, but make sure it's reset
  # so we don't return a stale cached path (since we don't clear this
  # on sys_close()).
  #
  $path_of_open_fd_cache[$fd] = undef;

  return $fd;
}

my $proc_self_fd_fd = undef;

noexport:; sub open_proc_self_fd_fd() {
  if (!defined $proc_self_fd_fd) { 
    $proc_self_fd_fd = POSIX::2008::open('/proc/self/fd/', O_DIRECTORY|O_RDONLY);
    die('Cannot open /proc/self/fd/') if (($proc_self_fd_fd // -1) < 0);
    $path_of_open_fd_cache[$proc_self_fd_fd] = '/proc/'.getpid().'/fd';
  }

  return $proc_self_fd_fd;
}

sub uncached_path_of_open_fd($) {
  my ($fd) = @_;
  if (!defined $fd) { return undef; }
  # if ($fd == AT_FDCWD) { return sys_getcwd(); }
  $proc_self_fd_fd //= open_proc_self_fd_fd();
  return sys_readlinkat($proc_self_fd_fd, $fd);
}

sub path_of_open_fd($) {
  my ($fd) = @_;

  if (!defined $fd) { return undef; }

  # if ($fd == AT_FDCWD) { return sys_getcwd(); }
  $proc_self_fd_fd //= open_proc_self_fd_fd();

  my $path = $path_of_open_fd_cache[$fd];

  if (!defined $path) { 
    $path = sys_readlinkat($proc_self_fd_fd, $fd); 
    $path_of_open_fd_cache[$fd] = $path;
  }

  return $path;
}

#
# The following hook functions are injected into the core Perl symbol table
# so they will be invoked first whenever literally any other code (whether
# written in Perl and/or C/XS/etc. interfacing with Perl) subsequently 
# attempts to use these functions.
#
# These hooks are necessary to maintain the coherence and correctness of
# the $path_of_open_fd_cache[] array, since the hooks intercept every call
# which could possibly result in a file descriptor suddenly referring to
# another file instead of whatever was cached in $path_of_open_fd_cache.
#
# Specifically, all flavors of open (open(), sysopen(), opendir()), close
# (close(), closedir()) and dup (dup(), dup2()) are intercepted. The hook
# functions for these essentially just determine which argument and/or 
# result refers to a file descriptor (translating from a Perl handle with
# fileno($handle) as needed), then undefines $path_of_open_fd_cache[$fd],
# and finally jumps directly to the original Perl provided function.
#
sub invalidate_cached_path_for_fd {
  return if (!defined $_[0]);
  my $fd = get_native_fd($_[0]);
  
  # print(STDERR 'Invalidating mapping of fd ', $fd, ' to cached path ',
  #   ((defined $fd) ? ($path_of_open_fd_cache[$fd] // '<not cached>') : '<fd undefined>'), "\n");

  return if (!defined $fd);
  $path_of_open_fd_cache[$fd] = undef;
}

our @invalidate_cached_fd_hooks;
our @invalidate_cached_readonly_fd_hooks;
our @invalidate_cached_path_hooks;

INIT {
  @invalidate_cached_readonly_fd_hooks = ( \&invalidate_cached_path_for_fd );
  @invalidate_cached_fd_hooks = ( );
  @invalidate_cached_path_hooks = ( );
};

# Invalidate any cached metadata associated with the specified path:
sub call_invalidate_cached_path_hooks
  { foreach my $func (@invalidate_cached_path_hooks) { $func->(@_); } }

# Invalidate any cached metadata associated with this fd, since it may be 
# modified, in addition to invalidating any read-only fd <-> path mappings:
sub call_invalidate_cached_fd_hooks {
  foreach my $func (@invalidate_cached_readonly_fd_hooks) { $func->(@_); } 
  foreach my $func (@invalidate_cached_fd_hooks) { $func->(@_); } 
}

# Only invalidate any cached mappings between the fd and its filesystem path:
sub call_invalidate_cached_readonly_fd_hooks 
  { foreach my $func (@invalidate_cached_readonly_fd_hooks) { $func->(@_); } }

my $perl_open_mode_re = 
    qr{\A ([\<\>\+\-\&\|]*+)}oamsx;

my $perl_pipe_open_mode_re = 
    qr{(?> \A [\<\>\+\-\&]*+ \|) | (?> \| \Z)}oamsx;

my $perl_write_file_modes_re =
    qr{[\>\+]}oamsx;

my $perl_open_mode_and_filename_re = 
    qr{$perl_open_mode_re (.++) \Z}oamsx;

sub perl_open_hook(*;$@) {
  #
  # Perl's built-in open() function is unusual because callers can pass the
  # *name* of the symbol in their package namespace into which open() should 
  # place the opened file handle. This means we cannot simply invoke the 
  # built-in open() once we've reached this hook function, since this "magic"
  # will be stripped as soon as we do anything with $_[0] (including merely
  # calling the real open() with it). Therefore, the following code manually
  # looks up that symbol in the caller's namespace to avoid this problem:
  #

  if ((defined $_[0]) && (!ref $_[0])) 
    { splice @_, 0, 1, Symbol::qualify_to_ref($_[0], (caller)[0]); }

  my $argc = scalar @_;
  my $mode; my $filename;
  if ($argc <= 2) {
    # 2-arg form: mode and filename are combined into a single argument $_[1]:
    ($mode, $filename) = ($_[1] =~ /$perl_open_mode_and_filename_re/oamsx);
  } else {
    # 3-arg form: mode is in $_[1], filename is in $_[2]
    ($mode, $filename) = @_[1,2];
  }

  my $is_write = ($mode =~ /$perl_write_file_modes_re/oamsx) ? 1 : 0;
  my $is_pipe = ($mode =~ /$perl_pipe_open_mode_re/oamsx) ? 1 : 0;

  # my ($caller_package, $caller_file, $caller_line) = caller(0);
  # 
  # print(STDERR 'perl_open_hook: ', ($caller_file // '?'), ':', 
  #       ($caller_line // '?'), ' (package ', $caller_package, 
  #       ') is opening "', ($filename // '<undef>'), 
  #       '", mode "', $mode, '", argc ', $argc, ', is_write? ', 
  #       $is_write, ', is_pipe? ', $is_pipe, ', target symbol ',
  #       ($_[0] // '<undef>'), "\n");

  if ($is_write && (defined $filename) && (!$is_pipe))
    { call_invalidate_cached_path_hooks($filename); }

  my $result = 
    ($argc == 1) ? CORE::open($_[0]) :
    ($argc == 2) ? CORE::open($_[0], $_[1]) :
    ($argc == 3) ? CORE::open($_[0], $_[1], $_[2]) :
    CORE::open($_[0], $_[1], $_[2], @_[3..($argc-1)]); 

  if ($result && (!$is_pipe)) {
    if ($is_write) { call_invalidate_cached_fd_hooks($_[0]); }
      else { call_invalidate_cached_readonly_fd_hooks($_[0]); }
  }

  # print(STDERR 'perl_open_hook: done opening filename "', ($filename // '<undef>'), 
  #       '", mode "', $mode, '", is_write? ', $is_write, ' => result ',
  #       ($result // '<undef>'), ', handle ', ($_[0] // '<undef>'), ', fd ', 
  #       (fileno($_[0]) // '<undef>'), "\n");

  return $result;
};

sub perl_sysopen_hook(*;$$;$) {
  # See comments above for perl_open_hook():
  if ((defined $_[0]) && (!ref $_[0])) 
    { splice @_, 0, 1, Symbol::qualify_to_ref($_[0], (caller)[0]); }

  my ($filename, $mode, $perms) = @_[1,2,3];
  my $accmode = ($mode & O_ACCMODE);
  my $is_write = (($accmode == O_WRONLY) || ($accmode == O_RDWR) ||
       (($mode & (O_CREAT | O_TRUNC | O_APPEND | O_EXCL)) != 0));

  if ($is_write && (defined $filename)) 
    { call_invalidate_cached_path_hooks($filename); }

  my $result = 
    ($argc == 3) ? CORE::sysopen($_[0], $_[1], $_[2]) :
    CORE::sysopen($_[0], $_[1], $_[2], $_[3]);

  if ($result) {
    if ($is_write) { call_invalidate_cached_fd_hooks($_[0]); }
    else { call_invalidate_cached_readonly_fd_hooks($_[0]); }
  }

  return $result;
};

sub perl_opendir_hook(*$) {
  # See comments above for perl_open_hook():
  if ((defined $_[0]) && (!ref $_[0])) 
    { splice @_, 0, 1, Symbol::qualify_to_ref($_[0], (caller)[0]); }

  my $result = CORE::opendir($_[0], @_[1..$#_]);

  # Directories are always opened read only, so there's no need
  # to invalidate any caches other than the fd -> path mapping.
  # However,
  # call_invalidate_cached_readonly_fd_hooks($_[0]);
  return $result;
};

sub perl_close_hook(;*) {
  my $fd = fileno($_[0]);

# FIXME:
#  if ($is_write && (defined $filename)) 
#    { call_invalidate_cached_path_hooks($filename); }

  $path_of_open_fd_cache[$fd] = undef if (defined $fd);

  goto &CORE::close;
};

sub perl_closedir_hook(*) {
  # &call_invalidate_cached_readonly_fd_hooks;
  goto &CORE::closedir;
};

sub perl_link_hook($$) 
  { call_invalidate_cached_path_hooks($_[1]); goto &CORE::link; }

sub perl_mkdir_hook(_;$)
  { call_invalidate_cached_path_hooks($_[0]); goto &CORE::mkdir; }

sub perl_rename_hook($$)
  { &call_invalidate_cached_path_hooks; goto &CORE::rename; }

sub perl_rmdir_hook(_)
  { &call_invalidate_cached_path_hooks; goto &CORE::rmdir; }

sub perl_symlink_hook($$)
  { call_invalidate_cached_path_hooks($_[1]); goto &CORE::symlink; }

sub perl_unlink_hook(@)
  { &call_invalidate_cached_path_hooks; goto &CORE::unlink; }

sub sys_close {
  &call_invalidate_cached_readonly_fd_hooks;
  goto &POSIX::close;
}

sub sys_closedir {
  # &invalidate_cached_path_for_fd;
  #
  # Directories handles in Perl are screwy - there isn't a general way to
  # get the underlying file descriptor for a dir handle even though there
  # will always be one (opened with O_DIRECTORY) on Linux...
  #
  # $ fd = fileno($fd) // $fd;
  # $ path_of_open_fd_cache[$fd] = undef;
  goto &POSIX::closedir;
}

sub sys_dup {
  my $newfd = &POSIX::dup;
  call_invalidate_cached_readonly_fd_hooks($newfd);
  return $fd;
}

sub sys_dup2 {
  my ($fd, $newfd) = @_;
  call_invalidate_cached_readonly_fd_hooks($newfd);
  goto &POSIX::dup2;
}

BEGIN {
  no warnings;
  #*CORE::GLOBAL::open = \&perl_open_hook;
  #*CORE::GLOBAL::sysopen = \&perl_sysopen_hook;
  #*CORE::GLOBAL::opendir = \&perl_opendir_hook;
  *CORE::GLOBAL::close = \&perl_close_hook;
  #*CORE::GLOBAL::closedir = \&perl_closedir_hook;
  *CORE::GLOBAL::link = \&perl_link_hook;
  *CORE::GLOBAL::mkdir = \&perl_mkdir_hook;
  *CORE::GLOBAL::rename = \&perl_rename_hook;
  *CORE::GLOBAL::rmdir = \&perl_rmdir_hook;
  *CORE::GLOBAL::symlink = \&perl_symlink_hook;
  #*CORE::GLOBAL::unlink = \&perl_unlink_hook;
};

BEGIN {
  *sys_access = *POSIX::access;
  *sys_chmod = *POSIX::2008::chmod;
  *sys_chown = *POSIX::2008::chown;
# These are actual functions defined above:
#  *sys_close = *POSIX::close;
#  *sys_closedir = *POSIX::closedir;
#  *sys_dup = *POSIX::dup;
#  *sys_dup2 = *POSIX::dup2;
  *sys_fsync = *POSIX::2008::fsync;
  *sys_fdatasync = *POSIX::2008::fdatasync;
  *sys_fstat = *POSIX::fstat;
  *sys_ftruncate = *POSIX::2008::ftruncate;
  *sys_futimens = *POSIX::2008::futimens;
  *sys_fsync = *POSIX::2008::fsync;
  *sys_link = *POSIX::2008::link;
  *sys_lstat = *POSIX::2008::lstat;
  *sys_mkdir = *POSIX::2008::mkdir;
  *sys_mkfifo = *POSIX::2008::mkfifo;
  *sys_mknod = *POSIX::mknod;
  *sys_open = *POSIX::2008::open;
  *sys_opendir = *POSIX::opendir;
  *sys_pause = *POSIX::pause;
  *sys_pipe = *POSIX::pipe;
  *sys_read = *POSIX::2008::read;
  *sys_readdir = *POSIX::readdir;
  *sys_rename = *POSIX::2008::rename;
  *sys_rewinddir = *POSIX::rewinddir;
  *sys_stat = *POSIX::2008::stat;
  *sys_symlink = *POSIX::2008::symlink;
  *sys_sync = *POSIX::2008::sync;
  *sys_truncate = *POSIX::2008::truncate;
  *sys_unlink = *POSIX::2008::unlink;
  *sys_write = *POSIX::write;

  *sys_openat = *POSIX::2008::openat;
  *sys_faccessat = *POSIX::2008::faccessat;
  *sys_fchmodat = *POSIX::2008::fchmodat;
  *sys_fchownat = *POSIX::2008::fchownat;
  *sys_fstatat = *POSIX::2008::fstatat;
  *sys_linkat = *POSIX::2008::linkat;
  *sys_lstat = *POSIX::2008::lstat;
  *sys_mkdirat = *POSIX::2008::mkdirat;
  *sys_mkfifoat = *POSIX::2008::mkfifoat;
  *sys_mknodat = *POSIX::2008::mknodat;
  *sys_openat = *POSIX::2008::openat;

  if ($POSIX::2008::compat_flags{readlink_null_terminated} // 0) {
    *sys_readlink = *POSIX::2008::readlink;
    *sys_readlinkat = *POSIX::2008::readlinkat;
  } else {
    *sys_readlink = *CORE::readlink;
    *sys_readlinkat = *readlinkat_via_direct_syscall;
  }

  *sys_renameat = *POSIX::2008::renameat;
  *sys_symlinkat = *POSIX::2008::symlinkat;
  *sys_unlinkat = *POSIX::2008::unlinkat;
  *sys_utimensat = *POSIX::2008::utimensat;
};

preserve:; our @EXPORT = (
  @POSIX_symbols,
  @POSIX_2008_symbols,
  @Fcntl_symbols,
  @Errno::EXPORT, @Errno::EXPORT_OK,
  qw(sys_access sys_chmod sys_chown sys_close sys_closedir
  sys_dup sys_dup2 sys_fsync sys_fdatasync sys_fstat sys_ftruncate
  sys_futimens sys_fsync sys_link sys_lstat sys_mkdir sys_mkfifo
  sys_mknod sys_open sys_opendir sys_pause sys_pipe sys_read 
  sys_readdir sys_readlink sys_rename sys_stat sys_symlink sys_sync
  sys_truncate sys_unlink sys_write sys_openat sys_faccessat 
  sys_fchmodat sys_fchownat sys_fstatat sys_linkat sys_lstat
  sys_mkdirat sys_mkfifoat sys_mknodat sys_openat sys_readlinkat
  sys_renameat sys_rewinddir sys_symlinkat sys_unlinkat sys_utimensat
  O_PATH DEFAULT_DIR_PERMS DEFAULT_FILE_PERMS strftime clock_gettime_nsec
  getpid clock_gettime_nsec sys_open_path path_of_open_fd 
  path_is_symlink get_native_fd is_file_handle sys_readdir_ext
  inode_and_type_of_dir_entry uncached_path_of_open_fd
  clock_nanosecs dirfd
  @invalidate_cached_fd_hooks
  @invalidate_cached_readonly_fd_hooks
  @invalidate_cached_path_hooks
  NATIVE_BIT_WIDTH PLATFORM_32_BIT PLATFORM_64_BIT)
);

1;
