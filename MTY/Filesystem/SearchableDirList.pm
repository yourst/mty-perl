#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::SearchableDirList
#
# Copyright 1997 - 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::SearchableDirList;

use integer; use warnings; use Exporter qw(import);

preserve:; our @EXPORT = 
  qw(find_perl_module test_searchable_dir_list);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Common::Cache;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::PathCache;
use MTY::Filesystem::StatsCache;
use MTY::RegExp::FilesAndPaths;
use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;

#
# $this->search_dir_list_for_file($filename):
#
# $filename may be the trailing part of a longer path (e.g. to find
# "subdir/subsubdir/filename.ext" in a list of directories, e.g. as
# "/absolute/dir/in/which/we/found/subdir/subsubdir/filename.ext".
#
# if $filename is an absolute path (i.e. it starts with "/"), it is
# only returned as is if it actually exists.
#
# If $filename is a reference to an array rather than a single
# string, each filename (or subpath, if it contains "/" separators) 
# in that array is checked in sequence to see if it exists in each
# directory, and the first match is returned. 
#
# (In the case of an array of absolute paths, the first path that 
# exists is returned, without any need for the specified list of 
# directories, although a mix of absolute paths and relative paths 
# may produce undefined results if this function's implementation 
# is ever changed. Therefore callers are strongly advised to only
# modify the final filename portion of each array entry).
#
# This array feature is intended to provide the correct semantics 
# when searching for a given target filename along with one or more
# higher priority variations of that name, e.g. with Perl modules,
# path/to/module.pmc should be returned before path/to/module.pm
# if both appear in the same directory, but not if they are in
# different directories.
#

