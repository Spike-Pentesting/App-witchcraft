package App::witchcraft::Plugin::Slack;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use constant DEBUG => $ENV{DEBUG} || 0;
use Locale::TextDomain 'App-witchcraft';
use WebService::Slack::WebApi;

sub register {
    my ( $self, $emitter ) = @_;
    return undef unless $emitter->Config->param('SLACK_TOKEN');
    return undef unless $emitter->Config->param('SLACK_CHANNEL');
    my $username = $emitter->Config->param('SLACK_NICK')
      // $App::witchcraft::HOSTNAME;

    $emitter->on(
        "send_report_body" => sub {
            my ( $witchcraft, $message, $log ) = @_;
            my $slack =
              WebService::Slack::WebApi->new(
                token => $emitter->Config->param('SLACK_TOKEN') );

            $slack->chat->post_message(
                channel  => $emitter->Config->param('SLACK_CHANNEL'),
                text     => $message . '-' . $log,
                parse    => "full",
                username => $emitter->Config->param('SLACK_NICK'),
            );
        }
    );
    $emitter->on(
        "send_report_link" => sub {
            my ( $witchcraft, $message, $url ) = @_;
            my $slack =
              WebService::Slack::WebApi->new(
                token => $emitter->Config->param('SLACK_TOKEN') );

            $slack->chat->post_message(
                channel  => $emitter->Config->param('SLACK_CHANNEL'),
                text     => $message . '-' . $url,
                username => $emitter->Config->param('SLACK_NICK'),
            );
        }
    );
    $emitter->on(
        "send_report_message" => sub {
            my ( $witchcraft, $message ) = @_;
            my $slack =
              WebService::Slack::WebApi->new(
                token => $emitter->Config->param('SLACK_TOKEN') );

            $slack->chat->post_message(
                channel  => $emitter->Config->param('SLACK_CHANNEL'),
                text     => $message,
                username => $emitter->Config->param('SLACK_NICK'),
            );
        }
    );

}

1;
