#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Common::Symbols
#
# Perl symbol table examination and manipulation
#
# Copyright 2015 Matt T. Yourst <yourst@yourst.com>
#

package MTY::Common::Symbols;

use integer; use warnings; use Exporter qw(import);
use MTY::Common::Common;
use Scalar::Util qw(reftype blessed isdual looks_like_number);
use Symbol;
use B;
#pragma end_of_includes

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(is_constant glob_to_hash glob_to_pairs get_glob_slots get_package_stash
     get_glob_slot_typeids get_symbols_in_package hash_of_constants_in_package
     list_of_constants_in_package symbol_name_and_package_of_glob
     get_glob_slots_by_symbol_and_package
     code_ref_to_sub_function_name_and_package);

sub get_package_stash(;$) {
  no strict qw(refs);
  my ($package) = @_;
  $package //= caller;

  return $package if (is_hash_ref $package);
  my $stash_name = $package.'::';
  return \%{$stash_name};
}

sub symbol_name_and_package_of_glob {
  my ($globref) = @_;
  return (wantarray ? (*{$glob}{NAME}, *{$glob}{PACKAGE}) : *{$glob}{NAME});
}

# This is a stripped down version of similar code in the Sub::Identify package:
sub code_ref_to_sub_function_name_and_package($) {
  my ($coderef) = @_;
  return if (!defined $coderef);
  my $accessor = B::svref_2object($coderef);
  return if (!$accessor->isa('B::CV'));
  return if ($accessor->GV->isa('B::SPECIAL'));
  return (wantarray 
    ? ($accessor->GV->NAME, $accessor->GV->STASH->NAME)
    : $accessor->GV->NAME);
}

sub glob_to_pairs {
  my $obj = \(*{$_[0]});

  if (!defined $obj) { return ( ); }

  alias my $scalar_slot_ref = *{$obj}{SCALAR};
  alias my $scalar_slot = 
    ((defined $scalar_slot_ref) && (defined ${$scalar_slot_ref})) 
      ? ${$scalar_slot_ref} : undef;

  my @slots;
  push @slots, (SCALAR  => *{$obj}{SCALAR})  if (defined $scalar_slot);
  push @slots, (ARRAY   => *{$obj}{ARRAY})   if (defined *{$obj}{ARRAY});
  push @slots, (HASH    => *{$obj}{HASH})    if (defined *{$obj}{HASH});
  push @slots, (CODE    => *{$obj}{CODE})    if (defined *{$obj}{CODE});
  push @slots, (Regexp  => *{$obj}{Regexp})  if (defined *{$obj}{Regexp});
  push @slots, (GLOB    => *{$obj}{GLOB})    if ((defined *{$obj}{GLOB}) && 
                                                   ((*{$obj}{GLOB}) != $obj));
  push @slots, (LVALUE  => *{$obj}{LVALUE})  if (defined *{$obj}{LVALUE});
  push @slots, (FORMAT  => *{$obj}{FORMAT})  if (defined *{$obj}{FORMAT});
  push @slots, (IO      => *{$obj}{IO})      if (defined *{$obj}{IO});
  push @slots, (VSTRING => *{$obj}{VSTRING}) if (defined *{$obj}{VSTRING});

  return @slots;
}

sub glob_to_hash { 
  return { glob_to_pairs(@_) }; 
}

sub get_glob_slots {
  alias my $obj = $_[0];
  my $result_format = $_[1] // 0;
  my $return_typeids_only = ($result_format == -1);
  my $return_pairs = ($result_format == 1);

  # If the glob is undefined (symbol does not exist), return
  # an array with all slots undefined except for the UNDEF
  # typeid, which is a reference to the undef value:
  if (!defined $obj) { return ( ); }

  alias my $scalar_slot_ref = *${obj}{SCALAR};
  my $have_scalar_slot = (defined $scalar_slot_ref) && (defined ${$scalar_slot_ref});
  alias my $scalar_slot = ($have_scalar_slot) ? ${$scalar_slot_ref} : undef;
  my $scalar_slot_type = ($have_scalar_slot) ? (typeof $scalar_slot) : -1;

  if ($return_typeids_only) {
    my @slots = ( );
    push @slots, UNDEF if ((defined $scalar_slot_ref) && (!defined ${$scalar_slot_ref}));
    push @slots, $scalar_slot_type if ($have_scalar_slot);
    push @slots, ARRAY_REF if (defined *{$obj}{ARRAY});
    push @slots, HASH_REF if (defined *{$obj}{HASH});
    push @slots, CODE_REF if (defined *{$obj}{CODE});
    push @slots, REGEXP_REF if (defined *{$obj}{Regexp});
    push @slots, GLOB_REF if (defined *{$obj}{GLOB});
    push @slots, LVALUE_REF if (defined *{$obj}{LVALUE});
    push @slots, FORMAT_REF if (defined *{$obj}{FORMAT});
    push @slots, IO_REF if (defined *{$obj}{FORMAT});
    push @slots, VSTRING_REF if (defined *{$obj}{VSTRING});

    return @slots;
  } else {
    my @slots = ((undef) x 8);

    if ($have_scalar_slot) {
      $slots[$scalar_slot_type] = 
        ($scalar_slot_type == UNDEF) ? (\undef) : $scalar_slot;
    }

    push @slots, (
      *{$obj}{ARRAY},
      *{$obj}{HASH},
      *{$obj}{CODE},
      *{$obj}{Regexp},
      undef, # blessed object pseudo-slot unused
      *{$obj}{GLOB},
      *{$obj}{LVALUE},
      *{$obj}{FORMAT},
      *{$obj}{IO},
      *{$obj}{VSTRING});

    return @slots;
  }
}

