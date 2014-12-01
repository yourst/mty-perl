#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Filesystem::SearchableDirList
#
# Copyright 1997 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Filesystem::SearchableDirList;

use integer; use warnings; use Exporter::Lite;

preserve:; our @EXPORT = 
  qw(find_perl_module test_searchable_dir_list);

use MTY::System::POSIX;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Common::Cache;
#use MTY::Common::DirEntryCache;
use MTY::Filesystem::FileStats;
use MTY::Filesystem::EnhancedFileStats;
use MTY::RegExp::FilesAndPaths;

#use parent 'MTY::Common::Cache';

#
# search_list_of_directories_for_file($filename, @dirlist):
#
# $filename may be the trailing part of a longer path (e.g. to find
# "subdir/subsubdir/filename.ext" in a list of directories, e.g. as
# "/absolute/dir/in/which/we/found/subdir/subsubdir/filename.ext")
#

# SUPER::__field_count__ => 7:

noexport:; use constant {
  cache        => 0,
  absdirs      => 1,   # fully resolved absolute path of each directory in dirlist
  basefds      => 2,   # O_PATH file descriptors corresponding to each directory in dirlist
  timestamps   => 3,   # absolute directory path (includes both stem in absdirs *and* any explicitly queried subdirectories) => stat modification timestamp (mtime) of that directory
};

noexport:; sub search_dir_list_for_file(+$) {
  my ($this, $filename) = @_;
  #print(STDERR 'search_dir_list_for_file: args = [ '.join(', ', @_).' ]'.NL);

  my $fdlist = $this->[basefds];
  my $absdirs = $this->[absdirs];
  my $index = 0;

  #print(STDERR '=> this '.$this.' $basefds = '.join(', ', @{$this->[basefds]}).NL);

  foreach $fd (@$fdlist) {
    #print(STDERR '...search absdir #'.$index.' = '.($absdirs->[$index]).' with pathfd '.$fd.'...'.NL);
    if (path_exists_relative_to_dir_fd($fd, $filename, 1)) {
      return $absdirs->[$index].'/'.$filename;
    }
    $index++;
  }

  return undef;
}

noexport:; sub dirlist($) {
  my ($this) = @_;
  my $list = $this->[absdirs];
  return (wantarray ? @$list : $list);
}

noexport:; sub new($+;$) {
  my ($class, $dirlist, $label) = @_;
  $label //= join(':', @$dirlist);

  my $cache = MTY::Common::Cache->new(\&search_dir_list_for_file, $label);

  my $absdirs = [ ];
  my $basefds = [ ];
  my $timestamps = { };

  my %abspath_to_pathfd = ( );

  foreach $dirname (@$dirlist) {
    my ($fd, $abspath) = resolve_and_open_path($dirname, undef, O_DIRECTORY);

    next if ((!defined $fd) || (!defined $abspath));

    if (exists $abspath_to_pathfd{$abspath}) {
      sys_close($fd);
      next;
    }

    my $mtime = get_mtime_of_fd($fd);
    $abspath_to_pathfd{$abspath} = $fd;
    $timestamps{$abspath} = $mtime;

    push @$absdirs, $abspath;
    push @$basefds, $fd;
  }

  my $this = [ $cache, $absdirs, $basefds, $timestamps ];
  $cache->parent($this);

  return bless $this, $class;
}

# (the parent Cache class's get() method is used to query (and update) the cache)

noexport:; sub refresh($) {
  my ($this) = @_;
  my $absdirs_to_refresh = (scalar @_) ? \@_ : $this->[absdirs];
  #foreach my $dir (keys @$absdirs_to_refresh) {    
  #}
}

noexport:; sub invalidate($;$) {
  my ($this, $path) = @_;
  return ($this->[cache])->invalidate($path);
}

noexport:; sub get($;$) {
  my ($this, $subpath) = @_;
  my $cache = $this->[cache];
  return $cache->get($subpath);
}

noexport:; sub close($) {
  my ($this) = @_;
  foreach my $fd (@{$this->[basefds]}) { sys_close($fd); }
  $this->[basefds] = undef;
}

noexport:; sub DESTROY($) {
  my ($this) = @_;
  $this->close();
}

my @perl_lib_dirs = ( );
my $searchable_perl_lib_dirs;

sub find_perl_module($;+) {
  my ($name, $pathlist) = @_;

  # print("Called find_perl_module($name, ".($pathlist ? join(' ', @$pathlist) : 'undef').")".NL);

  $pathlist //= \@perl_lib_dirs;

  if ($name =~ /\.pm/oax) {
    # already is a filename: just return its full path
    return realpath($name);
  }

  # Remove any .pm suffix so we don't redundantly add it again:
  $name =~ s/\.pm$//oaxg;
  # Convert :: to / (unless ModuleParentPackage/Module.pm form was used):
  $name =~ s{::|\.|-}{/}oaxg;
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

  return $searchable_perl_lib_dirs->get($name);
}

sub test_searchable_dir_list {
  my $dirlist = [ @INC ];
  print('dirlist = [ '.join(' ', @$dirlist).' ]'.NL);

  my $searchfor = [ 'MTY/Common/Strings.pm', 'POSIX/2008.pm', 're.pm' ];

  if (1) {
    my $sdl = MTY::Filesystem::SearchableDirList->new($dirlist, 'perl_inc_dirs');
    
    foreach my $target (@$searchfor, @$searchfor) {
      my $abspath = $sdl->get($target) // '???';
      print('  '.$target.' => '.$abspath.NL);
    }

    print('---------'.NL);
    $sdl->invalidate('POSIX/2008.pm');

    foreach my $target (@$searchfor) {
      my $abspath = $sdl->get($target) // '???';
      print('  '.$target.' => '.$abspath.NL);
    }

  } 
}

1;







