package App::witchcraft::Command::Bump;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils
    qw(error info notice draw_down_line draw_up_line find_ebuilds uniq euscan filetoatom);
use warnings;
use App::witchcraft::Command::Euscan;
use strict;
use Cwd;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Bump - Automatically bumps packages using euscan

=head1 SYNOPSIS

  $ witchcraft bump|bu [full|scan] [--no-test] [--git]
  $ witchcraft bu scan cat/atom

=head1 DESCRIPTION

It scans the packages in the repository, searching with euscan new versions. Automatically tests it and add to the git if --git flag is passed.

=head1 ACTIONS

=head2 full

Scans the entire repository and autobumps ebuilds if tests passes

=head2 scan

If called with an argument, tries to autobump it, otherwise will try to bump the ebuild in the current directory

=head1 OPTIONS

=head2 --no-test

Skip tests

=head2 --git

Automatically commit to the git repo

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<App::witchcraft>, L<App::witchcraft::Command::Euscan>

=cut

sub options {
    (   "n|no-test" => "notest",
        "g|git"     => "git"
    );
}
our @AVAILABLE_CMDS = qw(full scan);

sub run {
    my $self   = shift;
    my $action = shift;
    my @args   = @_;

    error "At leat one of this action must be specified: @AVAILABLE_CMDS"
        and exit 1
        if !defined $action
        or !( grep { $_ eq $action } @AVAILABLE_CMDS );

    my $Euscan = App::witchcraft::Command::Euscan->new;
    $Euscan->{git}      = $self->{git};
    $Euscan->{install}  = ( $self->{notest} ) ? 0 : 1;
    $Euscan->{manifest} = $Euscan->{update} = 1;
    $self->$action( $Euscan, @args );

}

sub scan {
    my $self   = shift;
    my $Euscan = shift;
    my @args   = @_;
    push( @args, join( "/", ( split( /\//, cwd ) )[ -2 .. -1 ] ) )
        unless @args > 0;
    chomp(@args);
    $self->euscan_packages( $Euscan, @args );
}

sub full {
    my $self   = shift;
    my $Euscan = shift;
    my $git     = App::witchcraft->instance->Config->param('GIT_REPOSITORY');
    my @EBUILDS = uniq( filetoatom( find_ebuilds($git) ) );
    $self->euscan_packages( $Euscan, @EBUILDS );
}

sub euscan_packages {
    my $self    = shift;
    my $Euscan  = shift;
    my @EBUILDS = @_;
    my @Added;
    my @Updates;
    my $c = 1;
    foreach my $Package (@EBUILDS) {
        draw_up_line;
        notice "[$c/" . scalar(@EBUILDS) . "] " . $Package;
        my @temp = euscan($Package);
        info "** " . $_ for @temp;
        push( @Updates, @temp );
        push( @Added, $Euscan->update( $Package, undef, @temp ) )
            if ( @temp > 0 );

        $c++;
    }
    if ( @Updates > 0 ) {
        notice $_ for @Updates;
    }

    if ( @Added > 0 ) {
        info "Those are the packages that passed the tests";
        notice $_ for @Updates;
    }
}

1;