sub get_glob_slot_typeids { return get_glob_slots(@_, -1); };

sub get_glob_slots_by_symbol_and_package($;$) {
   my ($symbol, $package) = @_;
   $package //= caller;
 
   no strict 'refs';

   my $stash = get_package_stash($package);

   return ((exists $stash->{$symbol})
     ? get_glob_slots(*{$stash->{$symbol}}) : undef);
}

my @typeid_to_sigil = (
  '',  '$', '$', '$',
  '$', '$', '$', '$',
  '@', '%', '',  '$',
  '',  '',  '$', '',
  '',  '',  ''
);

sub get_symbols_in_package(;+$$) {
  no strict 'refs';
  
  my ($package, $expand_names_with_sigils, 
      $return_format) = @_;
  
  $package //= caller;
  $expand_names_with_sigils //= 0;
  $return_format //= 0;
  $return_actual_slots = ($return_format == 0);
  $return_typeid_list = ($return_format < 0);
  $return_typeid_bitmap = ($return_format < 0);
  
  my $stash = get_package_stash($package);
  
  my %out = ( );
  
  if ($return_actual_slots) {
    foreach my $symbol (%$stash) {
      my @slots = get_glob_slots(*{$stash->{$symbol}});
      if ($want_sigil_names) {
        foreach my $i (0..$#slots) {
          next if (!defined $slots[$i]);
          my $name_with_sigil = $typeid_to_sigil[$i].$symbol;
          $out{$name_with_sigil} = $slots[$i] if (!exists $out{$name_with_sigil});
        }
      } else {
        $out{$symbol} = [ @slots ];
      }
    }
    $symbol_to_type_bitmask{$symbol} = $valid_slots;
  } else { # returning typeid lists or bitmaps for each symbol name
    foreach my $symbol (%$stash) {
      my @slots = get_glob_slots(*{$stash->{$symbol}}, 1);
      my $result;
      if ($return_typeid_bitmap) {
        $result = 0;
        foreach my $typeid (@slots) { $result |= (1 << $typeid); }
      } else { # want array of valid typeids
        $result = [ @slots ];
      }
      if ($want_sigil_names) {
        foreach my $typeid (@slots) { 
          # assign ref to typeid array to each sigil prefixed name:
          my $name_with_sigil = $typeid_to_sigil[$typeid].$symbol;
          $out{$name_with_sigil} = $result if (!exists $out{$name_with_sigil});
        }
      } else { # only assign to hash entry for un-prefixed symbol name
        next if (!defined $slots[$i]);
        $out{$symbol} = $result;
      }
    }
  }
  
  return \%out;
}

#
# is_constant($name, $package):
# Returns 1 if the symbol $name is a constant in package $package,
# or returns 0 if the symbol doesn't exist or it isn't a constant.
#
# Note: be careful when evaluating what appears to be a constant 
# (but is really a sub) in any security sensitive or privileged
# code that lets an unprivileged user specify a (supposedly) 
# constant symbol's name to look up and evaluate.
#
# $name = symbol name of desired constant
#
# $package = package name (delimited by '::')
#            (if unspecified, "main" is the default package)
#
sub is_constant($;$) {
  my $name = $_[0];
  my $package = $_[1] // caller;

  my $fullname = $package.'::'.$name;
  return (exists $constant::declared{$fullname});
}

sub list_of_constants_in_package(;$) {
  my $package = $_[0] // caller;
  my $stash = $package.'::';
  my @list;

  foreach my $name (keys %$stash) {
    my $fullname = $package.'::'.$name;
    push @list,$name if (exists $constant::declared{$fullname});
  }

  return (wantarray ? @list : \@list);
}

sub hash_of_constants_in_package(;$) {
  my $package = $_[0] // caller;
  my $stash = $package.'::';
  my %hash;

  foreach my $name (keys %$stash) {
    my $fullname = $package.'::'.$name;
    next unless (exists $constant::declared{$fullname});
    #%hash{$name} = $sub->();
  }

  return (wantarray ? %hash : \%hash);
}

1;