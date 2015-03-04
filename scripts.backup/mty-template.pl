#!/usr/bin/perl -w
# -*- cperl -*-

use MTY::Common::Common;
use MTY::Common::CommandLine;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Filesystem::Files;
use MTY::Display::Colorize;
use MTY::Display::ColorizeErrorsAndWarnings;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::Scrollable;
use MTY::Display::TextInABox;
use MTY::Display::Tree;
use MTY::Display::TreeBuilder;

my $input_format = 'auto';
my $path_separator = '/';
my $verbose = 0;

my $arg1 = 0;

my %command_line_options = (
  'arg1' => [ \$arg1, 0, [ 'a' ] ],
);

my @command_line_options_help = (
  [ OPTION_HELP_BANNER, B ] => '<Description of this program>',
  [ OPTION_HELP_SYNTAX ] => undef, # use the default automatically generated command syntax description

  [ OPTION_HELP_CATEGORY ] => 'Options',
  'arg1' => 'Description of arg1 option',
);

my ($lines, $invalid_args) = parse_and_check_command_line(%command_line_options, @ARGV, @command_line_options_help);

# code goes here
