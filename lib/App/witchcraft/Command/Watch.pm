package App::witchcraft::Command::Watch;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils
    qw(daemonize error draw_up_line draw_down_line info notice send_report last_md5 repo_update);
use warnings;
use strict;
use File::Find;
use Regexp::Common qw/URI/;
use App::witchcraft::Command::Align;
use App::witchcraft::Build;
use Tie::File;
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Watch - Automatic compile and equo push after a git commit of an ebuild

=head1 SYNOPSIS

  $ witchcraft watch
  $ witchcraft w [--daemon]

=head1 DESCRIPTION

Automatic compile and equo push after a git commit of an ebuild A.K.A spikemate

=head1 ARGUMENTS

=over 4

=item C<-d|--daemon>

Run in background

=item C<--help>

it prints the POD help.

=back

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
    ( "d|daemon" => "daemon", );
}

sub run {
    my $self = shift;
    error __ 'You must run it with root permissions' and return 1 if $> != 0;
    my $cfg = App::witchcraft->instance->Config;
    info __x(
        'Watching overlay {overlay} every {sleep} s',
        overlay => $cfg->param('OVERLAY_NAME'),
        sleep   => $cfg->param('SLEEP_TIME')
    );
    daemonize($0) if $self->{daemon};
    send_report( __ "Watching the repo forever" );
    while (1) {
        info __ "Checking for updates, and merging up!";
        draw_up_line;
        repo_update;
        $self->update;
        manual_update( $cfg->param('OVERLAY_PATH') );
        draw_down_line;
        sleep $cfg->param('SLEEP_TIME');
    }

}

sub manual_update($) {
    my $overlay = shift;
    my $cfg     = App::witchcraft->instance->Config;
    my $overlay_to_compile_packages
        = $cfg->param('OVERLAY_MANUAL_COMPILE_FILE');

    if ( -e $overlay . "/" . $overlay_to_compile_packages ) {
        open( my $fh, '<', $overlay . "/" . $overlay_to_compile_packages )
            or send_report(
            __x("Cannot open {overlay}/{packages}: {error}",
                overlay  => $overlay,
                packages => $overlay_to_compile_packages,
                error    => $!
            )
            );
        binmode($fh);
        my $calculated_md5 = Digest::MD5->new->addfile($fh)
            ->hexdigest
            ;    #Computing the md5 of the file containing the packages
        close $fh;
        my $last_md5 = last_md5();
        info(
            __x("Last md5 {md5} of {overlay}/{packages}",
                md5      => $last_md5,
                overlay  => $overlay,
                packages => $overlay_to_compile_packages
            )
        ) if defined $last_md5;
        if ( !defined $last_md5 or ( $calculated_md5 ne $last_md5 ) )
        {        #If they are different, then proceed the compile them
            open( my $fh, '<', $overlay . "/" . $overlay_to_compile_packages )
                or (
                __x("Cannot open {overlay}/{packages}: {error}",
                    overlay  => $overlay,
                    packages => $overlay_to_compile_packages,
                    error    => $!
                )
                and return
                );

            my @DIFFS = <$fh>;
            close $fh;
            chomp(@DIFFS);
            send_report(
                __x("Issued a manual packages compile, start compiling process for : {packages}",
                    packages => @DIFFS
                )
            );
            App::witchcraft::Build->new(
                manual      => 1,
                track_build => 1,
                id          => $calculated_md5,
                packages    => @DIFFS
            )->build;
        }
        else {
            notice( __
                    "Are you looking at me? i have NOTHING better to do than sleeping... can you say the same?"
            );
        }
    }
}

sub update() {
    my $Align = App::witchcraft::Command::Align->new;
    $Align->run();
}
1;
