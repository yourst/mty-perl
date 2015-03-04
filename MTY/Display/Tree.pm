#!/usr/bin/perl -w
# -*- cperl -*-
#
# MTY::Display::Tree
#
# Copyright 2003 - 2015 Matt T. Yourst <yourst@yourst.com>
#

=head1 SYNOPSIS

The Display::Tree package prints or formats hierarchical trees using
colors, symbols and box drawing characters for tree branches. Tree
nodes are described using a set of nested arrays (see "TREE STRUCTURE"
section below), and can be printed to a file handle using the
print_tree() function, or formatted as a multi-line string or an array
of lines using format_tree().

It includes numerous advanced formatting facilities, the ability to
make dynamic substitutions into a pre-defined tree template, and a
powerful callback facility for dynamically generating nodes and labels
if desired. Its output is amongst the most visually appealing and
polished of any available tree formatting engine, fully leveraging
Unicode symbols and fonts, and RGB true color console escapes in
modern terminal programs.

The companion package Display::TreeBuilder can also be used to
automatically create trees from dependency graphs, indented lines
of text, filesystem paths and more.

=head1 TREE OUTPUT FORMAT

Each line of the printed or formatted rendering of a tree structure
comprises three components in the following left to right order:

- Prefix (optional) which can be different for each node and may contain
  commands for setting the line's background color, text like a node number,
  or other user defined content applying to the entire line. Even and odd
  lines may be set to automatically use different prefixes.

- Branch of the tree constructed using Unicode and/or ANSI line drawing
  characters. The branch color and style may be changed for each node
  and/or sub-nodes using the TREE_CMD_BRANCH_xxx commands described below.

- Symbol for the node, which is a character or short string representing an 
  icon for that type of node (by default a right facing triangle)

- Label for the node, comprising a text string defined either literally 
  or optionally in parts, where each part may reference an externally
  defined array, string or scalar to facilitate easy reuse of trees
  as templates for placeholder substitution each time they are printed.

=head1 USEFUL TOOLS FOR CONSTRUCTING TREES

In addition to constructing trees from scratch using the data structures
and commands described below, the TreeBuilder package provides convenient
functions for automatically creating highly configurable trees from data
sets like dependency graphs, indented lines of text, filesystem paths
and more. The resultant trees can be further refined and printed just
like trees constructed node by node.

=head1 TREE STRUCTURE DEFINITION

=head1 Node Definition Arrays

The tree structure is specified by a recursive set of arrays of references to 
scalars or other arrays, where each array defines one tree node as follows:

- [0] label (string or reference to array of strings and/or commands)

- [1, 2, ...] sub-nodes, each of which may be either a text string (for leaf
  nodes not requiring any formatting commands) or a reference to an array
  with this same [label, sub-node, sub-node, ...] structure

=head2 Node Labels

The label element is either a single scalar text string, or a reference to 
an array whose elements are any mix of:

- label text strings, concatenated without separators when printed, but kept
  separately to simplify dynamic manipulation of the tree and substitution
  of placeholder elements if desired, or:

- tree control and formatting commands (see the TREE COMMANDS section below)

=head3 Multi-Line Labels

The label may contain multiple lines (separated by newline (NL) characters);
all lines of the label will be properly indented to line up with the first
line, depending on the indentation depth of the label's node. For multi-line
labels, the array format is mandatory, and each line must be in a separate
array element (or multiple separate array elements, which append to the
current line, and only the final element in each line ends with a newline).

=head2 Text Strings in Labels and Command Arguments

=head3 Strings, Characters and Symbols

In all labels or tree command arguments (unless otherwise noted), text strings
may comprise one or more characters, either as strings ('text' or "text"),
Unicode characters (e.g. chr(0xABCD) or "\U{ABCD}"), named symbols chosen from
amongst the library provided by the PrintableSymbols package or defined by the 
user, interpolated variables ("... $var ..." or 'before '.$var.' after', but
remember that variables are interpolated when the tree is defined, not when it
is later printed or formatted as text; see below for how to do this), or any
other Perl string construct.

=head3 Colors and Formatting

Each string may also contain one or more color or formatting markups, either
using the '%<color>' form within the string (e.g. '%R%Ured underlined%!U%X'),
or through variables or equivalent constants defined in the Colorize package
(e.g. "before $Ggreen text$X after" or 'before '.G.'green text'.X.'after').
All of these methods will ultimately insert ANSI color code escapes into the
resultant string. See the documentation for the Colorize package for details.

If the color or formatting of portions of each label need to be dynamically
changed for certain nodes (e.g. to highlight them) after creating the tree
structure, string arrays and references may be useful (see below).

=head3 Concatenated String Arrays

For string and array based labels, and as command arguments which accept 
"string arrays and references" as noted in each command's description, a string
argument may be replaced by an array of sub-strings.

=head3 References to Strings or Numeric Scalars

References to a strings or numeric scalars may also be used, either instead of
an array reference, or as one of the elements within a referenced array. 

=head3 Using Arrays and References in Labels

Both array elements and references to external strings or numeric scalars will
be concatenated without separators each time the tree is printed or formatted.

Since these are defined as separate elements in the tree structure, they can
facilitate dynamic manipulation of the tree, or reuse of a pre-defined tree
structure as a template by including references to external placeholders and
then altering the referenced arrays or scalars each time the tree is printed.

This can be done either by changing the individual array elements or scalar
variables declared outside the scope of the tree, or by changing the original
references in node label(s) themselves to point to different values or arrays.

If modifying variables defined outside the tree, remember that overwriting a
reference variable with another reference will disconnect it from the tree!
External variables should be actual arrays (@name = (elem1, ...)) or scalars
($name = 'value...'), with the tree nodes containing the only references to
those variables unless you are certain other external references will never
be redirected, since this will create subtle bugs where the tree remains
the same when printed even after overwriting placeholder variables.

=head1 TREE COMMANDS

=head2 Command Arrays

Tree commands are elements of each node's label array (if commands are used,
the label must be specified as an array and cannot use a simple text string).
Each command uses one of the following formats:

  - text string in the form "%{command=arg1,arg2,...}', which may be easier
    if the tree is defined by text read from the user instead of being  
    constructed programatically by other code

  - array reference (preferred, since this is faster to process) of the form
    [ command, arg1, arg2, ... ], where the command is one of the TREE_CMD_xxx 
    constants.

