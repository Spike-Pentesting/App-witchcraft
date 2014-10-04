package App::witchcraft::Utils;

use parent
    qw(Exporter App::witchcraft::Utils::Base App::witchcraft::Utils::Gentoo App::witchcraft::Utils::Sabayon);

use Import::Into;
use warnings;
use App::witchcraft;
use App::witchcraft::Loader;
use strict;

sub import {
    shift;
    my @functs = @_;
    my $caller = caller;
    my $loader = App::witchcraft::Loader->new;
    if ( my $helper = App::witchcraft->new->Config->param("DISTRO") ) {
        $helper = "App::witchcraft::Utils::" . ucfirst($helper);
        if ( !$loader->load($helper) ) {
            $helper->import::into( $caller, @functs );
            return;
        }

    }
    App::witchcraft::Utils::Gentoo->import::into( $caller, @functs );

    return;
}

1;
