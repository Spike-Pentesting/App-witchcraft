package App::witchcraft::Command::Box;

use base qw(App::witchcraft::Command);
use Carp::Always;
use Locale::TextDomain 'App-witchcraft';
use App::witchcraft::Utils
    qw(error info notice draw_down_line draw_up_line send_report vagrant_box_status vagrant_box_cmd);
use warnings;
use Child;
use strict;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Box - Handy utilities for managing your vagrant builder boxes

=head1 SYNOPSIS

  $ witchcraft box|b [list|status|halt|up|ssh|monitor_start|monitor_stop]

=head1 DESCRIPTION

Handles your vagrant boxes handly: it can start/stop them, watch their status (maintaining them up), spawn ssh on a new-window for tmux, list their statuses.
You should set VAGRANT_BOXES on the config file, pointing to the group of boxes that you wish to manage. You can also specific a fake home and a fake vagrant home (if you have your boxes on a separate directory than your home) with FAKE_ENV_HOME and FAKE_ENV_VAGRANT_HOME.
We use it internally with the systemd script used to run at start a special behaviour of witchcraft (see ex/witchcraft.service).

=head1 ACTIONS

=head2 list

List the vagrant boxes specified in the configuration file

=head2 status

List the status of your boxes

=head2 halt

halt all your boxes

=head2 up

starts all your boxes

=head2 ssh

spawn a "vagrant ssh" for each box in a new tmux window in the current session

=head2 monitor_start MINUTES

Starts a monitor process that check machine status for each MINUTES, if arg is not given, it checks the machine each hour.
The machine if turned off will be automatically turned on

=head2 monitor_stop

Kills the monitor process

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

our @AVAILABLE_CMDS = qw(list status monitor_start monitor_stop up halt ssh);

sub run {
    my $self   = shift;
    my $action = shift;
    my @args   = @_;
    error __x("At least one of this action must be specified: {cmds}", cmds=>"@AVAILABLE_CMDS")
        and return 1
        if !defined $action
        or !( grep { $_ eq $action } @AVAILABLE_CMDS );
    App::witchcraft->instance->emit("irc_exit");    # prevent irc collapse

    my $cfg          = App::witchcraft->instance->Config;
    my $HOME         = $ENV{HOME};
    my $VAGRANT_HOME = $ENV{VAGRANT_HOME};

    my $FAKE_ENV_HOME         = $cfg->param("FAKE_ENV_HOME");
    my $FAKE_ENV_VAGRANT_HOME = $cfg->param("FAKE_ENV_VAGRANT_HOME");

    $ENV{HOME}         = $FAKE_ENV_HOME         if ($FAKE_ENV_HOME);
    $ENV{VAGRANT_HOME} = $FAKE_ENV_VAGRANT_HOME if ($FAKE_ENV_VAGRANT_HOME);

    ( -d $_ )
        ? $self->$action( $_, @args )
        : error("Something is wrong, i can't find your box: $_")
        for $cfg->param("VAGRANT_BOXES");

    $ENV{HOME}         = $HOME;
    $ENV{VAGRANT_HOME} = $VAGRANT_HOME;

}

sub list { notice $_[1]; }

#available status : poweroff running
sub status { info $_[1] . ": " . vagrant_box_status( $_[1] ); }

sub up {
    error $_[1] . ": " . __ "box is already running" and return 1
        if ( vagrant_box_status( $_[1] ) eq "running" );
    info __ "Starting up " . $_[1];
    info $_[1] . ": ";
    notice join( "\n", @{ ( vagrant_box_cmd( "up", $_[1] ) )[1] } );
}

sub halt {
    info __ "Stopping " . $_[1];
    info $_[1] . ": ";
    notice join( "\n", @{ ( vagrant_box_cmd( "halt", $_[1] ) )[1] } );
}

sub ssh {
    my $self = shift;
    my $box  = shift;
    info __x( "Spawning ssh on {box}", box => $box );
    system(   "tmux new-window 'export HOME=\""
            . $ENV{HOME}
            . "\";export VAGRANT_HOME=\""
            . $ENV{VAGRANT_HOME}
            . "\";cd $box; vagrant ssh' &" );
}

sub monitor_start {
    my $self = shift;
    my $box  = shift;
    my $min  = shift || 60;
    my $secs = $min * 60;

    $self->_clean_monitor($box) if ( -e "$box/.monitor.pid" );
    error __x( "it seems that a monitor is already up for {box}",
        box => $box )
        and return 0
        unless ( !-e "$box/.monitor.pid" );

    info __x( "Monitoring {box} for {min} m ", box => $box, min => $min );

    my $child = Child->new(
        sub {
            my ($parent) = @_;
            while (1) {
                notice join( "\n", @{ ( vagrant_box_cmd( "up", $box ) )[1] } )
                    if vagrant_box_status($box) eq "poweroff";
                sleep $secs;
            }
        }
    );
    my $proc = $child->start;
    open my $PIDFILE, ">$box/.monitor.pid";
    print $PIDFILE $proc->pid;
    close $PIDFILE;
}

sub monitor_stop {
    my $self = shift;
    my $box  = shift;
    my $min  = shift || 60;
    my $secs = $min * 60;
    error __x( "it seems that there isn't a monitor running for {box}",
        box => $box )
        and return 0
        unless ( -e "$box/.monitor.pid" );
    open my $PIDFILE, "<$box/.monitor.pid";
    my $PID = <$PIDFILE>;
    close $PIDFILE;
    info __x(
        "stopping monitoring for {box}, {pid} process",
        box => $box,
        pid => $PID
    );
    kill 9, $PID;
    unlink("$box/.monitor.pid");
}

sub _clean_monitor {
    my $self = shift;
    my $box  = shift;
    open my $PIDFILE, "<$box/.monitor.pid";
    my $PID = <$PIDFILE>;
    close $PIDFILE;
    my $running = kill 0, $PID;
    unlink("$box/.monitor.pid") if ( !$running );
}

1;