Since commands may be array references, commands and their arguments may be
easily changed dynamically before each time the tree is printed by simply
redirecting the corresponding reference to a different command array. The
same command array can (and should) be defined once and referenced by many
nodes, since this can save considerable memory for very large trees whose
nodes frequently use the same commands and arguments every time.

=head2 Attribute Inheritance

If a given node uses commands to set any attributes (unless noted below
for certain commands), all sub-nodes of that node will use the same 
attributes unless they use the same commands to override these 
inherited attributes with different values. 

For example, if a node sets its branch style, color or symbol, every
sub-node within the tree branch rooted at that node will use these
same attributes by default.

Commands which use these these semantics include:

- TREE_CMD_SYMBOL
- TREE_CMD_PREFIX
- TREE_CMD_BRANCH_COLOR
- TREE_CMD_BRANCH_STYLE
- TREE_CMD_BRANCH_DASHED
- TREE_CMD_SUB_BRANCH_COLOR
- TREE_CMD_SUB_BRANCH_STYLE
- TREE_CMD_SUB_BRANCH_DASHED
- TREE_CMD_HORIZ_BRANCH_LENGTH

and any other commands described in later sections.

For commands where multiple instances per node label are concatenated together
(see next section), the inherited value is the final concatenated result.

=head2 Multiple Instances of Commands which Concatenate Strings

If a given node's label array contains multiple instances of commands which
define strings, unless stated below, the strings given as the arguments to
each command will be concatenated together to form the final string used
for the corresponding attribute's value. For example, if a label contains:

  [ TREE_CMD_PREFIX, "part1" ],
  [ TREE_CMD_PREFIX, "part2" ],
  ...,
  [ TREE_CMD_PREFIX, "part3 "],

the final prefix will be printed as "part1part2part3".

Commands which use these concatenating semantics include:

- TREE_CMD_LABEL
- TREE_CMD_PREFIX
- TREE_CMD_EVEN_ODD
- TREE_CMD_EVEN_ODD_PREFIX

and any other commands described in later sections.

(Note that the "even/odd" commands - which apply different attributes to
every other output line - will separately concatenate the strings for
even and odd lines).

=head2 Multiple Instances of Commands which Override Attributes

In contrast, each instance of a tree command which sets a scalar value
will override the node's corresponding attribute, such that the final
attribute value is set by the last corresponding command in sequence.

However, if the command propagates its attribute to sub-nodes by default
(see Attribute Inheritance section above), only the first instance of
the command in a given node's label will be propagated to sub-nodes;
subsequent instances will only alter the node itself, not its entire
sub-tree.

This may be useful for setting a default symbol and then overriding it
only for certain nodes (although this is more efficiently achieved by
simply changing the original command for each node if its position within 
the label array is known.

Commands with these semantics include:

- TREE_CMD_SYMBOL
- TREE_CMD_BRANCH_COLOR
- TREE_CMD_BRANCH_STYLE
- TREE_CMD_BRANCH_DASHED
- TREE_CMD_SUB_BRANCH_COLOR
- TREE_CMD_SUB_BRANCH_STYLE
- TREE_CMD_SUB_BRANCH_DASHED
- TREE_CMD_HORIZ_BRANCH_LENGTH

and any other commands described in later sections.

=head1 TREE COMMAND REFERENCE

=head2 TREE_CMD_LABEL ("%{label=...}" in text input format)

This command is implicit whenever a string, reference to a scalar
or array reference is used within a node's label or label array,
but may be useful as an explicit command to append text onto an
existing label. However, in most cases it should not be needed.

The TREE_CMD_LABEL command uses the concatenation semantics in
the "Multiple Instances of Commands which Concatenate Strings" 
section above. However, labels are never inherited by sub-nodes.

=head2 TREE_CMD_SYMBOL ("%{symbol=...}" in text input format)

Overrides the node's default character symbol (typically a solid right facing
triangle for a node with subnodes, or an empty triangle outline for a leaf). 

In the form [ TREE_CMD_SYMBOL, <nodesym>, <leafsym> ]:

- nodesym: symbol to use if the node contains sub-nodes
  (optional: defaults is a solid right facing triangle)

- leafsym: symbol to use if the node is a leaf without any sub-nodes
  (optional: default is the nodesym symbol if specified, or an open
  right facing triangle outline otherwise)

Both nodesym and leafsym may be text strings, string arrays or references
as defined in the "Text Strings in Labels and Command Arguments" section.

The TREE_CMD_SYMBOL command uses the inheritance semantics described in the 
"Attribute Inheritance" section above, and the override semantics described
in the "Multiple Instances of Commands which Override Attributes" section.

=head2 TREE_CMD_PREFIX ("%{prefix=...}" in text input format)

Each line of the printed or formatted rendering of a tree structure may
optionally start with a prefix, which can be different for each node and
may contain any user defined text string, colors or formatting.

The prefix facility is useful for setting each line's background color,
text like a node number for later reference, or other content applying
to the entire line. Do not use the prefix to set foreground colors, since
these will be changed when the branches and symbol are printed; the label
must always set its own foreground colors. However, background colors
will be retained for the entire line until changed by the symbol or label.

The TREE_CMD_PREFIX command uses the inheritance semantics described in the 
"Attribute Inheritance" section above, and the concatenation semantics in
the "Multiple Instances of Commands which Concatenate Strings" section.

=head2 TREE_CMD_EVEN_ODD_PREFIX ("%{even_odd_prefix=...}" in text input format)

Sets a different prefix for every other output line, where the first argument
is used for even lines 0, 2, 4, 6, ... and the second argument is used for odd
lines 1, 3, 5, 7, .... This is useful for setting the background color to
alternating colors or light and dark shades to make it easier for the viewer
to read longer labels or labels with many separate fields.

The TREE_CMD_EVEN_ODD_PREFIX command uses the inheritance semantics described 
in the "Attribute Inheritance" section above, and the concatenation semantics 
in the "Multiple Instances of Commands which Concatenate Strings" section,
but the even and odd strings will be concatenated separately.

=head2 TREE_CMD_EVEN_ODD ("%{even_odd=...}" in text input format)

Equivalent to the TREE_CMD_LABEL command, but uses a different label for
even vs odd lines (or more commonly a different foreground color, rather 
than changing the actual text, which can be in a separate element of the 
label array so it remains the same regardless of which line number the
node is printed on).

