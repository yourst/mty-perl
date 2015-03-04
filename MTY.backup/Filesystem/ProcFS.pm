#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::ProcFS
#
# Process related utility functions that use /proc on Linux
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::ProcFS;

use integer; use warnings; use Exporter qw(import);

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(%proc_stat_field_names @proc_stat_field_names_list
     PROC_STAT_BLOCKIODELAYS PROC_STAT_CMAJFLT PROC_STAT_CMINFLT
     PROC_STAT_CNSWAP PROC_STAT_COMM PROC_STAT_CPU PROC_STAT_CSTIME
     PROC_STAT_CUTIME PROC_STAT_ENDCODE PROC_STAT_EXITSIG PROC_STAT_FLAGS
     PROC_STAT_KRSP PROC_STAT_MAJFLT PROC_STAT_MINFLT PROC_STAT_NEXTALARM
     PROC_STAT_NICE PROC_STAT_NSWAP PROC_STAT_PGRP PROC_STAT_PID
     PROC_STAT_PPID PROC_STAT_PRIORITY PROC_STAT_RIP PROC_STAT_RSS
     PROC_STAT_RSSLIMIT PROC_STAT_RTPRIO PROC_STAT_SCHPOLICY PROC_STAT_SID
     PROC_STAT_SIGBLOCKED PROC_STAT_SIGCATCH PROC_STAT_SIGIGNORE
     PROC_STAT_SIGNALS PROC_STAT_STARTCODE PROC_STAT_STARTSTACK
     PROC_STAT_STARTTIME PROC_STAT_STATE PROC_STAT_STIME PROC_STAT_THREADS
     PROC_STAT_TTY PROC_STAT_TTYPGID PROC_STAT_UTIME PROC_STAT_VMCGUESTTIME
     PROC_STAT_VMGUESTTIME PROC_STAT_VSIZE PROC_STAT_WCHAN close_proc
     foreach_pid get_pids get_pids_by_name get_proc_base_fd get_proc_dir_fd
     open_proc open_procfs pids_to_stats proc_stats_to_hash read_proc
     read_proc_array read_proc_lines read_proc_link read_proc_matrix
     read_proc_matrix_column read_proc_named_fields read_proc_null_sep_array
     read_proc_nulls_to_spaces read_proc_self read_proc_subdir
     read_proc_subdir_contents set_process_name_in_procfs
     read_proc_cmdline);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::Common::Strings;
use MTY::RegExp::Define;
#pragma end_of_includes

my $null_sep_re = qr{\0}oax;
my $space_or_null_sep_re = qr{[\s\0]+}oax;
my $newline_sep_re = qr{\n}oax;

# Keep a cached file handle to /proc open at all times
# so we can use the xxxat() family of syscalls to speed
# up querying numerous items within /proc/xxx/...:

my $proc_base_fd = undef;
my $proc_dir_fd = undef;
my $proc_self_fd = undef;

noexport:; sub open_procfs() {
  # Try it both with and without O_PATH
  # (since older kernels may not support O_PATH):
  $proc_base_fd //= sys_open('/proc', O_PATH|O_DIRECTORY|O_RDONLY);
  $proc_base_fd //= sys_open('/proc', O_DIRECTORY|O_RDONLY);
  $proc_dir_fd //= sys_opendir('/proc');

  if ((!defined $proc_base_fd) || (!defined $proc_dir_fd))
    { die "Cannot open /proc filesystem (is /proc mounted?) ($!)"; }

  #
  # Open a path handle to our own pid (i.e. /proc/self/) 
  # since we'll be using this frequently:
  #
  # open_proc(getpid());
}

sub get_proc_base_fd() {
  if (!defined $proc_base_fd) { open_procfs(); }
  return $proc_base_fd;
}

sub get_proc_dir_fd() {
  if (!defined $proc_dir_fd) { open_procfs(); }
  return $proc_dir_fd;
}

