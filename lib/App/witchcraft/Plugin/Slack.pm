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
    my $slack = WebService::Slack::WebApi->new(
        token => $emitter->Config->param('SLACK_TOKEN') );

    $emitter->on(
        "send_report_body" => sub {
            my ( $witchcraft, $message, $log ) = @_;
            eval {
                $slack->chat->post_message(
                    channel  => $emitter->Config->param('SLACK_CHANNEL'),
                    username => $emitter->Config->param('SLACK_NICK'),
                    text     => $message . ' - ' . $log,
                );
            };
            warn $@ if $@;
        } );
    $emitter->on(
        "send_report_link" => sub {
            my ( $witchcraft, $message, $url ) = @_;
            eval {
                $slack->chat->post_message(
                    channel  => $emitter->Config->param('SLACK_CHANNEL'),
                    username => $emitter->Config->param('SLACK_NICK'),
                    text     => $message . ' - ' . $url,
                );
            };
            warn $@ if $@;
        } );
    $emitter->on(
        "send_report_message" => sub {
            my ( $witchcraft, $message ) = @_;
            eval {
                $slack->chat->post_message(
                    channel  => $emitter->Config->param('SLACK_CHANNEL'),
                    username => $emitter->Config->param('SLACK_NICK'),
                    text     => $message,
                );
            };
            warn $@ if $@;
        } );

}

1;