The TREE_CMD_EVEN_ODD is not inherited by sub-nodes, but still follows
the concatenation semantics in the "Multiple Instances of Commands which 
Concatenate Strings" section; the even and odd strings are concatenated
separately in this case.

=head2 TREE_CMD_BRANCH_COLOR ("%{branch_color=...}" in text input format)

Sets the foreground color of the line drawing symbols used to render each
node's branch (i.e. vertical lines with a right facing horizontal branch,
or an L-shaped lower left corner for the last sub-node). The only argument
should be an ANSI color escape code sequence, such as the color constants
R/G/B/C/M/Y/K/W/X or U/UX, or the fg_color_rgb, scale_rgb_fg, etc. functions
in the Colorize package (see this package's documentation for details).

The TREE_CMD_BRANCH_COLOR command uses the inheritance semantics described 
in the "Attribute Inheritance" section above, and the override semantics 
in the "Multiple Instances of Commands which Override Attributes" section.

=head2 TREE_CMD_BRANCH_STYLE ("%{branch_style=...}" in text input format)

Sets the style of the line drawing symbols used to render each node's
output branch (i.e. vertical lines with a right facing horizontal
branch, or an L-shaped lower left corner for the last sub-node). The
vertical continuation lines of higher level parent nodes (in the style
and color of those nodes) is independently printed to the left of the
node's own branch symbols, which are followed on the right by the node's
symbol and finally its label.

The first argument specifies the branch style for nodes with sub-nodes,
while the second argument (if present) specifies the style for leaf nodes.

Styles are specified by one of the following text strings:

- 'single':    single thin lines with square corner for the last node
- 'rounded':   single thin lines with rounded corner for the last node
- 'double':    two adjacent thin lines
- 'thick':     single thick line
- 'dashed':    dashed lines
- 'dotted':    dotted lines

The TREE_CMD_BRANCH_STYLE command uses the inheritance semantics described 
in the "Attribute Inheritance" section above, and the override semantics 
in the "Multiple Instances of Commands which Override Attributes" section.

=head2 TREE_CMD_BRANCH_DASHED ("%{branch_dashed=...}" in text input format)

Prints the horizontal portion of the node's branch with dashes rather than
a continuous line, even if the style is not 'dashed' or 'dotted'. The vertical
portion of the tree branch uses the defined style.

Note that this will only appear properly when using the 'single', 'rounded'
or 'thick' styles (otherwise there will be a visual discontinuity between
the right facing stem of the vertical line and the rest of the horizontal
branch). This attribute is more obvious when using a longer branch length
set by TREE_CMD_HORIZ_BRANCH_LENGTH. This command is generally only used
for leaf nodes which are different from normal leaf nodes in some way.

The TREE_CMD_BRANCH_DASHED command uses the inheritance semantics described 
in the "Attribute Inheritance" section above, and the override semantics 
in the "Multiple Instances of Commands which Override Attributes" section.

=head2 TREE_CMD_BRANCH_SKIP ("%{branch_skip=...}" in text input format)

Skips printing the horizontal portion of the node's branch altogether,
and only prints the vertical portion, in effect "skipping" the branch
while still printing the label itself. This is useful when the label
is a comment on or continuation of the previous node's label, rather
than a truly separate node, yet simply extending the previous node's
label with another line or adding a sub-node to it was undesirable.

The first and only optional argument may be a boolean value where
true or 1 (the default if no argument is given) will skip the branch,
and false or 0 (the default) will print the branch (but this is only
useful if another TREE_CMD_BRANCH_SKIP command is overriding an
earlier instance of this command for the node).

The TREE_CMD_BRANCH_SKIP command is not inherited (and should only be
used on leaf nodes, never with nodes containing sub-nodes), and the
override semantics in the "Multiple Instances of Commands which 
Override Attributes" section (only if an argument is provided).

=head2 TREE_CMD_SUB_BRANCH_{COLOR|STYLE|DASHED} ("%{sub_branch_color=...}" in text input format)

Equivalent to the TREE_CMD_BRANCH_{COLOR|STYLE|DASHED} commands (see above), 
but only overrides the corresponding attributes of the branches to sub-nodes
of this node; the branch to the node itself continues to use the branch color
defined by its parent node, or the color defined by a separate optional 
TREE_CMD_BRANCH_COLOR command (which if present must appear before the 
TREE_CMD_SUB_BRANCH_COLOR command; otherwise the TREE_CMD_BRANCH_COLOR 
command will also override the sub-branch colors).

These commands use the inheritance semantics described in the "Attribute
Inheritance" section above, and the override semantics in the "Multiple
Instances of Commands which Override Attributes" section (but unlike the
corresponding TREE_CMD_BRANCH_* commands, the node itself is unaffected).

=head2 TREE_CMD_HORIZ_BRANCH_LENGTH ("%{horiz_branch_length=...}" in text input format)

Sets the length in characters of the horizontal portion of the branch that
connects the node (and by default its sub-nodes) to the tree's trunk. The
default without this option is a single horizontal line character width
in the selected branch style (the entire set of branch symbols comprises
this length plus the additional vertical or lower left corner symbol, not
including any vertical continuation lines from higher level parent nodes).
The TREE_CMD_HORIZ_BRANCH_LENGTH command uses the inheritance semantics 
described in the "Attribute Inheritance" section above, and the override 
semantics in the "Multiple Instances of Commands which Override Attributes" 
section.

=head2 TREE_CMD_COLUMN ("%{column=...}" in text input format)

This command causes the tree printer to continue printing the
remaining text after this command at the column number specified
by the first and only required argument, relative to the absolute
first column in the line (i.e. left edge of the screen).

