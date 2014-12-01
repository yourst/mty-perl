#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::System::POSIX
#
# Copyright 2002 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::System::POSIX;

use POSIX 
  qw(clock ctermid cuserid difftime mktime nice setpgid
     rewinddir setsid tcsetpgrp times uname strftime getgroups
     FD_CLOEXEC F_DUPFD F_GETFD F_GETFL F_GETLK F_OK F_RDLCK F_SETFD
     F_SETFL F_SETLK F_SETLKW F_UNLCK F_WRLCK O_ACCMODE O_APPEND
     O_CREAT O_EXCL O_NOCTTY O_NONBLOCK O_RDONLY O_RDWR O_TRUNC
     O_WRONLY S_IRGRP S_IROTH S_IRUSR S_IRWXG S_IRWXO S_IRWXU S_ISGID
     S_ISUID S_IWGRP S_IWOTH S_IWUSR S_IXGRP S_IXOTH S_IXUSR S_ISBLK
     S_ISCHR S_ISDIR S_ISFIFO S_ISREG CLK_TCK CLOCKS_PER_SEC R_OK
     SEEK_CUR SEEK_END SEEK_SET STDIN_FILENO STDOUT_FILENO
     STDERR_FILENO W_OK X_OK);

use POSIX::2008 
  qw(basename clock_getcpuclockid clock_getres clock_gettime
     clock_nanosleep clock_settime dirname ffs getdate getdate_err 
     gethostid gethostname getitimer getpriority getsid
     killpg mkdtemp mkstemp nanosleep pread ptsname pwrite setegid
     setitimer setpriority setregid setreuid mkdir mkdirat 
     acos acosh asin asinh atan2 atan atanh atof atoi atol cbrt ceil cos 
     cosh div erand48 erf exp2 expm1 fdim fegetround fesetround floor 
     fma fmax fmin fmod fnmatch fpclassify hypot ilogb isinf isnan
     jrand48 ldexp ldiv lgamma log2 logb lrand48 mrand48 nearbyint
     nextafter nrand48 remainder round scalbn seed48 copysign signbit sinh 
     srand48 srandom tan tanh
     AT_EACCESS AT_EMPTY_PATH AT_FDCWD AT_NO_AUTOMOUNT AT_REMOVEDIR
     AT_SYMLINK_FOLLOW AT_SYMLINK_NOFOLLOW BOOT_TIME CLOCK_MONOTONIC
     CLOCK_MONOTONIC_RAW CLOCK_PROCESS_CPUTIME_ID CLOCK_REALTIME
     CLOCK_THREAD_CPUTIME_ID _CS_GNU_LIBC_VERSION
     _CS_GNU_LIBPTHREAD_VERSION _CS_PATH DEAD_PROCESS FNM_CASEFOLD
     FNM_FILE_NAME FNM_LEADING_DIR FNM_NOESCAPE FNM_NOMATCH FNM_PATHNAME
     FNM_PERIOD FP_INFINITE FP_NAN FP_NORMAL FP_SUBNORMAL FP_ZERO
     INIT_PROCESS ITIMER_PROF ITIMER_REAL ITIMER_VIRTUAL LOGIN_PROCESS
     NEW_TIME O_CLOEXEC O_DIRECTORY O_EXEC OLD_TIME O_NOFOLLOW O_RSYNC
     O_SEARCH O_SYNC O_TMPFILE O_TTY_INIT RTLD_GLOBAL RTLD_LAZY RTLD_LOCAL
     RTLD_NOW RUN_LVL TIMER_ABSTIME USER_PROCESS UTIME_NOW UTIME_OMIT
     getgid getuid getegid geteuid
);

