#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::MakeAnalyzer::MakefileParser
#
# Parse the database of make rules and recipes output of 'make -p' 
# so it can be saved and reloaded to accelerate make's performance
# on complex collections of many makefiles, or analyzed for many
# other useful applications
#
# Copyright 2003-2014 Matt T. Yourst <yourst@yourst.com>. All rights reserved.
#

package MTY::MakeAnalyzer::MakefileParser;

use integer; use warnings; use Exporter::Lite;

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw();

use MTY::MakeAnalyzer::Common;
use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::RegExp::Define;

1;
