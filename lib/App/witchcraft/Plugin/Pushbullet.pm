package App::witchcraft::Plugin::Pushbullet;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use forks;
use constant DEBUG => $ENV{DEBUG} || 0;

sub register {
    my ( $self, $emitter ) = @_;

    my $hostname = $App::witchcraft::HOSTNAME;
    return undef unless $emitter->Config->param('ALERT_BULLET');
    $emitter->on(
        "send_report_body" => sub {
            my ( $witchcraft, $message, $log ) = @_;
            $self->bullet( "note", $message, $log );
        }
    );
    $emitter->on(
        "send_report_link" => sub {
            my ( $witchcraft, $message, $url ) = @_;
            $self->bullet( "link", $message, $url );
        }
    );
    $emitter->on(
        "send_report_message" => sub {
            my ( $witchcraft, $message ) = @_;
            $self->bullet( "note", "Status", $message );
        }
    );

}

sub bullet {
    shift;
    my $type  = shift;
    my $title = shift;
    my $arg   = shift;

    my $hostname = $App::witchcraft::HOSTNAME;
    my $ua       = LWP::UserAgent->new;
    my @BULLET   = App::witchcraft->instance->Config->param('ALERT_BULLET');
    my $api      = $type eq "note" ? "body" : "url";
    foreach my $BULL (@BULLET) {
        threads->new(
            sub {
                my $req = POST 'https://api.pushbullet.com/v2/pushes',
                    [
                    type  => $type,
                    title => "Witchcraft\@$hostname: " . $title,
                    $api  => $arg
                    ];
                $req->authorization_basic($BULL);
                my $res = $ua->request($req)->as_string;
                if ( $res =~ /HTTP\/1.1 200 OK/mg ) {
                    notice("Push sent correctly!") if DEBUG;
                }
                else {
                    error("Error sending the push!") if DEBUG;
                }
                threads->exit;
            }
        )->detach;

    }
}

1;
