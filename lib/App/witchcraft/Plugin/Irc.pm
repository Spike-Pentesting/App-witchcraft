package App::witchcraft::Plugin::Irc;

use Deeme::Obj -base;
use IO::Socket::INET;
use App::witchcraft::Utils qw(info error notice);

sub register {
    my ( $self, $emitter ) = @_;
    my $hostname = $App::witchcraft::HOSTNAME;
    return undef unless $emitter->Config->param('IRC_CHANNELS');
    info "<Plugin: IRC> Configured, loading";
    notice $_ for ($emitter->Config->param('IRC_CHANNELS'));
    $emitter->on(
        "send_report_link" => sub {
            my ( $witchcraft, $message, $url ) = @_;
            $self->irc_msg(
                "Witchcraft\@$hostname: " . $message . " - " . $url );
        }
    );
    $emitter->on(
        "send_report_message" => sub {
            my ( $witchcraft, $message ) = @_;
            $self->irc_msg( "Witchcraft\@$hostname: " . $message );
        }
    );

}

sub irc_msg {
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
    ) or error("Couldn't connect to the irc server");
    info("Sending notification also on IRC");
    $socket->autoflush(1);
    sleep 2;
    printf $socket "NICK " . $cfg->param('IRC_NICKNAME') . "\r\n";
    printf $socket "USER $ident $ident $ident $ident :$realname\r\n";

    while ( my $line = <$socket> ) {
        if ( $line =~ m/^\:(.+?)\s+376/i ) {
            foreach my $chan (@channels) {
                printf $socket "JOIN $chan\r\n";
                info( "Joining $chan on " . $cfg->param('IRC_SERVER') );
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
