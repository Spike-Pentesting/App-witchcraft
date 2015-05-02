package App::witchcraft::Constants;
use parent "Exporter";
use constant BUILD_SUCCESS => 1;
use constant BUILD_FAILED  => 2;
use constant BUILD_UNKNOWN => 3;
@EXPORT_OK = qw(BUILD_UNKNOWN BUILD_SUCCESS BUILD_FAILED);
1;
