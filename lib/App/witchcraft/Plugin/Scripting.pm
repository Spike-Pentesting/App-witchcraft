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
    $emitter->on(
        emit => sub {
            shift;
            my ( $event, @args ) = @_;
            if ( -e $DIR . $event ) {
                info __x(
                    "[Plugin::Scripting] Executing script: ({script})",
                    script => "cd $DIR;./$event @args"
                );
                system("cd $DIR;./$event @args");
            }
        }
    );
}

1;
