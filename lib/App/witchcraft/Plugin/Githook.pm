package App::witchcraft::Plugin::Githook;
use Deeme::Obj -base;
use App::witchcraft::Utils
    qw(info error notice append dialog_yes_default send_report spurt chwn index_sync test_ebuild clean_logs uniq);
use Cwd;
use Git::Sub;
use Github::Hooks::Receiver::Declare;
use App::witchcraft;

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "git_push" => sub {
            shift;
            my $event = shift;
            warn $event->event;
            my $payload = $event->payload;
            info $payload;
            notice $event->event;
        }
    );
    my $receiver = Github::Hooks::Receiver->new(
        secret => App::witchcraft->Config->param("SECRET") );
    $receiver->on(
        push => sub {
            my ( $event, $req ) = @_;
            App::witchcraft->instance->emit( "git_push" => $event );
        }
    );
    $receiver->to_app->run();
}

1;