use Fcntl 
  qw(FD_CLOEXEC F_ALLOCSP F_ALLOCSP64 F_COMPAT F_DUP2FD F_DUPFD
     F_EXLCK F_FREESP F_FREESP64 F_FSYNC F_FSYNC64 F_GETFD F_GETFL
     F_GETLK F_GETLK64 F_GETOWN F_NODNY F_POSIX F_RDACC F_RDDNY
     F_RDLCK F_RWACC F_RWDNY F_SETFD F_SETFL F_SETLK F_SETLK64
     F_SETLKW F_SETLKW64 F_SETOWN F_SHARE F_SHLCK F_UNLCK F_UNSHARE
     F_WRACC F_WRDNY F_WRLCK O_ACCMODE O_ALIAS O_APPEND O_ASYNC
     O_BINARY O_CREAT O_DEFER O_DIRECT O_DSYNC O_EXCL
     O_EXLOCK O_LARGEFILE O_NDELAY O_NOCTTY O_NOINHERIT
     O_NONBLOCK O_RANDOM O_RAW O_RDONLY O_RDWR O_RSRC 
     O_SEQUENTIAL O_SHLOCK O_TEMPORARY O_TEXT O_TRUNC O_WRONLY
     DN_ACCESS DN_ATTRIB DN_CREATE DN_DELETE DN_MODIFY DN_MULTISHOT
     DN_RENAME F_GETLEASE F_GETSIG F_NOTIFY F_SETLEASE F_SETSIG
     LOCK_MAND LOCK_READ LOCK_RW LOCK_WRITE O_IGNORE_CTTY O_NOATIME
     O_NOLINK O_NOTRANS LOCK_SH LOCK_EX LOCK_NB LOCK_UN S_ISUID
     S_ISGID S_ISVTX S_ISTXT _S_IFMT S_IFREG S_IFDIR S_IFLNK S_IFSOCK
     S_IFBLK S_IFCHR S_IFIFO S_IFWHT S_ENFMT S_IRUSR S_IWUSR S_IXUSR
     S_IRWXU S_IRGRP S_IWGRP S_IXGRP S_IRWXG S_IROTH S_IWOTH S_IXOTH
     S_IRWXO S_IREAD S_IWRITE S_IEXEC S_ISREG S_ISDIR S_ISLNK S_ISSOCK
     S_ISBLK S_ISCHR S_ISFIFO S_ISWHT S_ISENFMT S_IFMT S_IMODE
     SEEK_SET SEEK_CUR SEEK_END FAPPEND FASYNC FCREAT FDEFER FDSYNC
     FEXCL FLARGEFILE FNDELAY FNONBLOCK FRSYNC FSYNC FTRUNC);

use Errno
  qw(EBADR ENOMSG ENOTSUP ESTRPIPE EADDRINUSE EL3HLT EBADF ENAVAIL
     ECHRNG ENOTBLK ENOTNAM ELNRNG ENOKEY EXDEV EBADE EBADSLT
     ECONNREFUSED ENOSTR EISCONN EOVERFLOW ENONET EKEYREVOKED EFBIG
     ECONNRESET ELIBMAX EWOULDBLOCK EREMOTEIO ERFKILL ENOPKG ELIBSCN
     EMEDIUMTYPE EDESTADDRREQ ENOTSOCK EIO EINPROGRESS ERANGE
     EADDRNOTAVAIL EAFNOSUPPORT EINTR EILSEQ EREMOTE ENOMEM
     ENETUNREACH EPIPE ENODATA EUSERS EOPNOTSUPP EPROTO EISNAM ESPIPE
     EALREADY ENAMETOOLONG ENOEXEC EISDIR EBADRQC EEXIST EDOTDOT
     ELIBBAD EOWNERDEAD ESRCH EFAULT EAGAIN EDEADLOCK EXFULL
     ENOPROTOOPT ENETDOWN EPROTOTYPE EL2NSYNC ENETRESET EADV EUCLEAN
     EROFS ESHUTDOWN EMULTIHOP EPROTONOSUPPORT ENFILE ENOLCK
     ECONNABORTED ECANCELED EDEADLK ENOLINK ESRMNT ENOTDIR ETIME
     EINVAL ENOTTY ENOANO ELOOP ENOENT EPFNOSUPPORT EBADMSG ENOMEDIUM
     EL2HLT EDOM EBFONT EKEYEXPIRED EMSGSIZE ENOCSI EL3RST ENOSPC
     EIDRM ENOBUFS ENOSYS EHOSTDOWN EBADFD ENOSR ENOTCONN ESTALE
     EDQUOT EKEYREJECTED ENOTRECOVERABLE EMFILE EACCES EBUSY E2BIG
     EPERM ELIBEXEC ETOOMANYREFS ELIBACC ENOTUNIQ ECOMM ERESTART
     EUNATCH ESOCKTNOSUPPORT ETIMEDOUT ENXIO ENODEV ETXTBSY EHWPOISON
     EMLINK ECHILD EHOSTUNREACH EREMCHG ENOTEMPTY);

