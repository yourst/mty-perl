#
# Convenient alias for MTY::Display::DataStructures package
# so you can simply use "use DDS; pp ..."
#

package DDS;

use Exporter qw(import);
use MTY::Display::DataStructures;
#pragma end_of_includes

preserve:; our @EXPORT = @MTY::Display::DataStructures::EXPORT;

1;