sub open_proc($;$) {
  my ($pid, $subdir) = @_;
  $pid //= getpid();

  # don't add the slash unless we want an actual subdirectory:
  my $dir = (defined $subdir) ? $pid.'/'.$subdir : $pid;

  my $fd = $pid_to_open_proc_fd{$dir};
  if (defined $fd) { return $fd; }

  my $proc_base_fd = get_proc_base_fd();
  $fd = sys_open_path($dir, $proc_base_fd);

  if (defined $fd) { $pid_to_open_proc_fd{$dir} = $fd; }
  return $fd;
}

sub close_proc($;$) {
  my ($pid, $subdir) = @_;
  $pid //= getpid();

  my $dir = (defined $subdir) ? $pid.'/'.$subdir : $pid;

  my $fd = $pid_to_open_proc_fd{$dir};
  return 0 if (!defined $fd);

  sys_close($fd);
  delete $pid_to_open_proc_fd{$dir};
  return 1;
}

sub read_proc {
  my ($pid, $subpath) = @_;
  $pid //= getpid();

  my $proc_base_fd = get_proc_base_fd();

  my $basefd = $pid_to_open_proc_fd{$pid};
  my $filename = (defined $basefd) ? $subpath : 
    ((defined $subpath) ? ($pid.'/'.$subpath) : $pid);
  $basefd //= $proc_base_fd;

  my $link = sys_readlinkat($basefd, $filename);
  if (defined $link) { return $link; }
  my $fd = sys_openat($basefd, $filename, O_RDONLY);

  if (!defined $fd) {
    warn('Failed to open "/proc/'.$filename.'" (errno '.$!.')');
    return undef;
  }

  sys_read($fd, my $data, 1<<30) || return undef;
  sys_close($fd);
  return $data;
}

sub read_proc_self($) {
  my ($subpath) = @_;

  if (!defined $proc_self_fd) 
    { $proc_self_fd = open_proc('self'); }

  #++TODO
}

sub read_proc_link($$) {
  my ($pid, $subpath) = @_;
  $pid //= getpid();

  my $basefd = $pid_to_open_proc_fd{$pid};
  my $filename = (defined $basefd) ? $subpath : 
    ((defined $subpath) ? ($pid.'/'.$subpath) : $pid);
  $basefd //= get_proc_base_fd();
  my $target = sys_readlinkat($basefd, $filename);
  return $target;
}

sub read_proc_lines {
  my $data = read_proc(@_) || return undef;
  my @lines = split(/$newline_sep_re/oax, $data);
  return (wantarray ? @lines : \@lines);
}

sub read_proc_array {
  my $s = read_proc(@_) || return undef;
  my @out = split(/$space_or_null_sep_re/oa, $s);
  return (wantarray ? @out : \@out);
}

sub read_proc_matrix {
  my $lines = read_proc_lines(@_) || return undef;
  my @out = ( );
  foreach my $line (@$lines) {
    push @out,[ split /$space_or_null_sep_re/oa, $line ];
  }
  return (wantarray ? @out : \@out);
}

sub read_proc_matrix_column {
  my ($pid, $subpath, $column) = @_;
  $pid //= getpid();

  my $data = read_proc($pid, $subpath) || return undef;

  my $column_re_in = '^(?> \S++ \s++){'.($column-1).'}(\S++).*\n';
  my $column_re = qr{$column_re_in}oamsx;

  my @out = ( );
  while ($data =~ /$column_re/oamsxg) { push @out, $1; }

  return (wantarray ? @out : \@out);
}

sub read_proc_null_sep_array($$) {
  my $s = read_proc(@_) || return undef;
  my @out = split(/$null_sep_re/oa, $s);
  return (wantarray ? @out : \@out);
}

sub read_proc_cmdline(;$) {
  my ($pid) = @_;
  $pid //= getpid();
  return read_proc_null_sep_array($pid, 'cmdline');
}

sub read_proc_nulls_to_spaces($$;$) {
  my $s = read_proc(@_) || return undef;
  $s =~ s{$null_sep_re}{\ }oamsg;
  return $s;
}

