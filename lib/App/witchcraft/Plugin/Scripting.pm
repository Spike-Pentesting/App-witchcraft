package App::witchcraft::Plugin::Scripting;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice emit send_report);
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
                send_report(
                    info(
                        __x(
                            "[Scripting] Executing script: ({script})",
                            script => "cd $DIR;./$event @args"
                        )
                    )
                );
                my $rt = system("cd $DIR;./$event @args");
                send_report(
                    info(
                        __x(
                            "[Scripting] {script} returned {status}",
                            script => "cd $DIR;./$event @args",
                            status => $rt,
                        )
                    )
                );
            }
        }
    );
}

1;
