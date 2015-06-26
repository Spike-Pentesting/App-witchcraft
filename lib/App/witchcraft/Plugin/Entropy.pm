package App::witchcraft::Plugin::Entropy;
use Locale::TextDomain 'App-witchcraft';

use Deeme::Obj -base;
use App::witchcraft;
use App::witchcraft::Utils
    qw(info error notice append spurt chwn log_command send_report);

use App::witchcraft::Utils::Sabayon
    qw(entropy_update conf_update calculate_missing);

sub register {
    my ( $self, $emitter ) = @_;

    $emitter->on(
        "packages.build.before.emerge" => sub {
            shift;
            my $commit = pop @_;
            my @equo_install;
            entropy_update;

            #reticulating splines here...
            push( @equo_install, &calculate_missing( $_, 1 ) ) for @_;
            info(
                __xn(
                    "One dependency of the package is not present in the system, installing them with equo",
                    "{count} dependencies of the package are not present in the system, installing them with equo",
                    scalar(@equo_install),
                    count => scalar(@equo_install) ) );
            my $Installs = join( " ", @equo_install );
            info( __("Installing: ") );
            notice($_) for @equo_install;
            system("sudo equo i -q --relaxed $Installs");
            conf_update;

        } );

}

1;