sub read_proc_named_fields($$) {
  return split_lines_into_keys_and_values(read_proc(@_));
}

sub read_proc_subdir {
  my ($pid, $subpath) = @_;
  $pid //= getpid();

  my $dirname = '/proc/'.((defined $subpath) ? $pid.'/'.$subpath : $pid);
  my $dirfd = sys_opendir($dirname);
  if (!defined $dirfd) { return undef; }
  my @filenames = sys_readdir($dirfd);
  sys_closedir($dirfd);
  return (wantarray ? @filenames : \@$filenames);
}

sub read_proc_subdir_contents {
  my ($pid, $subpath) = @_;
  $pid //= getpid();

  my @filenames = read_proc_subdir($pid, $subpath);
  if (!@filenames) { return undef; }

  my $pid_dir_fd = $pid_to_open_proc_fd{$pid};
#++MTY FIXME
  error("TODO");
}

#sub write_proc{$$$} {
#  my ($pid, $subpath, $data) = @_;
#
# my $proc_base_fd = get_proc_base_fd();
# my $filename = (defined $subpath) ? ($pid.'/'.$subpath) : $pid;
# my $fd = sys_openat($proc_base_fd, $filename, O_WRONLY);
#
#  if (!defined $fd) {
#   warn('Failed to open "/proc/'.$filename.'" for writing (errno '.$!.')');
#   return undef;
# }
#
# sys_write($fd, $data, length($data)) || return undef;
# sys_close($fd);
# return $data;
#}

sub set_process_name_in_procfs($) {
  return write_proc(getpid(), 'comm', $_[0]);
}

my $sys_pid_max = undef;

sub get_pids(;$$+) {
  my ($min_pid, $max_pid, $command_names) = @_;
  if (!defined($sys_pid_max)) {
    $sys_pid_max = read_proc('sys', 'kernel/pid_max');
    if (!defined($sys_pid_max)) { die('Cannot read /proc/sys/kernel/pid_max'); }
    chomp $sys_pid_max;
  }

  $min_pid //= 0;
  $max_pid //= $sys_pid_max;

  if (($max_pid < $min_pid) || (($min_pid + 1024) >= $sys_pid_max)) {
    # this means there is a possibility of PID wraparound, so include all PIDs
    # just to be safe:
    $min_pid = 0;
    $max_pid = $pid_max;
  }

  my $fd = get_proc_dir_fd();

  my @pids = 
    sort { $a <=> $b } 
    grep { /^\d+$/ && ($_ >= $min_pid) && ($_ <= $max_pid) } 
    sys_readdir($fd);

  if (defined $command_names) {
    my $contains_command_name_re = generate_regexp_to_match_any_string_in_list($command_names);
    @pids = grep {
      my $comm = read_proc($_, 'comm') // '';
      my $exe = read_proc_link($_, 'exe') // '';
      ($comm =~ /$contains_command_name_re/) || ($exe =~ /$contains_command_name_re/);
    } @pids;
  }

  sys_rewinddir($fd);
  return (wantarray ? @pids : \@pids);
}

sub get_pids_by_name($;$$) {
  my ($command_names, $min_pid, $max_pid) = @_;
  return get_pids($min_pid, $max_pid, $command_names);
}

our @proc_stat_field_names_list = 
  qw(pid comm state ppid pgrp sid tty ttypgid flags
     minflt cminflt majflt cmajflt utime stime cutime
     cstime priority nice threads nextalarm starttime
     vsize rss rsslimit startcode endcode startstack
     krsp rip signals sigblocked sigignore sigcatch 
     wchan nswap cnswap exitsig cpu rtprio schpolicy
     blockiodelays vmguesttime vmcguesttime);

