# -*- cperl -*-
#
# MTY::Display::ModuleCache
#
# Copyright 2003 - 2014 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::ModuleCache;

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(package_load_hook);

my ($slash_re, $dot_pm_re, $cache_dir, $debug);

BEGIN {
  my $debug = exists $ENV{PERL_CACHE_DEBUG};

  $slash_re = qr{/}oax;
  $dot_pm_re = qr{\.pm\Z}oax;
  # $strip_last_path_component_re = qr{(?> \A / \K | /?) [^/]++ /*+ \Z}oax;
  $strip_last_path_component_re = qr{/ [^/]+ /* \Z}oamsx;

  $cache_dir = undef;
  my $uid = $>;

  my $home_cache_dir = (exists $ENV{HOME}) ? $ENV{HOME}.'/.perlcache/'.$^V.'/' : undef;
  my $tmp_cache_dir = '/tmp/.perlcache/'.$^V.'/';

  push @alternatives, $ENV{PERL_LIB_CACHE}.'/' if (defined $ENV{PERL_LIB_CACHE});
  push @alternatives, '/usr/lib/perl5/.cache/'.$^V.'/';
  push @alternatives, $ENV{HOME}.'/.perlcache/'.$^V.'/' if (exists $ENV{HOME});
  push @alternatives, '/tmp/.perlcache/'.$^V.'/';

  foreach my $dir (@alternatives) 
    { if (-x $dir) { $cache_dir = $dir; last; } }

  if (!defined $cache_dir) {
    my @create_dirs = ($home_cache_dir, $tmp_cache_dir);
    foreach my $dir (@create_dirs) {
      my $parent_dir = ($dir =~ s{$strip_last_path_component_re}{}roamsx);
      if (! -d $parent_dir) {
        prints(STDERR '[Try to create '.$parent_dir.']'."\n") if ($debug);
        mkdir($parent_dir);
      }
      prints(STDERR '[Try to create '.$dir.']'."\n") if ($debug);
      mkdir($dir);
      my ($rc) = mkdir($dir);
      if (-x $dir) { $cache_dir = $dir; last; }
    }
  }

  if (defined $cache_dir) {
    prints(STDERR '[Perl library cache dir is in '.$cache_dir.']'."\n") if ($debug);
  }
}

sub package_load_hook {
  my ($ref_to_this_function, $relative_filename) = @_;
  $relative_filename //= '<undef>';

  my $package = 
    $relative_filename =~ s{$slash_re}{::}roamsxg
      =~ s{$dot_pm_re}{}roamsx;

  my $fd; my $rc;

  $rc = sysopen($fd, $cache_dir.$package, 0);
  if ($rc) {
    prints(STDERR '[Used package '.$package.' ('.$relative_filename.') from '.$cache_dir.$package.']'."\n") if ($debug);
    return (undef, $fd);
  }
    
  my $found = undef;

  foreach my $dir (@INC) {
    next if (substr($dir, 0, 5) eq 'CODE(');
    my $path = $dir.'/'.$relative_filename;
    if (-r $path) {
      $found = $path;
      last;
    }
  }

  if (!defined $found) { die('Cannot find package "'.$relative_filename.'" in @INC'); }

  sysopen($fd, $found, 0)
    || die('Cannot load module '.$found);

  prints(STDERR '[Used package '.$package.' ('.$relative_filename.') from '.$found.']'."\n") if ($debug);

  if (defined $cache_dir) {
    symlink($found, $cache_dir.$package) ||
      warn('Cannot create symlink from '.$found.' to '.$cache_dir.$package);
  }

#  my $prepend_source_code = 
#    'BEGIN { my $self = $INC{\''.$relative_filename.'\'} // \'undef\'; '.
#    'prints(STDERR \'[Used package '.$relative_filename.' => '.$found.']\'."\\n"); '.
#    '}'."\n";
  return (undef, $fd);
  # prints(STDERR $prepend_source_code);
  # return (\$prepend_source_code, $fd);
  # return ($prepend_source_code, $file_handle_with_data, $source_line_generator_func, $state_to_pass_to_generator)
}

BEGIN { use lib \&package_load_hook; };

1;