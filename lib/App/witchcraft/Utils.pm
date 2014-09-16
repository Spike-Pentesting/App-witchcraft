package App::witchcraft::Utils;

use parent
    qw(Exporter App::witchcraft::Utils::Base App::witchcraft::Utils::Gentoo App::witchcraft::Utils::Sabayon);

use Import::Into;
use warnings;
use strict;

sub import {
    shift;
    my @functs = @_;
    my $caller = caller;
    if ( my $helper = App::witchcraft->Config->param("DISTRO") ) {
        App::witchcraft::Utils::Gentoo->import::into( $caller, @functs )
            and return
            if $helper eq "gentoo";
        App::witchcraft::Utils::Sabayon->import::into( $caller, @functs )
            and return
            if $helper eq "sabayon";
    }
    App::witchcraft::Utils::Base->import::into( $caller, @functs );

    return;
}

1;
