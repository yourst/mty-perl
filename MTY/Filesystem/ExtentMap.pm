#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::System::Misc
#
# Linux I/O Device Controls (ioctls)
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::ExtentMap;

use integer; use warnings; use Exporter qw(import);

preserve:; our @EXPORT = 
  qw(get_file_extents get_file_handle_extents print_extents summarize_extents
     @fiemap_extent_flag_names
     FIEMAP_EXTENT_LAST FIEMAP_EXTENT_UNKNOWN FIEMAP_EXTENT_DELAYED
     FIEMAP_EXTENT_ENCODED FIEMAP_EXTENT_ENCRYPTED FIEMAP_EXTENT_UNALIGNED
     FIEMAP_EXTENT_INLINE FIEMAP_EXTENT_TAIL FIEMAP_EXTENT_UNWRITTEN
     FIEMAP_EXTENT_MERGED FIEMAP_EXTENT_SHARED FIEMAP_EXTENT_FLAG_COUNT);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::Ioctl;
use POSIX::2008;

use constant {
  FIEMAP_EXTENT_LAST          => (1 << 0),
  FIEMAP_EXTENT_UNKNOWN       => (1 << 1),
  FIEMAP_EXTENT_DELAYED       => (1 << 2),
  FIEMAP_EXTENT_ENCODED       => (1 << 3),
  FIEMAP_EXTENT_ENCRYPTED     => (1 << 7),
  FIEMAP_EXTENT_UNALIGNED     => (1 << 8),
  FIEMAP_EXTENT_INLINE        => (1 << 9),
  FIEMAP_EXTENT_TAIL          => (1 << 10),
  FIEMAP_EXTENT_UNWRITTEN     => (1 << 11),
  FIEMAP_EXTENT_MERGED        => (1 << 12),
  FIEMAP_EXTENT_SHARED        => (1 << 13),
  FIEMAP_EXTENT_FLAG_COUNT    => 14,
};

our @fiemap_extent_flag_names = (
  'last',
  'unknown',
  'delayed',
  'encoded',
  '(bit 4)', 
  '(bit 5)', 
  '(bit 6)',
  'encrypted',
  'unaligned',
  'inline',
  'tail',
  'unwritten',
  'merged',
  'shared'
);

