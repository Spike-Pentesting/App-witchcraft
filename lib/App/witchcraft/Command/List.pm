package App::witchcraft::Command::List;

use base qw(App::witchcraft::Command);
use warnings;
use strict;

sub run {
    my $self = shift;
    my $Repo = shift // "spike";
    exec("equo query list available $Repo -q");
    exit;
}

1;
