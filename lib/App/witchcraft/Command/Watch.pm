package App::witchcraft::Command::Watch;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils
    qw(daemonize error draw_up_line draw_down_line info notice send_report conf_update save_compiled_commit process to_ebuild save_compiled_packages find_logs find_diff last_md5 last_commit);
use warnings;
use strict;
use File::Find;
use Regexp::Common qw/URI/;
use Tie::File;

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
    error 'You must run it with root permissions' and exit 1 if $> != 0;
    my $cfg = App::witchcraft->Config;
    info 'Watching overlay '
        . $cfg->param('OVERLAY_NAME')
        . ' every '
        . $cfg->param('SLEEP_TIME') . ' s';
    daemonize($0) if $self->{daemon};
    send_report("I'm up!");
    while (1) {
        info "Checking for updates, and merging up!";
        draw_up_line;
        if ( system("layman -S") == 0 ) {    #Launch layman -S first.
            system("eix-sync");
            update( $cfg->param('OVERLAY_PATH'),
                $cfg->param('GIT_MASTER_FILE') );
            manual_update( $cfg->param('OVERLAY_PATH') );
        }
        else {
            send_report( "Layman coudn't sync", "Executing : layman -S " );
        }
        draw_down_line;
        sleep $cfg->param('SLEEP_TIME');
    }

}

sub manual_update($) {
    my $overlay = shift;
    my $cfg     = App::witchcraft->Config;
    my $overlay_to_compile_packages
        = $cfg->param('OVERLAY_MANUAL_COMPILE_FILE');

    if ( -e $overlay . "/" . $overlay_to_compile_packages ) {
        open( my $fh, '<', $overlay . "/" . $overlay_to_compile_packages )
            or send_report(
            "Cannot open $overlay/$overlay_to_compile_packages: $!");
        binmode($fh);
        my $calculated_md5 = Digest::MD5->new->addfile($fh)
            ->hexdigest
            ;    #Computing the md5 of the file containing the packages
        close $fh;
        my $last_md5 = last_md5();
        info("Last md5 $last_md5 of $overlay/$overlay_to_compile_packages")
            if defined $last_md5;
        if ( !defined $last_md5 or ( $calculated_md5 ne $last_md5 ) )
        {        #If they are different, then proceed the compile them
            open( my $fh, '<', $overlay . "/" . $overlay_to_compile_packages )
                or (
                send_report(
                    "Cannot open $overlay/$overlay_to_compile_packages: $!"
                )
                and return
                );

            my @DIFFS = <$fh>;
            close $fh;
            chomp(@DIFFS);
            send_report(
                "Issued a manual packages compile, start compiling process for : "
                    . join( " ", @DIFFS ) );
            process( @DIFFS, $calculated_md5, 1 );
        }
        else {
            notice(
                "Are you looking at me? i have NOTHING better to do than sleeping... can you say the same?"
            );
        }
    }
}

#
#  name: update
#  input: $overlay,$master_file
#  output: void
#  Funzione che si occupa di gestire le chiamate alle funzioni in caso di compile tramite l'ausilio dei commit di git
#
sub update($$) {
    my $overlay     = shift;
    my $master_file = shift;
    my $cfg         = App::witchcraft->Config;

    my ( $commit, $line ) = last_commit( $overlay, $master_file );
    info("Last commit: $commit");
    my $compiled_commit = compiled_commit();
    info("Last COMPILED commit: $compiled_commit");
    if ( defined $compiled_commit and $commit eq $compiled_commit ) {
        info(
            "Are you looking at me? i have NOTHING better to do than sleeping... can you say the same?"
        );
    }
    else {
        notice("Commits seems differents, calculating the differencies.");
        my @DIFFS = find_diff( $overlay, $master_file );
        info(     "A total of "
                . scalar(@DIFFS)
                . " real changes were found, proceeding to compile them." );
        my $overlay_name = $cfg->param('OVERLAY_NAME');
        my @EMERGING = map { $_ . "::" . $overlay_name } @DIFFS;
        process( @EMERGING, $commit, 0 )
            ;    # 0 to use with git, 1 with manual use
    }
}
1;