use Cwd qw(realpath abs_path);

use File::Path qw(mkpath make_path remove_tree rmtree);

# Defined by the latest Linux kernels but not yet in the Perl definitions:
use constant O_PATH => 010000000;

# These are subject to masking by the current umask:
use constant {
  DEFAULT_DIR_PERMS  => 0755, # i.e. drwxr-xr-x
  DEFAULT_FILE_PERMS => 0644, # i.e. -rw-r--r--
};

#
# Perl will cache the value returned by getpid(), and will also keep
# this cached pid up to date even across forks, so we use it instead
# of calling POSIX::getpid() ourselves:
#
sub getpid() { return $$; }

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
  my $buf = chr(0) x 1024;
  my $rc = syscall(&SYS_readlinkat, $fd, $path, $buf, 1024-1);
  if ($rc < 0) { return undef; }
  # force it to be null terminated the perl way:
  $buf = substr($buf, 0, $rc);
  return $buf;
}

sub clock_gettime_nsec() {
  my ($sec, $nsec) = POSIX::2008::clock_gettime();
  return ($sec * 1000000000) + $nsec;
}

BEGIN {
  *sys_access = *POSIX::access;
  *sys_chmod = *POSIX::2008::chmod;
  *sys_chown = *POSIX::2008::chown;
  *sys_close = *POSIX::close;
  *sys_closedir = *POSIX::closedir;
  *sys_dup = *POSIX::dup;
  *sys_dup2 = *POSIX::dup2;
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
# (See above for when this workaround is needed):
# *sys_readlink = *CORE::readlink;
  *sys_readlink = *POSIX::2008::readlink;
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
# (See above for when this workaround is needed):
# *sys_readlinkat = *readlinkat_via_direct_syscall
  *sys_readlinkat = *POSIX::2008::readlinkat;
  *sys_renameat = *POSIX::2008::renameat;
  *sys_symlinkat = *POSIX::2008::symlinkat;
  *sys_unlinkat = *POSIX::2008::unlinkat;
  *sys_utimensat = *POSIX::2008::utimensat;
};

my $cached_current_dir = undef;

sub sys_getcwd() {
  $cached_current_dir //= POSIX::getcwd();
  return $cached_current_dir;
}

sub invalidate_cached_current_dir($) {
  # don't preemptively update the cached current directory path,
  # since at the time this is called, we don't yet know if the
  # new directory passed to chdir() is actually valid or not:
  $cached_current_dir = undef; 
}

my @chdir_notifiers = ( \&invalidate_cached_current_dir );

sub add_chdir_notifier
  { push @chdir_notifiers, $_[0]; }

sub sys_chdir($) {
  if ($_[0] eq $cached_current_dir) { return $cached_current_dir; }

  # first get a handle to the target directory to guarantee it exists,
  # we can access it, and it is in fact a directory (this is done prior
  # to the actual chdir to avoid race conditions with other processes).
  my $dirfd = POSIX::2008::open($_[0], O_PATH|O_DIRECTORY);
  if (!defined $fd) { return $undef; }

  # invalidate any caches that have registered with us
  # because their data depends on the current directory:
  foreach $notifier (@chdir_notifiers) 
    { $notifier->($_[0]) if (defined $notifier); }

  # finally change to the new directory via its handle:
  die if (!POSIX::2008::fchdir($dirfd));
  $cached_current_dir = POSIX::getcwd();

  POSIX::2008::close($dirfd);

  return $cached_current_dir;
}

