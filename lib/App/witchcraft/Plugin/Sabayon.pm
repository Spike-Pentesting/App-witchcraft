package App::witchcraft::Plugin::Sabayon;

use Deeme::Obj "App::witchcraft::Plugin::Gentoo";
use App::witchcraft;
use App::witchcraft::Utils
    qw(info error notice append spurt chwn log_command);
use App::witchcraft::Utils::Gentoo
    qw(stripoverlay clean_logs find_logs upgrade to_ebuild);

use App::witchcraft::Utils::Sabayon
    qw(entropy_update conf_update entropy_rescue);
use IPC::Run3;

sub register {
    my ( $self, $emitter ) = @_;
    $self->SUPER::register;
    $emitter->on(
        "packages.build.before.emerge" => sub {
            shift;
            my $commit = pop @_;
            entropy_update;
            return
                if !App::witchcraft->instance->Config->param(
                'EQUO_DEPINSTALL')
                or App::witchcraft->instance->Config->param('EQUO_DEPINSTALL')
                != 1;

            #reticulating splines here...
            push( @equo_install, calculate_missing( $_, 1 ) ) for @_;
            info(
                __xn(
                    "One dependency of the package is not present in the system, installing them with equo",
                    "{count} dependencies of the package are not present in the system, installing them with equo",
                    scalar(@equo_install),
                    count => scalar(@equo_install)
                )
            );
            my $Installs = join( " ", @equo_install );
            info( __ "Installing: " );
            notice($_) for @equo_install;
            system("sudo equo i -q --relaxed $Installs");

        }
    );
    $emitter->on(
        "packages.build.after.push" => sub {
            my $commit = pop @_;
            info(
                __x("<{commit}> All went smooth, HURRAY!",
                    commit => $commit
                )
            );
            send_report(
                __x("<{commit}> All went smooth, HURRAY! do an equo up to checkout the juicy stuff",
                    commit => $commit
                )
            );
            entropy_rescue;
            entropy_update;
        }
    );
    $emitter->on( "packages.build.before.compression" => sub { conf_update; }
    );
    $emitter->on( "packages.build.after.compression" =>
            sub { $emitter->emit("packages.build.before.compression"); } );

    $emitter->on(
        "packages.build.after.emerge" => sub {
            shift;
            my $commit = pop @_;
            my @DIFFS  = @_;
            info(
                __x("Compressing {count} packages: {packages}",
                    count    => scalar(@DIFFS),
                    packages => @DIFFS
                )
            );

            App::witchcraft->instance->emit(
                "packages.build.before.compression" => (@DIFFS) );

            #       unshift( @CMD, "add" );
            #     push( @CMD, "--quick" );
            # $Expect->spawn( "eit", "add", "--quick", @CMD )
            #$Expect->spawn( "eit", "commit", "--quick",";echo ____END____" )
            #   or send_report("Cannot spawn eit: $!\n");
            sleep 1;
            send_report( __("Compressing packages"), @DIFFS );

            my ( $out, $err );
            run3(
                [ 'eit', 'commit', '--quick' ],
                \"Si\n\nYes\n\nSi\n\nYes\n\nSi\r\nYes\r\nSi\r\nYes\r\n",
                \$out, \$err
            );

            if ( $? == 0 ) {
                App::witchcraft->instance->emit(
                    "packages.build.after.compression" => (@DIFFS) );
                App::witchcraft->instance->emit(
                    "packages.build.after.push" => ( @DIFFS, $commit ) )
                    if ( log_command("eit push --quick") );
            }
            else {
                &send_report(
                    __( "Error in compression phase, you have to manually solve it"
                    ),
                    $out, $err
                );
            }
        }
    );

}

1;