noexport:; sub search_dir_list_for_file(+$+;$) {
  my ($this, $key, $filenames, $acceptable_types_mask) = @_;
  $acceptable_types_mask //= FILE_TYPE_MASK_ANY;

  $filenames = (is_array_ref $filenames) ? $filenames : [ $filenames ];

  foreach my $dirinfo (@{$this}[1..$#$this]) {
    # next if (!is_array_ref($dirinfo)); # skip the cache reference itself

    my ($abs_dir_path, $fd, $stats, $hits) = @$dirinfo;

    my $abs_file_path = undef;

    foreach my $filename (@$filenames) {
      $abs_file_path = resolve_path($filename, $fd);
      next if (!defined $abs_file_path);

      if ($acceptable_types_mask != FILE_TYPE_MASK_ANY) {
        my $type = get_file_type($abs_file_path);
        if ((!defined $type) || (!(($acceptable_types_mask >> $type) & 1))) {
          $abs_file_path = undef;
          next;
        }
      }

      last; # if we found a match
    }

    if (defined $abs_file_path) {
      $dirinfo->[3] = ++$hits;
      return $abs_file_path;
    }
  }

  return undef;
}

noexport:; sub dirlist($) {
  my ($this) = @_;
  my @dirs = ( );
  foreach my $info (@$this) {
    next if (!is_array_ref($info));
    push @dirs, $info->[0];
  }

  return (wantarray ? @dirs : \@dirs);
}

noexport:; sub get_perf_stats($) {
  my ($this) = @_;
  my $info = { };

  my $total_files_queried = $cache_hits + $cache_misses;
  my $total_files_found = 0;

  my $cache = $this->[0];
  my $hash_of_cache = $cache->get_hash();
  my ($cache_hits, $cache_misses, $cache_flushes) = $cache->get_stats();
  my $total_cache_entries = scalar keys %$hash_of_cache;
  my $undef_cache_entries = 0;

  foreach my $v (values %$hash_of_cache) 
    { $undef_cache_entries += (!defined $v) ? 1 : 0; }

  $info->{'.total.queries'} = $total_files_queried;
  $info->{'.total.found'} = $total_files_found;
  $info->{'.total.missing'} = $total_files_queried - $total_files_found;
  $info->{'.unique.total'} = $total_cache_entries;
  $info->{'.unique.undef'} = $undef_cache_entries;
  $info->{'.unique.valid'} = $total_cache_entries - $undef_cache_entries;
  $info->{'.cache.hits'} = $cache_hits;
  $info->{'.cache.misses'} = $cache_misses;
  $info->{'.cache.flushes'} = $cache_flushes;

  foreach my $info (@$this) {
    next if (!is_array_ref($info));
    my ($abspath, $fd, $stats, $hits) = @$info;
    $info->{$abspath} = $hits;
    $total_files_found += $hits;
  }

  return $info;
}

noexport:; sub new($+;$) {
  my ($class, $dirlist, $label) = @_;
  $label //= join(':', @$dirlist);

  my $cache = MTY::Common::Cache->new(\&search_dir_list_for_file, $label);
  my $this = [ $cache ];

  my %abspath_to_pathfd = ( );

  foreach my $dirname (@$dirlist) {
    if (ref $dirname) {
      # warning('SearchableDirList: ignoring non-path entry "'.($dirname // '<undef>').'"');
      next;
    }

    my $fd = sys_open_path($dirname, undef, O_DIRECTORY);

    if (!defined $fd) {
      warning('Ignoring non-existent or inaccessable search path "'.$dirname.'"');
      next;
    }

    my $abspath = path_of_open_fd($fd);

    if (exists $abspath_to_pathfd{$abspath}) {
      warning('Ignoring duplicate search path "'.$dirname.'"'.
        (($dirname ne $abspath) ? " (absolute path '$abspath')" : ''));

      sys_close($fd);
      next;
    }

    my $stats = get_file_stats_of_fd($fd);
    
    my $searchable_dir_info = [
      $abspath,
      $fd,
      $stats,
      0, # hits in this directory
    ];

    push @$this, $searchable_dir_info;
  }

  $cache->parent($this);
  return bless $this, $class;
}

# (the parent Cache class's get() method is used to query (and update) the cache)

noexport:; sub refresh(+) {
  my ($this) = @_;
  # TODO
}

noexport:; sub invalidate(+;$) {
  my ($this, $path) = @_;
  my $cache = $this->[0];

  return $cache->invalidate($path);
}

noexport:; sub get(++;$) {
  my ($this, $subpaths, $acceptable_types_mask) = @_;
  $acceptable_types_mask //= FILE_TYPE_MASK_ANY;
  my $cache = $this->[0];
  my $found = $cache->get(((is_array_ref $subpaths) ? $subpaths->[0] : $subpaths), $subpaths);
  return $found;
}

noexport:; sub close(+) {
  my ($this) = @_;

  my $cache = $this->[0];
  if (defined $cache) { $cache->flush(); }

  foreach my $info (@$this) {
    next if (!is_array_ref($info));
    my ($abspath, $fd) = @$info;
    sys_close($fd);
    $info = undef;
  }
 }

noexport:; sub DESTROY(+) {
  my ($this) = @_;
  $this->close();
}

my @perl_lib_dirs = @INC;
my $searchable_perl_lib_dirs;

sub find_perl_module($;+) {
  my ($name, $pathlist) = @_;

  $pathlist //= \@perl_lib_dirs;

  if ($name =~ /\.pmc?/oax) {
    # already is a filename: just return its full path
    return resolve_path($name);
  }

  # Remove any .pm suffix so we don't redundantly add it again:
  $name =~ s{\.pmc?$}{}oaxg;
  # Convert :: to / (unless ModuleParentPackage/Module.pm form was used):
  $name =~ s{::|[\.\-\']}{/}oaxg;
  # Add the .pm suffix back in:
  $name .= '.pm';

  # Found relative to the current directory?
  # (Note: don't do this by default since Perl normally puts '.' 
  # at the end of @INC (lowest priority) rather than the start:
  # return realpath($name) if (-e $name);

  # If it was an absolute path yet it wasn't readable as
  # specified, there's no point in searching for it:
  return undef if ($name =~ /^\//);

  $searchable_perl_lib_dirs //= MTY::Filesystem::SearchableDirList->new($pathlist, 'perl_lib_dirs');

  # look for .pmc files before .pm files:
  my @alternatives = ($name.'c', $name);
  return $searchable_perl_lib_dirs->get($name, @alternatives);
}

sub test_searchable_dir_list {
  my $dirlist = [ @INC ];
  prints('dirlist = [ '.join(' ', @$dirlist).' ]'.NL);

  my $searchfor = [qw(MTY/Common/Strings.pm POSIX/2008.pm re.pm)];

  if (1) {
    my $sdl = MTY::Filesystem::SearchableDirList->new($dirlist, 'perl_inc_dirs');
    
    foreach my $target (@$searchfor, @$searchfor) {
      my $abspath = $sdl->get($target) // '???';
      prints('  '.$target.' => '.$abspath.NL);
    }

    prints('---------'.NL);
    $sdl->invalidate('POSIX/2008.pm');

    foreach my $target (@$searchfor) {
      my $abspath = $sdl->get($target) // '???';
      prints('  '.$target.' => '.$abspath.NL);
    }

  } 
}

1;