my $open_path_default_flags = 
  O_PATH | O_RDONLY | O_CLOEXEC;

my @open_path_fd_to_path;

sub get_path_of_open_path_fd($) {
  my ($fd) = @_;
  my $path = $open_path_fd_to_path[$fd];

  if (!defined $path) { 
    $path = readlink('/proc/self/fd/'.$fd);
    if (!defined $path) { warn("Cannot determine path of O_PATH fd $fd"); }
    $open_path_fd_to_path[$fd] = $path;
  }

  return $path;
}

sub sys_open_path($;$$) {
  my ($dir, $basefd, $flags) = @_;

  my $basepath = (defined $basefd) ? get_path_of_open_path_fd($basefd).'/' : '';

  $basefd //= AT_FDCWD;
  $flags //= O_DIRECTORY; # O_PATH is most commonly used on directories

  #
  # First try to open the path with O_PATH, then fall back
  # to opening it without O_PATH if O_PATH isn't supported:
  #
  my $fd = sys_openat($basefd, $dir, $flags | $open_path_default_flags);
  
  #
  # This kernel version doesn't seem to support O_PATH, so 
  # don't try to use this performance optimization next time:
  #
  if ((!defined $fd) && ($! == EINVAL)) {
    warn('sys_open_path: O_PATH not supported by this kernel version; reverting to openat() instead');
    $open_path_default_flags ^= O_PATH;
    $fd = sys_openat($basefd, $dir, $flags | $open_path_default_flags);
  }

  if ((!defined $fd) && (($! == EMFILE) || ($! == ENFILE)))
    { die("sys_open_path: too many open file descriptors"); }

  if (defined $fd) { $open_path_fd_to_path[$fd] = $basepath.$dir; }

  # print(STDERR "Opened $dir as O_PATH fd $fd\n");

  return $fd;
}

BEGIN {
  *chdir = *sys_chdir;
  *getcwd = *sys_getcwd;
  *cwd = *sys_getcwd;
  # *realpath = *sys_realpath;
};

use integer; use warnings; use Exporter::Lite;

