package App::witchcraft::Plugin::Githook;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice emit);
use Cwd;
use Git::Sub;
use Github::Hooks::Receiver;
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
            emit("align_to");
        }
    );
    $emitter->on(
        "githook.server.start" => sub {
            my $receiver = Github::Hooks::Receiver->new(
                secret => App::witchcraft->Config->param("GITHOOK_SECRET") );
            $receiver->on(
                push => sub {
                    App::witchcraft->instance->emit( "git_push" => @_ );
                }
            );
            $receiver->parse_options(
                App::witchcraft->Config->param("GITHOOK_PLACK_OPTIONS") );
            $receiver->to_app->run();
        }
    );
}

1;