package FIEMAPExtentStruct {
  use MTY::Common::Common;
  use MTY::Common::Strings;
  use POSIX::2008 qw(ffs);

  sub new($;$$$$$$) {
    my ($class, $fe_logical, $fe_physical, $fe_length, $fe_flags) = @_;
    
    my $this = {
      fe_logical => $fe_logical // 0,
      fe_physical => $fe_physical // MTY::System::POSIX::LONG_MAX,
      fe_length => $fe_length // 0,
      fe_flags => $fe_flags // 0,
    };
    return bless $this, $class;
  }

  noexport:; use constant {
    FORMAT => 'QQQQQLLLL',
    SIZE => 56,
  };

  sub unpack($$) {
    my ($this, $data) = @_;

    my ($res1, $res2, $res3, $res4, $res5);
    @{$this}{fe_logical, fe_physical, fe_length, fe_res1, fe_res2, fe_flags, fe_res3, fe_res4, fe_res5} = CORE::unpack(FORMAT, $data);

    return $this;
  }

  sub new_from_packed($;$) {
    my ($class, $data) = @_;

    my $this = { };
    &unpack($this, $data);

    return bless $this, $class;
  }

  sub format_extent_flags($) {
    my ($flags) = @_;

    my $out = '';

    while ($flags) {
      my $i = ffs($flags) - 1;
      append_with_sep($out, $fiemap_extent_flag_names[$i] // 'bit'.$i, ' ');
      $flags ^= (1 << $i);
    }

    return $out;
  }

  sub format_as_string($) {
    my ($this) = @_;

    return sprintf('offset 0x%016llx @ block 0x%016llx for %19llu bytes, flags 0x%08x %s',
                   $this->{fe_logical}, $this->{fe_physical}, $this->{fe_length}, 
                   $this->{fe_flags}, format_extent_flags($this->{fe_flags}));
  }

  sub format_as_list($) {
    my ($this) = @_;

    return @{$this}{fe_logical, fe_physical, fe_length, fe_flags};
  }

  sub format_as_string_list($) {
    my ($this) = @_;

    return ('offset', '0x'.hexstring($this->{fe_logical}),
            'devblock', '0x'.hexstring($this->{fe_physical}),
            'for', $this->{fe_length}.' bytes',
            'flags', format_extent_flags($this->{fe_flags}));
  }

}

package FIEMAPStruct {
  use MTY::Common::Common;

  sub new($;$$$$$$) {
    my ($class, $fm_start, $fm_length, $fm_flags, $fm_mapped_extents, $fm_extent_count) = @_;
    
    my $this = {
      fm_start => $fm_start // 0,
      fm_length => $fm_length // MTY::System::POSIX::LONG_MAX,
      fm_flags => $fm_flags // 0,
      fm_mapped_extents => $fm_mapped_extents // 0,
      fm_extent_count => $fm_extent_count // 0,
      fm_reserved => 0,
    };
    return bless $this, $class;
  }

  noexport:; use constant {
    FORMAT => 'QQLLLL',
    SIZE => 32,
  };

  sub pack($;$) {
    my ($this, $alloc_space_for_extent_count) = @_;

    my $data = CORE::pack(FORMAT, @{$this}{fm_start, fm_length, fm_flags, fm_mapped_extents, fm_extent_count, fm_reserved});

    if (defined $alloc_space_for_extent_count) {
      my $extent = CORE::pack(FIEMAPExtentStruct::FORMAT, 0, 0, 0, 0, 0, 0, 0, 0, 0);
      die if ((length $extent) != FIEMAPExtentStruct::SIZE);
      $data .= ($extent x $alloc_space_for_extent_count);
    }

    return $data;
  }

  sub unpack($$) {
    my ($this, $data) = @_;
    @{$this}{fm_start, fm_length, fm_flags, fm_mapped_extents, fm_extent_count, fm_reserved} = CORE::unpack(FORMAT, $data);

    my $ess = FIEMAPExtentStruct::SIZE;
    my $extents = undef;
    my $n = $this->{fm_extent_count};
    
    if ((length $data) > SIZE) {
      if ((length($data) - SIZE) < ($n * $ess)) {
        warn("FIEMAPExtentStruct::unpack: fm_extent_count = $n (i.e. ".($n * $ess)." total bytes) ".
               "but returned data size after ".SIZE."-byte FIEMAPStruct header was only ".(length($data) - SIZE));
        return undef;
      }

      $extents = [ ];
      prealloc($extents, $n);

      my $p = SIZE;
      my $last_extent = undef;

      foreach (my $i = 0; $i < $n; $i++) {
        my $extent = FIEMAPExtentStruct->new_from_packed(substr($data, $p, $ess));
        if (($extent->{fe_flags} & MTY::Filesystem::ExtentMap::FIEMAP_EXTENT_LAST) != 0) { $last_extent = $extent; }
        $extents->[$i] = $extent;
        $p += $ess;
      }
    }

    return (wantarray ? ((defined $extents) ? ($this, $extents, $last_extent) : ($this)) : $this);
  }

  sub format_as_string($) {
    my ($this) = @_;

    return sprintf('  start 0x%016llx, length %19llu bytes, flags 0x%08x, mapped_extents %llu, extent_count %llu, reserved1 = %llu'.NL,
                   @{$this}{fm_start, fm_length, fm_flags, fm_mapped_extents, fm_extent_count, fm_reserved});
  }

  sub format_as_list($) {
    my ($this) = @_;

    return @{$this}{fm_start, fm_length, fm_flags, fm_mapped_extents, fm_extent_count};
  }
};

sub get_file_handle_extents($;$) {
  my ($fd, $fdstats) = @_;

  my $fiemap_struct = FIEMAPStruct->new();

  my $fiemap_packed_struct = $fiemap_struct->pack();
  my $rc = ioctl($fd, IOCTL_FS_IOC_FIEMAP, $fiemap_packed_struct) || -1;
  if ($rc < 0) { $! = -$rc; return undef; }

  $fiemap_struct->unpack($fiemap_packed_struct);

  my $extent_count = $fiemap_struct->{fm_mapped_extents};

  $fiemap_struct->{fm_extent_count} = $extent_count;
  $fiemap_struct->{fm_mapped_extents} = 0;

  $fiemap_packed_struct = $fiemap_struct->pack($extent_count);

  $rc = ioctl($fd, IOCTL_FS_IOC_FIEMAP, $fiemap_packed_struct) || -1;
  if ($rc < 0) { $! = -$rc; return undef; }

  my $extents;
  ($fiemap_struct, $extents) = $fiemap_struct->unpack($fiemap_packed_struct);

  $fdstats //= [ sys_fstatat(fileno($fd), '', AT_EMPTY_PATH) ];
  my $actual_bytes = $fdstats->[STAT_SIZE];
  my $actual_bytes_left = $actual_bytes;

  foreach my $extent (@$extents) {
    my ($offset, $bytes, $flags) = @{$extent}{fe_logical, fe_length, fe_flags};
    my $end_of_extent = $offset + $bytes;

    if ((($flags & FIEMAP_EXTENT_LAST) != 0) && ($end_of_extent > $actual_bytes)) { 
      $bytes -= ($end_of_extent - $actual_bytes);
      $extent->{fe_length} = $bytes; 
    }
    $actual_bytes_left -= $bytes;
  }

  # if ($actual_bytes_left > 0) {
  #   push @$extents, FIEMAPExtentStruct->new($actual_bytes - $actual_bytes_left, 
  #   0, $actual_bytes_left, FIEMAP_EXTENT_UNWRITTEN|FIEMAP_EXTENT_LAST);
  # }

  return (wantarray ? ($extents, $fdstats) : $extents);
}

sub get_file_extents($;$) {
  my ($filename, $stats) = @_;

  sysopen(my $fd, $filename, O_RDONLY) || return undef;
  my ($extents, $fdstats) = get_file_handle_extents($fd, $stats);
  close($fd);
  return (wantarray ? ($extents, $fdstats) : $extents);
}

sub print_extents(+) {
  my ($extents, $outfd) = @_;
  $outfd //= STDOUT;

  my $i = 0;
  my @table = map { [ '#'.$i++, $_->format_as_string_list() ] } @$extents;

  my @alignments = (
    ALIGN_RIGHT,
    ALIGN_LEFT, ALIGN_RIGHT,
    ALIGN_LEFT, ALIGN_RIGHT,
    ALIGN_LEFT, ALIGN_RIGHT,
    ALIGN_LEFT, ALIGN_LEFT
  );
  
  printfd($outfd, format_table(@table, colseps => '  ', row_prefix => '  ', align => @alignments));
  
  return \@table;
}

sub summarize_extents($;$) {
  my ($extents, $stats) = @_;
  
  my $file_size = (defined $stats) ? $stats->[STAT_SIZE] : undef;

  my $total_extents = 0;
  my $total_bytes = 0;

  my @extents_summary = ( );
  prealloc(@extents_summary, FIEMAP_EXTENT_FLAG_COUNT, 0);

  my @bytes_summary = ( );
  prealloc(@bytes_summary, FIEMAP_EXTENT_FLAG_COUNT, 0);

  foreach my $extent (@$extents) {
    my ($flags, $bytes) = @{$extent}{fe_flags, fe_length};

    while ($flags) {
      my $i = ffs($flags) - 1;
      $extents_summary[$i]++;
      $bytes_summary[$i] += $bytes;
      $flags ^= (1 << $i);
    }

    $total_extents++;
    $total_bytes += $bytes;
  }

  my $missing_bytes = ($file_size // $total_bytes) - $total_bytes;

  @bytes_summary[ffs(FIEMAP_EXTENT_UNWRITTEN)-1] += $missing_bytes;

  my %summary = (
    total_extents => $total_extents, 
    total_bytes => $total_bytes, 
    file_size => $file_size);

  foreach (my $i = 0; $i < FIEMAP_EXTENT_FLAG_COUNT; $i++) {
    my $flagname = $fiemap_extent_flag_names[$i] // 'bit'.$i;

    if ($extents_summary[$i] > 0) 
      { $summary{$flagname.'_extents'} = $extents_summary[$i]; }

    if ($bytes_summary[$i] > 0) 
      { $summary{$flagname.'_bytes'} = $bytes_summary[$i]; }
  }

  return \%summary;
}

1;

