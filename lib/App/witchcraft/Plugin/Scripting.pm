package App::witchcraft::Plugin::Scripting;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice emit);
use Cwd;
use App::witchcraft;
use Locale::TextDomain 'App-witchcraft';

sub register {
    my ( $self, $emitter ) = @_;
    my $cfg = App::witchcraft->instance->Config;
    my $DIR = $cfg->param("SCRIPTING_DIR");
    info "Scripting plugin loaded";
    $emitter->on(
        emit => sub {
            shift;
            my ( $event, @args ) = @_;

            if ( -e $DIR . $event ) {
                                info "EVENTO: $event : $DIR $event";

                info __x(
                    "Executing script: ({script})",
                    script => "cd $DIR;./$event @args"
                );
                system("cd $DIR;./$event @args");
            }
        }
    );
}

1;
