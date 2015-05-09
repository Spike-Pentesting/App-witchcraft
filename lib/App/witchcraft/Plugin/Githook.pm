package App::witchcraft::Plugin::Githook;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice emit);
use Cwd;
use Git::Sub;
use Github::Hooks::Receiver;
use App::witchcraft;
use Locale::TextDomain 'App-witchcraft';

sub register {
    my ( $self, $emitter ) = @_;
    my $cfg = App::witchcraft->instance->Config;
    $emitter->on(
        "git_push" => sub {
            shift;
            my $event   = shift;
            my $payload = $event->payload;
            info( __x( "Payload: {payload}", payload => $payload ) )
                if $payload;
            info( __x( "Event: {event}", event => $event->event ) )
                if $event->event;
            emit("align_to");
        } );
    $emitter->on(
        "githook.server.start" => sub {
            my $receiver = Github::Hooks::Receiver->new(
                secret => $cfg->param("GITHOOK_SECRET") );
            $receiver->on(

                #listening on events it's supported for github "push" =>
                sub {
                    $emitter->emit( "git_push" => @_ );
                } );
            my $psgi = $receiver->to_app;
            $receiver->run( $cfg->param("GITHOOK_PLACK_OPTIONS") );
        } );
}

1;