preserve:; our @EXPORT = 
  qw(clock ctermid cuserid difftime mktime nice setpgid getpid
     setsid tcsetpgrp times uname getcwd getgroups
     FD_CLOEXEC F_DUPFD F_GETFD F_GETFL F_GETLK F_OK F_RDLCK F_SETFD
     F_SETFL F_SETLK F_SETLKW F_UNLCK F_WRLCK O_ACCMODE O_APPEND
     O_CREAT O_EXCL O_NOCTTY O_NONBLOCK O_RDONLY O_RDWR O_TRUNC
     O_WRONLY S_IRGRP S_IROTH S_IRUSR S_IRWXG S_IRWXO S_IRWXU S_ISGID
     S_ISUID S_IWGRP S_IWOTH S_IWUSR S_IXGRP S_IXOTH S_IXUSR S_ISBLK
     S_ISCHR S_ISDIR S_ISFIFO S_ISREG CLK_TCK CLOCKS_PER_SEC R_OK
     SEEK_CUR SEEK_END SEEK_SET STDIN_FILENO STDOUT_FILENO
     STDERR_FILENO W_OK X_OK
     basename clock_getcpuclockid clock_getres clock_gettime
     clock_nanosleep clock_settime dirname ffs getdate getdate_err
     gethostid gethostname getitimer getpriority getsid
     killpg mkdtemp mkstemp nanosleep pread ptsname pwrite setegid
     setitimer setpriority setregid setreuid mkdir
     mkdirat 
     acos acosh asin asinh atan2 atan atanh atof atoi atol cbrt ceil cos 
     cosh div erand48 erf exp2 expm1 fdim fegetround fesetround floor 
     fma fmax fmin fmod fnmatch fpclassify hypot ilogb isinf isnan
     jrand48 ldexp ldiv lgamma llog1p log2 logb lrand48 mrand48 nearbyint
     nextafter nrand48 remainder round scalbn seed48 copysign signbit sinh 
     srand48 srandom tan tanh
     AT_EACCESS AT_EMPTY_PATH AT_FDCWD AT_NO_AUTOMOUNT AT_REMOVEDIR
     AT_SYMLINK_FOLLOW AT_SYMLINK_NOFOLLOW BOOT_TIME CLOCK_MONOTONIC
     CLOCK_MONOTONIC_RAW CLOCK_PROCESS_CPUTIME_ID CLOCK_REALTIME
     CLOCK_THREAD_CPUTIME_ID _CS_GNU_LIBC_VERSION
     _CS_GNU_LIBPTHREAD_VERSION _CS_PATH DEAD_PROCESS FNM_CASEFOLD
     FNM_FILE_NAME FNM_LEADING_DIR FNM_NOESCAPE FNM_NOMATCH FNM_PATHNAME
     FNM_PERIOD FP_INFINITE FP_NAN FP_NORMAL FP_SUBNORMAL FP_ZERO
     INIT_PROCESS ITIMER_PROF ITIMER_REAL ITIMER_VIRTUAL LOGIN_PROCESS
     NEW_TIME O_CLOEXEC O_DIRECTORY O_EXEC OLD_TIME O_NOFOLLOW O_RSYNC
     O_SEARCH O_SYNC O_TMPFILE O_TTY_INIT RTLD_GLOBAL RTLD_LAZY RTLD_LOCAL
     RTLD_NOW RUN_LVL TIMER_ABSTIME USER_PROCESS UTIME_NOW UTIME_OMIT
     getgid getuid getegid geteuid
     FD_CLOEXEC F_ALLOCSP F_ALLOCSP64 F_COMPAT F_DUP2FD F_DUPFD
     F_EXLCK F_FREESP F_FREESP64 F_FSYNC F_FSYNC64 F_GETFD F_GETFL
     F_GETLK F_GETLK64 F_GETOWN F_NODNY F_POSIX F_RDACC F_RDDNY
     F_RDLCK F_RWACC F_RWDNY F_SETFD F_SETFL F_SETLK F_SETLK64
     F_SETLKW F_SETLKW64 F_SETOWN F_SHARE F_SHLCK F_UNLCK F_UNSHARE
     F_WRACC F_WRDNY F_WRLCK O_ACCMODE O_ALIAS O_APPEND O_ASYNC
     O_BINARY O_CREAT O_DEFER O_DIRECT O_DSYNC O_EXCL
     O_EXLOCK O_LARGEFILE O_NDELAY O_NOCTTY O_NOINHERIT
     O_NONBLOCK O_RANDOM O_RAW O_RDONLY O_RDWR O_RSRC
     O_SEQUENTIAL O_SHLOCK O_TEMPORARY O_TEXT O_TRUNC O_WRONLY
     DN_ACCESS DN_ATTRIB DN_CREATE DN_DELETE DN_MODIFY DN_MULTISHOT
     DN_RENAME F_GETLEASE F_GETSIG F_NOTIFY F_SETLEASE F_SETSIG
     LOCK_MAND LOCK_READ LOCK_RW LOCK_WRITE O_IGNORE_CTTY O_NOATIME
     O_NOLINK O_NOTRANS LOCK_SH LOCK_EX LOCK_NB LOCK_UN S_ISUID
     S_ISGID S_ISVTX S_ISTXT _S_IFMT S_IFREG S_IFDIR S_IFLNK S_IFSOCK
     S_IFBLK S_IFCHR S_IFIFO S_IFWHT S_ENFMT S_IRUSR S_IWUSR S_IXUSR
     S_IRWXU S_IRGRP S_IWGRP S_IXGRP S_IRWXG S_IROTH S_IWOTH S_IXOTH
     S_IRWXO S_IREAD S_IWRITE S_IEXEC S_ISREG S_ISDIR S_ISLNK S_ISSOCK
     S_ISBLK S_ISCHR S_ISFIFO S_ISWHT S_ISENFMT S_IFMT S_IMODE
     SEEK_SET SEEK_CUR SEEK_END FAPPEND FASYNC FCREAT FDEFER FDSYNC
     FEXCL FLARGEFILE FNDELAY FNONBLOCK FRSYNC FSYNC FTRUNC
     EBADR ENOMSG ENOTSUP ESTRPIPE EADDRINUSE EL3HLT EBADF ENAVAIL
     ECHRNG ENOTBLK ENOTNAM ELNRNG ENOKEY EXDEV EBADE EBADSLT
     ECONNREFUSED ENOSTR EISCONN EOVERFLOW ENONET EKEYREVOKED EFBIG
     ECONNRESET ELIBMAX EWOULDBLOCK EREMOTEIO ERFKILL ENOPKG ELIBSCN
     EMEDIUMTYPE EDESTADDRREQ ENOTSOCK EIO EINPROGRESS ERANGE
     EADDRNOTAVAIL EAFNOSUPPORT EINTR EILSEQ EREMOTE ENOMEM
     ENETUNREACH EPIPE ENODATA EUSERS EOPNOTSUPP EPROTO EISNAM ESPIPE
     EALREADY ENAMETOOLONG ENOEXEC EISDIR EBADRQC EEXIST EDOTDOT
     ELIBBAD EOWNERDEAD ESRCH EFAULT EAGAIN EDEADLOCK EXFULL
     ENOPROTOOPT ENETDOWN EPROTOTYPE EL2NSYNC ENETRESET EADV EUCLEAN
     EROFS ESHUTDOWN EMULTIHOP EPROTONOSUPPORT ENFILE ENOLCK
     ECONNABORTED ECANCELED EDEADLK ENOLINK ESRMNT ENOTDIR ETIME
     EINVAL ENOTTY ENOANO ELOOP ENOENT EPFNOSUPPORT EBADMSG ENOMEDIUM
     EL2HLT EDOM EBFONT EKEYEXPIRED EMSGSIZE ENOCSI EL3RST ENOSPC
     EIDRM ENOBUFS ENOSYS EHOSTDOWN EBADFD ENOSR ENOTCONN ESTALE
     EDQUOT EKEYREJECTED ENOTRECOVERABLE EMFILE EACCES EBUSY E2BIG
     EPERM ELIBEXEC ETOOMANYREFS ELIBACC ENOTUNIQ ECOMM ERESTART
     EUNATCH ESOCKTNOSUPPORT ETIMEDOUT ENXIO ENODEV ETXTBSY EHWPOISON
     EMLINK ECHILD EHOSTUNREACH EREMCHG ENOTEMPTY
     getcwd cwd abs_path add_chdir_notifier
     mkpath make_path remove_tree rmtree
     sys_access sys_chdir sys_chmod sys_chown sys_close sys_closedir
     sys_dup sys_dup2 sys_fsync sys_fdatasync sys_fstat sys_ftruncate
     sys_futimens sys_fsync sys_link sys_lstat sys_mkdir sys_mkfifo
     sys_mknod sys_open sys_opendir sys_pause sys_pipe sys_read 
     sys_readdir sys_readlink sys_rename sys_stat sys_symlink sys_sync
     sys_truncate sys_unlink sys_write sys_openat sys_faccessat 
     sys_fchmodat sys_fchownat sys_fstatat sys_linkat sys_lstat
     sys_mkdirat sys_mkfifoat sys_mknodat sys_openat sys_readlinkat
     sys_renameat sys_rewinddir sys_symlinkat sys_unlinkat sys_utimensat
     O_PATH DEFAULT_DIR_PERMS DEFAULT_FILE_PERMS realpath cwd strftime 
     clock_gettime_nsec
     sys_open_path get_path_of_open_path_fd);

1;
