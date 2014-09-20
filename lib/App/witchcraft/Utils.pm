package App::witchcraft::Utils;

use parent
    qw(Exporter App::witchcraft::Utils::Base App::witchcraft::Utils::Gentoo App::witchcraft::Utils::Sabayon);

use Import::Into;
use warnings;
use App::witchcraft;
use strict;

sub import {
    shift;
    my @functs = @_;
    my $caller = caller;
    if ( my $helper = App::witchcraft->new->Config->param("DISTRO") ) {
        if ( $helper =~ /gentoo/i ) {
            App::witchcraft::Utils::Gentoo->import::into( $caller, @functs );
            return;
        }
        elsif ( $helper =~ /sabayon/i ) {
            App::witchcraft::Utils::Sabayon->import::into( $caller, @functs );
            return;
        }
    }
    App::witchcraft::Utils::Base->import::into( $caller, @functs );

    return;
}

1;