Specifically, %{column=N} will skip to the same column N regardless
of how deeply the tree may be indented at that point, so the output
remains properly lined up whether the tree is only one level deep
or a hundred levels deep. (In practice, if a given node is already
so far indented that its label starts after the column number N
specified by %{column=N}, the column directive will be ignored.

=head2 TREE_CMD_FIELD ("%{field=...}" in text input format)

Starts a new field which is automatically aligned to the starting 
column of any corresponding fields in any other nodes. The optional
first argument specifies a numerical identifier for this field (e.g.
0, 1, 2, ...), which simplifies placing text into the same field in
many nodes, some of which may skip certain fields.

The optional second argument (which requires the field number in
the first argument) specifies the alignment of the field, using
one of the constants ALIGN_LEFT, ALIGN_RIGHT, ALIGN_CENTER. By
default, left alignment is used. If subsequent nodes place text
into the same field, but omit the alignment, the previously set
alignment (or ALIGN_LEFT if no node specifies the alignment for
the field) remains set for that field.

The column widths are automatically sized using the same rules (and 
in fact the sameimplementation) as in the Display::Table package; 
see that package's documentation for details.

=head2 TREE_CMD_MAX_FIELD_WIDTH ("%{max_field_width=...}" in text input format)

Specifies the maximum width in characters (the second argument) of the field 
specified by the first argument; both arguments are mandatory.

=head2 TREE_CMD_SUBNODE_COUNT ("%{subnode_count}" in text input format)

Replaced in the printed output by the integer number of sub-nodes of this node.

=head2 TREE_CMD_DIV ("%{div=...}" in text input format)

Prints a horizontal divider line between the label of the previous node 
(if any) and this node. The color of the divider may be specified by the
optional first argument, and the style by the optional second argument
(using the same style names as for tree branches, although dotted or
dashed in a less visible color is often a more appealing choice).

=head2 TREE_CMD_INCLUDE ("%{include=...}" in text input format)

Includes multiple commands into the node's label, where each argument is a
reference to one command (i.e. an array of the form [command, arg1, ...]).
This command is useful when multiple commands are typically repeated for
many nodes, and the user desires either to save memory on large trees,
or intends to replace a series of many commands within various nodes.

=head2 TREE_CMD_USER_DATA ("%{user_data=...}" in text input format)

This command is defined as a no-op; the arguments to the command are
ignored and may be used for whatever the caller desires. Typically
TREE_CMD_USER_DATA is used to attach metadata to each node to avoid
maintaining a separate hash table or array to map tree nodes to
this metadata; alternatively it may contain text comments for 
debugging purposes.

=head2 TREE_CMD_CALL_FUNCTION ("%{call_function=...}" in text input format)

Replaces this command with the list of one or more commands or label strings
returned by the function specified by the code reference in the first argument.
This function is called every time the node in the tree is printed or 
formatted, and is passed an argument list comprising:

- argument 0:  reference to the node containing this command
- argument 1:  reference to the node's parent node
- argument 2:  reference to the tree's root node
- argument 3:  output line number of this node
- argument 4, 5, 6, ...:  any additional optional arguments in elements
     1, 2, 3, ..., respectively of the command's argument list.

The function should return either a list of one or more strings and/or
commands to include in place of the TREE_CMD_CALL_FUNCTION command
(similar to TREE_CMD_INCLUDE's semantics), or may return an empty list
or undef to include nothing in the label in place of this command.

Any TREE_CMD_CALL_FUNCTION commands are called and their output is substituted
before any other commands in the node's label are processed (i.e. at the same
time TREE_CMD_INCLUDE commands are handled).

This means the function is free to completely replace or dynamically generate
any part of of the node's definition, including modifying, deleting or
dynamically generating subnodes, or modifying or replacing the entire label.

After the function returns, this command's code will check if the function
replaced the node's label reference; if so, the entire label will be re-checked
for any TREE_CMD_CALL_FUNCTION or TREE_CMD_INCLUDE commands, which will be
invoked a second time if found. To avoid an infinite loop, if the function
does replace the entire label, it should always change the reference to
the label itself (i.e. the node's first array element), and must ensure the
label no longer contains any TREE_CMD_CALL_FUNCTION commands. The function
should *never* modify the referenced label array in place, since this could
cause the tree formatting engine's loop over that array to behave erratically
upon returning to it.

The TREE_CMD_CALL_FUNCTION facility provides an extraordinarily powerful
means of dynamically generating trees using a caller driven programming model,
rather than needing to pre-generate the entire tree structure ahead of time.

For example, to print a directory tree, print_tree could be invoked with
a single root node with no sub-nodes and a label comprising only a single
TREE_CMD_CALL_FUNCTION command. The specified function would read the 
directory and dynamically insert leaf sub-nodes for any files, and nodes
themselves containing TREE_CMD_CALL_FUNCTION commands for each subdirectory.
The tree engine would then effectively drive the recursive exploration of
the filesystem by iterating through the node for each subdirectory. In the
dynamically generated nodes with TREE_CMD_CALL_FUNCTION commands for each
subdirectory, the caller should typically add a pre-defined argument to
the command's argument list for the absolute path of the sub-directory;
this will be passed to the subsequently called function so it knows
which absolute directory to process.

This facility could also leverage continuations or coroutines (as in the
Coro package) to effectively return to whatever called print_tree in the
first place, and dynamically generate and print portions of the tree on
the fly as the program calls special functions to add nodes, which would
jump back into where the specified callback function left off, allowing
it to return the node to the tree engine and continue processing the
tree until another subnode was encountered, which would in turn jump
back into the external code stream, and so on. 

This highly advanced application is left as an exercise to the reader...

=cut

package MTY::Display::Tree;

use integer; use warnings; use Exporter qw(import);

use MTY::Common::Common;
use MTY::Common::Hashes;
use MTY::Common::Strings;
use MTY::Display::Colorize;
use MTY::Display::ColorCapabilityCheck;
use MTY::Display::ANSIColorREs;
use MTY::Display::PrintableSymbols;
use MTY::Display::PrintableSymbolTools;
use MTY::Display::TextInABox;
use MTY::Display::Table;
use MTY::RegExp::Define;
use MTY::RegExp::Tools;
use MTY::RegExp::Blocks;
use MTY::RegExp::Numeric;
use MTY::RegExp::Strings;
use MTY::RegExp::PerlSyntax;
#pragma end_of_includes

our @EXPORT = # (auto-generated by perl-mod-deps)
  qw(BRANCH NO_BRANCH HORIZ_LINE print_tree LAST_BRANCH format_tree
     %tree_styles HORIZ_DASHED TREE_CMD_DIV subtree_label tree_to_lines
     TREE_CMD_FIELD TREE_CMD_LABEL TREE_CMD_COLUMN TREE_CMD_PREFIX
     TREE_CMD_SYMBOL subtree_to_text NO_BRANCH_DASHED TREE_CMD_INCLUDE
     $tree_vert_dashed TREE_CMD_EVEN_ODD $tree_branch_color $tree_horiz_dashed
     TREE_CMD_USER_DATA label_of_tree_node $tree_leading_space
     $tree_leaf_indicator $tree_node_indicator $tree_root_indicator
     TREE_CMD_BRANCH_SKIP TREE_CMD_BRANCH_COLOR TREE_CMD_BRANCH_STYLE
     $tree_pre_branch_color TREE_CMD_BRANCH_DASHED TREE_CMD_CALL_FUNCTION
     TREE_CMD_SUBNODE_COUNT $tree_pre_branch_spacer %tree_command_name_to_id
     TREE_CMD_EVEN_ODD_PREFIX TREE_CMD_MAX_FIELD_WIDTH
     $tree_horiz_branch_length TREE_CMD_SUB_BRANCH_COLOR
     TREE_CMD_SUB_BRANCH_STYLE $tree_branch_to_leaf_style
     $tree_branch_to_node_style $tree_leaf_indicator_color
     $tree_node_indicator_color $tree_root_indicator_color
     $tree_subnode_count_prefix $tree_subnode_count_suffix
     TREE_CMD_SUB_BRANCH_DASHED TREE_CMD_HORIZ_BRANCH_LENGTH
     $tree_subnode_count_if_no_subnodes);

#
# Tree node commands (in first element of label array):
#
use constant enum qw(
  TREE_CMD_LABEL
  TREE_CMD_SYMBOL
  TREE_CMD_PREFIX
  TREE_CMD_EVEN_ODD_PREFIX
  TREE_CMD_EVEN_ODD
  TREE_CMD_BRANCH_COLOR
  TREE_CMD_BRANCH_STYLE
  TREE_CMD_BRANCH_DASHED
  TREE_CMD_BRANCH_SKIP
  TREE_CMD_SUB_BRANCH_COLOR
  TREE_CMD_SUB_BRANCH_STYLE
  TREE_CMD_SUB_BRANCH_DASHED
  TREE_CMD_HORIZ_BRANCH_LENGTH
  TREE_CMD_COLUMN
  TREE_CMD_FIELD
  TREE_CMD_MAX_FIELD_WIDTH
  TREE_CMD_SUBNODE_COUNT
  TREE_CMD_DIV
  TREE_CMD_INCLUDE
  TREE_CMD_USER_DATA
  TREE_CMD_CALL_FUNCTION
);

#
# Defaults:
#
our ($tree_branch_to_node_style, $tree_branch_to_leaf_style, $tree_branch_color,
     $tree_node_indicator_color, $tree_leaf_indicator_color, $tree_root_indicator_color,
     $tree_node_indicator, $tree_leaf_indicator, $tree_root_indicator, $tree_horiz_dashed,
     $tree_vert_dashed, $tree_leading_space, $tree_pre_branch_spacer, $tree_pre_branch_color,
     $tree_horiz_branch_length, $tree_subnode_count_prefix, $tree_subnode_count_suffix,
     $tree_subnode_count_if_no_subnodes);

my $use_rgb_color;

BEGIN {
  #
  # These need to be pre-computed at compile time so TreeBuilder 
  # and similar packages can declare constants that use their
  # default values (even though those constants will remain the
  # same even if the user later changes these defaults):
  #
  $use_rgb_color = (is_console_color_capable() >= ENHANCED_RGB_COLOR_CAPABLE) ? 1 : 0;
  my $darkK = ($use_rgb_color) ? fg_color_rgb(96, 96, 96) : K;

  $tree_branch_to_node_style = 'single';
  $tree_branch_to_leaf_style = 'single';
  $tree_branch_color         = ($use_rgb_color) ? fg_color_rgb(96, 64, 192) : B;
  my $tree_indicator_color   = ($use_rgb_color) ? fg_color_rgb(128, 86, 255) : C;
  $tree_node_indicator_color = $tree_indicator_color;
  $tree_leaf_indicator_color = $tree_indicator_color;
  $tree_root_indicator_color = $tree_indicator_color;
  $tree_node_indicator       = arrow_tri;
  $tree_leaf_indicator       = arrow_open_tri;
  $tree_root_indicator       = square_root_symbol;
  $tree_horiz_dashed         = 0;
  $tree_vert_dashed          = 0;
  $tree_leading_space        = ' ';
  $tree_pre_branch_spacer    = ' ';
  $tree_pre_branch_color     = X;
  $tree_horiz_branch_length  = 1;
  $tree_subnode_count_prefix = $darkK.' (#'.R;
  $tree_subnode_count_suffix = $darkK.')'.X;
  $tree_subnode_count_if_no_subnodes = '';
};

#
# Given a reference to a node (i.e. an array), these convenience functions 
# simply return an lvalue for the node's label (element 0 of the array)
# or its subnodes (the remaining elements starting from index 1, returned
# as a slice).
#
sub label_of_tree_node(+) :lvalue {
  my ($node) = @_;
  $node->[0];
}

#
# Tree Styles
#

noexport:; use constant enum (
  BRANCH,            # e.g.  |-
  LAST_BRANCH,       # e.g.  L_
  NO_BRANCH,         # e.g.  |
  NO_BRANCH_DASHED,  # e.g.  :
  HORIZ_LINE,        # e.g.  -
  HORIZ_DASHED       # e.g.  --
);

# Don't print any branch lines for the top level root node:

my @no_tree_style = (' ' x 6);

# Style Attributes:       |-           L_           |            :            -            --
my @single_tree_style  = (chr(0x251c), chr(0x2514), chr(0x2502), chr(0x2506), chr(0x2500), chr(0x254c));
my @double_tree_style  = (chr(0x2560), chr(0x255a), chr(0x2551), chr(0x2551), chr(0x2550), chr(0x2550));
my @rounded_tree_style = (chr(0x251c), chr(0x2570), chr(0x2502), chr(0x2506), chr(0x2500), chr(0x254c));
my @thick_tree_style   = (chr(0x2523), chr(0x2517), chr(0x2503), chr(0x2507), chr(0x2501), chr(0x254d));

# Style Attributes:                         |-           L_           |            :            -            --
my @single_vert_double_horiz_tree_style  = (chr(0x255e), chr(0x2558), chr(0x2502), chr(0x2506), chr(0x2550), chr(0x2550));
my @single_vert_thick_horiz_tree_style   = (chr(0x255e), chr(0x2558), chr(0x2502), chr(0x2506), chr(0x2501), chr(0x254d));
my @single_vert_arrow_horiz_tree_style   = (chr(0x251c), chr(0x2514), chr(0x2502), chr(0x2506), small_right_barbed_arrow, small_right_barbed_arrow);
my @double_vert_single_horiz_tree_style  = (chr(0x255f), chr(0x2559), chr(0x2551), chr(0x2551), chr(0x2550), chr(0x2550));
my @thick_vert_single_horiz_tree_style   = (chr(0x2520), chr(0x2516), chr(0x2503), chr(0x2507), chr(0x2500), chr(0x254c));

our %tree_styles = (
  'none'            => \@no_tree_style,
  'single'          => \@single_tree_style,
  'double'          => \@double_tree_style,
  'rounded'         => \@rounded_tree_style,
  'thick'           => \@thick_tree_style,

  'none,none'       => \@no_tree_style,

  'single,single'   => \@single_tree_style,
  'single,double'   => \@single_vert_double_horiz_tree_style,
  'single,thick'    => \@single_vert_thick_horiz_tree_style,
  'single,arrow'    => \@single_vert_arrow_horiz_tree_style,

  'double,double'   => \@double_tree_style,
  'double,single'   => \@double_vert_single_horiz_tree_style,

  'thick,thick'     => \@thick_tree_style,
  'thick,single'    => \@thick_vert_single_horiz_tree_style,
);

my $tree_label_markup_re = 
  qr{(?|
       (?>
         \% \{ 
         ([^\=\}]++) 
         (?> \= ($inside_braces_re))?
         \} 
       ) | 
       (?>
         (\t) ()
       )
     )}oax;

our %tree_command_name_to_id = (
  'label'                     => TREE_CMD_LABEL,
  'column'                    => TREE_CMD_COLUMN,
  multikey ('field', TAB, "\f" => TREE_CMD_FIELD),
  'max_field_width'           => TREE_CMD_MAX_FIELD_WIDTH,
  'subnodes'                  => TREE_CMD_SUBNODE_COUNT,
  'prefix'                    => TREE_CMD_PREFIX,
  'even_odd_prefix',          => TREE_CMD_EVEN_ODD_PREFIX,
  'even_odd',                 => TREE_CMD_EVEN_ODD,
  'symbol'                    => TREE_CMD_SYMBOL,
  'branch_color'              => TREE_CMD_BRANCH_COLOR,
  'branch_style'              => TREE_CMD_BRANCH_STYLE,
  'branch_dashed'             => TREE_CMD_BRANCH_DASHED,
  'horiz_branch_length'       => TREE_CMD_HORIZ_BRANCH_LENGTH,
  'div'                       => TREE_CMD_DIV,
  multikey (qw(callfunc callout call exec generate) => TREE_CMD_CALL_FUNCTION),
  multikey (qw(include inc) => TREE_CMD_INCLUDE),
  multikey (qw(userdata comment note) => TREE_CMD_USER_DATA),
);

noexport:; sub subtree_label {
  my ($label, $node, $leading_space,
      $branch_to_node_style, $branch_to_leaf_style,
      $sub_branch_to_node_style, $sub_branch_to_leaf_style,
      $branch_color, $sub_branch_color,
      $node_indicator, $leaf_indicator,
      $horiz_dashed, $vert_dashed, 
      $horiz_branch_length, $skip_branch,
      $max_field_widths,
      $output_line_number) = @_;

  my $subnode_count = (is_array_ref($node)) ? scalar(@$node)-1 : 0;

  my $is_even_line = ($output_line_number % 2) == 0;

  $leading_space //= '';

  my $per_line_header = '';

  my $field_id = 0;
  my @fields = ( '' );

  #
  # Even with an array, any literal chunks could still contain
  # %{tree_cmd=...} or \t (tab to next field), so also split 
  # any array elements that are scalars containing these.
  # (Text based commands can't use the INCLUDE command anyway).
  #
  my @chunks = (is_array_ref $label)
    ? (map {
      (!defined $_) ? ( ) :
      (is_array_ref $_) ? (do {
        my ($cmd, @args) = @{$_};
        ($cmd == TREE_CMD_INCLUDE) ? @args : 
        ($cmd == TREE_CMD_CALL_FUNCTION) ? (do {
          my ($func, @func_args) = @args;
          ($func->($node, $label, @func_args))
        }) : ($_)
      }) : (split $tree_label_markup_re, $_)
    } @$label) : (split $tree_label_markup_re, $label); 

  foreach my $chunk (@chunks) {
    my $cmd; my $arg; my @args = ( );
    next if (!defined $chunk); # undef chunks are no-ops: just skip them

    if (is_array_ref($chunk)) {
      @args = @$chunk;
      $cmd = shift @args;
      $arg = $args[0] // '';
    } elsif ($chunk =~ /$tree_label_markup_re/oax) {
      ($cmd, $arg) = ($tree_command_name_to_id{$1}, $2 // '');
      @args = split(/,/, $arg);
      if (!defined $cmd) {
        warning('Invalid tree formatting command "'.$1.'" with arguments ['.
              join(', ', @args).']');
      }
    } else {
      $cmd = TREE_CMD_LABEL;
      $arg = $chunk;
    }

    my $added = undef;
    my $added_to_prefix = undef;

    if ($cmd == TREE_CMD_LABEL) {
      $added = $arg;
    } elsif ($cmd == TREE_CMD_SUBNODE_COUNT) {
      my $before = (if_there $args[0]) // $tree_subnode_count_prefix;
      my $after = (if_there $args[1]) // $tree_subnode_count_suffix;
      my $if_no_subnodes = (if_there $args[2]) // $tree_subnode_count_if_no_subnodes;
      $added = ($subnode_count > 0) ? $before.$subnode_count.$after : $if_no_subnodes;
    } elsif ($cmd == TREE_CMD_FIELD) {
      if (is_there($arg)) {
        $field_id = $arg;
      } else {
        # add a new field at the end
        $field_id++;
      }
    } elsif ($cmd == TREE_CMD_MAX_FIELD_WIDTH) {
      my $f = (if_there $args[1]) // $field_id;
      set_if_there($max_field_widths->[$f + 1], $args[0]);
    } elsif ($cmd == TREE_CMD_PREFIX) {
      $added_to_prefix = join('', map { ((is_scalar_ref $_) ? ${$_} : $_) // '' } @args);
    } elsif ($cmd == TREE_CMD_EVEN_ODD_PREFIX) {
      $args[0] = (if_there $args[0]) // '';
      $args[1] = (if_there $args[1]) // $args[0];
      $added_to_prefix = ($is_even_line) ? $args[0] : $args[1];
    } elsif ($cmd == TREE_CMD_SYMBOL) {
      $$node_indicator = (if_there $args[0]) // 
        ($tree_node_indicator_color.$tree_node_indicator);
      $$leaf_indicator = (if_there $args[1]) // (if_there $args[0]) // 
        ($tree_leaf_indicator_color.$tree_leaf_indicator);
    } elsif ($cmd == TREE_CMD_BRANCH_COLOR) {
      $$branch_color = (if_there $arg) // $tree_branch_color;
    } elsif ($cmd == TREE_CMD_BRANCH_STYLE) {
      my ($br_to_node, $br_to_leaf) = @args;
      set_if_empty $br_to_node, $$branch_to_node_style;
      set_if_empty $br_to_leaf, $br_to_node;
      $$branch_to_node_style = $tree_styles{$br_to_node};
      $$branch_to_leaf_style = $tree_styles{$br_to_leaf};
      if (!exists $tree_styles{$br_to_node}) { warn('Style "'.$br_to_node." (for branch to node) is invalid"); }
      if (!exists $tree_styles{$br_to_leaf}) { warn('Style "'.$br_to_leaf." (for branch to leaf) is invalid"); }
    } elsif ($cmd == TREE_CMD_SUB_BRANCH_COLOR) {
      $$sub_branch_color = (if_there $arg) // $$branch_color;
    } elsif ($cmd == TREE_CMD_SUB_BRANCH_STYLE) {
      my ($br_to_node, $br_to_leaf) = @args;
      set_if_empty $br_to_node, $$branch_to_node_style;
      set_if_empty $br_to_leaf, $br_to_node;
      $$sub_branch_to_node_style = $tree_styles{$br_to_node};
      $$sub_branch_to_leaf_style = $tree_styles{$br_to_leaf};
      if (!exists $tree_styles{$br_to_node}) { warn('Style "'.$br_to_node." (for branch to subnode) is invalid"); }
      if (!exists $tree_styles{$br_to_leaf}) { warn('Style "'.$br_to_leaf." (for branch to subleaf) is invalid"); }
    } elsif ($cmd == TREE_CMD_BRANCH_DASHED) {
      $$horiz_dashed = (if_there $args[0]) // 1;
      $$vert_dashed = (if_there $args[1]) // 0;
    } elsif ($cmd == TREE_CMD_BRANCH_SKIP) {
      $$skip_branch = 1;
    } elsif ($cmd == TREE_CMD_HORIZ_BRANCH_LENGTH) {
      $$horiz_branch_length = (if_there $args[0]) // $tree_horiz_branch_length;
    } elsif ($cmd == TREE_CMD_DIV) {
      $args[0] = (if_there $args[0]) // dashed_horiz_bar_2_dashes;
      $args[1] = (if_there $args[1]) // $$branch_color // B;
      $added = $args[1].($args[0] x 80);
    } elsif ($cmd == TREE_CMD_EVEN_ODD) {
      $args[0] = (if_there $args[0]) // '';
      $args[1] = (if_there $args[1]) // $args[0];
      $added = ($is_even_line) ? $args[0] : $args[1];
    } elsif ($cmd == TREE_CMD_USER_DATA) {
      # no-op: just ignore all the arguments 
      # (which can be anything the caller wants)
    } else {
      die('Invalid formatting command #', $cmd,' with arguments ['.join_undefs(', ', @args).']');
    }

    if (defined $added) {
      $fields[$field_id] //= '';
      $fields[$field_id] .= $added;
    } elsif (defined $added_to_prefix) {
      $per_line_header .= $added_to_prefix;
    }
  }

  $per_line_header .= $leading_space;

  return ($per_line_header, @fields);
}

noexport:; sub subtree_to_text {
  my ($nodelist, $out, $level, $prefix, 
      $branch_to_node_style, $branch_to_leaf_style, 
      $branch_color, $parent_branch_color, $node_indicator, 
      $leaf_indicator, $horiz_dashed, $vert_dashed,
      $horiz_branch_length, $max_field_widths) = @_;

  $prefix //= '';

  my $nodecount = 0;
  
  my @empty_array = ( );

  my $node_count = scalar(@$nodelist);

  my $sub_branch_to_node_style = undef;
  my $sub_branch_to_leaf_style = undef;
  my $sub_branch_color = undef;

  my $skip_branch = 0;

  if ($level == 0) {
    # we need to print the header line for the top-level root node:
    my $root_branch_color = undef;
    my $root_branch_to_node_style = undef;
    my $root_branch_to_leaf_style = undef;
    my $root_node_indicator = undef;
    my $root_leaf_indicator = undef; # (this is only relevant for empty trees)

    my $this_horiz_dashed = $horiz_dashed;
    my $this_vert_dashed = $vert_dashed;
    my ($per_line_header, @fields) = subtree_label(
      ($nodelist->[0] // C.'root'.X),
      $node, $tree_leading_space,
      \$root_branch_to_node_style, \$root_branch_to_leaf_style,
      \$sub_branch_to_node_style, \$sub_branch_to_leaf_style,
      \$root_branch_color, \$sub_branch_color,
      \$root_node_indicator, \$root_leaf_indicator,
      \$this_horiz_dashed, \$this_vert_dashed,
      \$horiz_branch_length, \$skip_branch,
      $max_field_widths,
      scalar(@$out));

    #
    # Since the root node has no branch to its left, it is meaningless
    # to set its own branch style or color; in this case we instead set
    # the default sub-branch style and color (if not explicitly set)
    # to match the root style and color, so the first level branches
    # use these settings unless one or more of these first level 
    # branches override these settings using TREE_CMD_BRANCH_COLOR 
    # and/or TREE_CMD_BRANCH_STYLE or equivalently (for the root only)
    # TREE_CMD_SUB_BRANCH_STYLE and/or TREE_CMD_SUB_BRANCH_COLOR.
    #
    # These first level branches can also independently set the style and
    # color of their own sub-nodes (and their entire sub-tree by default)
    # using TREE_CMD_SUB_BRANCH_STYLE and/or TREE_CMD_SUB_BRANCH_COLOR.    
    #
    $branch_to_node_style = $root_branch_to_node_style // $sub_branch_to_node_style // $branch_to_node_style;
    $branch_to_leaf_style = $root_branch_to_leaf_style // $sub_branch_to_leaf_style // $branch_to_leaf_style;
    $branch_color = $root_branch_color // $sub_branch_color // $branch_color;
    $sub_branch_to_node_style //= $branch_to_node_style;
    $sub_branch_to_leaf_style //= $branch_to_leaf_style;
    $sub_branch_color //= $branch_color;
    $root_node_indicator //= $tree_root_indicator;

    $fields[0] = $tree_root_indicator_color.$root_node_indicator.' '.($fields[0] // '').' ';
    push @$out, [ $per_line_header, @fields ];
  }

  # $nodelist->[0] is this node's text to prints(already printed by the 
  # calling subtree_to_text()), so we start with index 1 here:

  for (my $i = 1; $i < $node_count; $i++) {
    my $node = $nodelist->[$i];
    my $is_last_node = ($i == ($node_count-1));
    my $is_array_node = is_array_ref($node);
    
    my $chunks = (((defined $node) && $is_array_node) ? $node->[0] : $node) // '';
    
    my $subnode_count = ($is_array_node ? scalar(@$node)-1 : 0);

    my $this_horiz_dashed = $horiz_dashed;
    my $this_vert_dashed = $vert_dashed;

    my ($per_line_header, @fields) = subtree_label(
      $chunks, $node, $tree_leading_space,
      \$branch_to_node_style, \$branch_to_leaf_style,
      \$sub_branch_to_node_style, \$sub_branch_to_leaf_style,
      \$branch_color, \$sub_branch_color,
      \$node_indicator, \$leaf_indicator,
      \$this_horiz_dashed, \$this_vert_dashed, 
      \$horiz_branch_length, \$skip_branch,
      $max_field_widths, 
      scalar(@$out));

    my $style_set = ($subnode_count > 0) ? $branch_to_node_style : $branch_to_leaf_style;
    
    my $style =
      ($is_last_node) ? LAST_BRANCH :
      (is_there $node) ? BRANCH :
      ($this_vert_dashed ? NO_BRANCH_DASHED : NO_BRANCH);
        
    my $horiz_style =
      ($this_horiz_dashed ? HORIZ_DASHED : HORIZ_LINE);

    die if (!defined $parent_branch_color);
    die if (!defined $branch_color);
    die if (!defined $tree_pre_branch_color);
    die if (!defined $style_set->[NO_BRANCH]);

    my $base_prefix = $parent_branch_color.$prefix.$branch_color;

    my $subnode_prefix = 
      $base_prefix.(($is_last_node) 
                    ? ($tree_pre_branch_spacer x $horiz_branch_length).$tree_pre_branch_spacer
                    : $style_set->[NO_BRANCH].(' ' x $horiz_branch_length));
   
    my $indicator = 
      (($subnode_count > 0)
        ? $node_indicator
        : (is_there($node) ? $leaf_indicator : $leaf_indicator));

    my $branch_symbols = $base_prefix.
      (($skip_branch)
         ? $style_set->[NO_BRANCH].(' ' x $horiz_branch_length)
         : $style_set->[$style].($style_set->[$horiz_style] x $horiz_branch_length)).
      $indicator.' '.(($subnode_count > 0) ? G : X);

    #
    # Prepend the branch symbols to the start of the first field,
    # rather than giving them their own field, since we want the
    # first field's label to appear immediately after the branches.
    #
    # (If this was aligned to the next field boundary, nodes closer
    # to the root would have a huge gap between the branch and its
    # label, which would look visually confusing).
    #
    @fields[0] = $branch_symbols.($fields[0] // '');

    push @$out, [ $per_line_header, @fields ];

    if ($subnode_count > 0) {
      subtree_to_text(
        $node, $out, $level+1, $subnode_prefix,
        $sub_branch_to_node_style // $branch_to_node_style,
        $sub_branch_to_leaf_style // $branch_to_leaf_style, 
        $sub_branch_color // $branch_color,
        $parent_branch_color, $node_indicator, $leaf_indicator, 
        $this_horiz_dashed, $this_vert_dashed, $horiz_branch_length,
        $max_field_widths);
    }
  }
}

noexport:; sub tree_to_lines {
  my $nodelist             = $_[0];
  my $branch_to_node_style = $_[1] // $tree_branch_to_node_style;
  my $branch_to_leaf_style = $_[2] // $tree_branch_to_leaf_style;
  my $branch_color         = $_[3] // $tree_branch_color;
  my $node_indicator       = $_[4] // $tree_node_indicator_color.$tree_node_indicator;
  my $leaf_indicator       = $_[5] // $tree_leaf_indicator_color.$tree_leaf_indicator;
  my $horiz_dashed         = $_[6] // $tree_horiz_dashed;
  my $vert_dashed          = $_[7] // $tree_vert_dashed;
  my $horiz_branch_length  = $_[8] // $tree_horiz_branch_length;

  if (!(exists $tree_styles{$branch_to_node_style}))
    { die('Undefined tree branch style "'.$branch_to_node_style.'"'); }

  $branch_to_node_style = $tree_styles{$branch_to_node_style};

  if (!(exists $tree_styles{$branch_to_leaf_style}))
    { die('Undefined tree branch style "'.$branch_to_leaf_style.'"'); }

  $branch_to_leaf_style = $tree_styles{$branch_to_leaf_style};

  my $parent_branch_color = $branch_color;

  if ((is_console_color_capable() >= ENHANCED_RGB_COLOR_CAPABLE)) {
    $parent_branch_color = fg_color_rgb(scale_rgb($branch_color, 0.5));
  }

  my $rows_and_columns = [ ];
  my $max_field_widths = [ undef ];

  subtree_to_text(
    $nodelist, $rows_and_columns, 0, '',
    $branch_to_node_style, $branch_to_leaf_style, 
    $branch_color, $parent_branch_color, 
    $node_indicator, $leaf_indicator,
    $horiz_dashed, $vert_dashed, 
    $horiz_branch_length,
    $max_field_widths);

  my @out = format_table($rows_and_columns, colseps => '', row_suffix => X.NL,
                         wrap_above_max_col_widths => $max_field_widths); 

  return (wantarray ? @out : \@out);
}

sub format_tree(+;@) {
  my ($node, @args) = @_;
  my $lines = tree_to_lines($node, @args);
  return (wantarray ? @$lines : join(NL, @$lines));
}

sub print_tree(+;$@) {
  my ($node, $fd, @args) = @_;
  $fd //= STDOUT;
  my $lines = tree_to_lines($node, @args);
  printfd($fd, join(NL, @$lines));
}

1;