use constant {
  PROC_STAT_PID => 0,
  PROC_STAT_COMM => 1,
  PROC_STAT_STATE => 2,
  PROC_STAT_PPID => 3,
  PROC_STAT_PGRP => 4,
  PROC_STAT_SID => 5,
  PROC_STAT_TTY => 6,
  PROC_STAT_TTYPGID => 7,
  PROC_STAT_FLAGS => 8,
  PROC_STAT_MINFLT => 9,
  PROC_STAT_CMINFLT => 10,
  PROC_STAT_MAJFLT => 11,
  PROC_STAT_CMAJFLT => 12,
  PROC_STAT_UTIME => 13,
  PROC_STAT_STIME => 14,
  PROC_STAT_CUTIME => 15,
  PROC_STAT_CSTIME => 16,
  PROC_STAT_PRIORITY => 17,
  PROC_STAT_NICE => 18,
  PROC_STAT_THREADS => 19,
  PROC_STAT_NEXTALARM => 20,
  PROC_STAT_STARTTIME => 21,
  PROC_STAT_VSIZE => 22,
  PROC_STAT_RSS => 23,
  PROC_STAT_RSSLIMIT => 24,
  PROC_STAT_STARTCODE => 25,
  PROC_STAT_ENDCODE => 26,
  PROC_STAT_STARTSTACK => 27,
  PROC_STAT_KRSP => 28,
  PROC_STAT_RIP => 29,
  PROC_STAT_SIGNALS => 30,
  PROC_STAT_SIGBLOCKED => 31,
  PROC_STAT_SIGIGNORE => 32,
  PROC_STAT_SIGCATCH => 33, 
  PROC_STAT_WCHAN => 34,
  PROC_STAT_NSWAP => 35,
  PROC_STAT_CNSWAP => 36,
  PROC_STAT_EXITSIG => 37,
  PROC_STAT_CPU => 38,
  PROC_STAT_RTPRIO => 39,
  PROC_STAT_SCHPOLICY => 40,
  PROC_STAT_BLOCKIODELAYS => 41,
  PROC_STAT_VMGUESTTIME => 42,
  PROC_STAT_VMCGUESTTIME => 43,
};

our %proc_stat_field_names = 
  ('pid' => 0,
   'comm' => 1,
   'state' => 2,
   'ppid' => 3,
   'pgrp' => 4,
   'sid' => 5,
   'tty' => 6,
   'ttypgid' => 7,
   'flags' => 8,
   'minflt' => 9,
   'cminflt' => 10,
   'majflt' => 11,
   'cmajflt' => 12,
   'utime' => 13,
   'stime' => 14,
   'cutime' => 15,
   'cstime' => 16,
   'priority' => 17,
   'nice' => 18,
   'threads' => 19,
   'nextalarm' => 20,
   'starttime' => 21,
   'vsize' => 22,
   'rss' => 23,
   'rsslimit' => 24,
   'startcode' => 25,
   'endcode' => 26,
   'startstack' => 27,
   'krsp' => 28,
   'rip' => 29,
   'signals' => 30,
   'sigblocked' => 31,
   'sigignore' => 32,
   'sigcatch' => 33, 
   'wchan' => 34,
   'nswap' => 35,
   'cnswap' => 36,
   'exitsig' => 37,
   'cpu' => 38,
   'rtprio' => 39,
   'schpolicy' => 40,
   'blockiodelays' => 41,
   'vmguesttime' => 42,
   'vmcguesttime' => 43);

sub proc_stats_to_hash(+) {
  return array_pair_to_hash(\@proc_stat_field_names_list, $_[0]);
}

sub pids_to_stats(+) {
  my ($pids) = @_;
  my $n = scalar(@$pids);
  my %stats;

  for my $i (0..($n-1)) {
    my $patsid = $pids->[$i];
    $stats{$pid} = read_proc_array($pid, 'stat');
  }

  return (wantarray ? %stats : \%stats);
}

sub foreach_pid(&;+) {
  my ($func, $pidlist) = @_;
  if (!defined($pidlist)) { $pidlist = get_pids(); }

  foreach my $pid (@$pidlist) {
    my $stats = read_proc_array($pid, 'stat');
    next if (!defined($stats));
    my $final_value = $func->($pid, $stats);
    if (defined($final_value)) { return $final_value; }
  }
 
  return undef;
}

1;
