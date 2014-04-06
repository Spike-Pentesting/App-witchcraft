package App::witchcraft::Command::Clean;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils;
use warnings;
use strict;

sub options {
    (

    );
}

sub run {
    my $self = shift;
    my $dir
        = shift // -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";
        info 'Manifest & Install of the untracked files in '.$dir;
    clean_untracked($dir);
    exit;
}

1;
__DATA__
compat-wireless
linux-live
profiles
prism54
compat-drivers
acpid
layout.conf
linux-sources
genmenu
nvidia-drivers
ati-drivers
openrc
mkxf86config
genkernel
