package App::witchcraft::Plugin::Irc;

use Deeme::Obj -base;
use IO::Socket::INET;
use App::witchcraft::Utils qw(info error notice send_report truncate_words);
use forks;
use constant DEBUG => $ENV{DEBUG} || 0;

has [qw (irc thread)];

sub register {
    my ( $self, $emitter ) = @_;
    my $hostname = $App::witchcraft::HOSTNAME;
    return undef unless $emitter->Config->param('IRC_CHANNELS');

    $self->irc( $self->_connect );
    $self->_handle if ( $self->irc );

    $emitter->on(
        "send_report_link" => sub {
            my ( $witchcraft, $message, $url ) = @_;
            my $string = "Witchcraft\@$hostname: " . $message . " - " . $url;
            $emitter->emit( send_irc_message => $string );
        }
    );
    $emitter->on(
        "send_report_message" => sub {
            my ( $witchcraft, $message ) = @_;
            my $string = "Witchcraft\@$hostname: " . $message;
            $emitter->emit( send_irc_message => $string );
        }
    );
    $emitter->on(
        "send_irc_message" => sub {
            my ( $witchcraft, $message );
            $message =~ s/\n/ /;
            my @pieces = truncate_words( $message, 200 );
            $self->irc_msg($_) for @pieces;
        }
    );

    $emitter->on( "on_exit"  => sub { $emitter->emit("irc_exit") } );
    $emitter->on( "irc_exit" => sub { $self->thread->kill('SIGUSR1') } );

}

sub irc_msg {
    my $self    = shift;
    my $message = shift;
    if ( $self->irc ) {
        my $socket = $self->irc;
        printf $socket "PRIVMSG $_ :$message\r\n"
            for App::witchcraft->instance->Config->param('IRC_CHANNELS');
    }
    else {
        $self->irc_msg_join_part($message);
    }
    sleep 1; #assures message is delivered at least.
}

sub _connect {
    my $cfg    = App::witchcraft->instance->Config;
    my $self   = shift;
    my $socket = IO::Socket::INET->new(
        PeerAddr => $cfg->param('IRC_SERVER'),
        PeerPort => $cfg->param('IRC_PORT'),
        Proto    => "tcp",
        Timeout  => 10
    );
    $socket->autoflush(1) if $socket;
    return $socket;
}

sub _handle {
    my $self = shift;
    return undef unless $self->irc;
    my $cfg      = App::witchcraft->instance->Config;
    my $ident    = $cfg->param('IRC_IDENT');
    my $realname = $cfg->param('IRC_REALNAME');
    my @channels = $cfg->param('IRC_CHANNELS');
    my $socket   = $self->irc;
    printf $socket "NICK " . $cfg->param('IRC_NICKNAME') . "\r\n";
    printf $socket "USER $ident $ident $ident $ident :$realname\r\n";
    my $thr = threads->new(
        sub {
            local $SIG{USR1}
                = sub { printf $socket "QUIT\r\n"; threads->exit };
            while ( my $line = <$socket> ) {
                print $line if DEBUG;
                if ( $line =~ /^PING \:(.*)/ ) {
                    print $socket "PONG :$1\n";
                }
                if ( $line =~ m/^\:(.+?)\s+376/i ) {
                    printf $socket "JOIN $_\r\n" for @channels;
                }
            }
            $socket->close if ( defined $socket );
        }
    );
    $thr->detach;
    $self->thread($thr);
}

sub irc_msg_join_part {
    shift;
    my @MESSAGES = map { $_ =~ s/\n/ /g; $_ } @_;
    my $cfg = App::witchcraft->instance->Config;
    return undef unless ( defined $cfg->param('IRC_IDENT') );
    my $ident    = $cfg->param('IRC_IDENT');
    my $realname = $cfg->param('IRC_REALNAME');
    my @channels = $cfg->param('IRC_CHANNELS');
    my $socket   = IO::Socket::INET->new(
        PeerAddr => $cfg->param('IRC_SERVER'),
        PeerPort => $cfg->param('IRC_PORT'),
        Proto    => "tcp",
        Timeout  => 10
        )
        or error("Couldn't connect to the irc server")
        and return undef;
    info("Sending notification also on IRC") if DEBUG;
    return undef unless $socket;
    $socket->autoflush(1);
    sleep 2;
    printf $socket "NICK " . $cfg->param('IRC_NICKNAME') . "\r\n";
    printf $socket "USER $ident $ident $ident $ident :$realname\r\n";

    while ( my $line = <$socket> ) {
        if ( $line =~ /^PING \:(.*)/ ) {
            print $socket "PONG :$1\n";
        }

        if ( $line =~ m/^\:(.+?)\s+376/i ) {
            foreach my $chan (@channels) {
                printf $socket "JOIN $chan\r\n";
                info( "Joining $chan on " . $cfg->param('IRC_SERVER') )
                    if DEBUG;
                printf $socket "PRIVMSG $chan :$_\r\n" and sleep 2
                    for (@MESSAGES);
                sleep 5;
            }
            printf $socket "QUIT\r\n";
            $socket->close if ( defined $socket );
            last;
        }
    }
    $socket->close if ( defined $socket );

}

1;
