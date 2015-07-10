package App::witchcraft::Plugin::Entropy;
use Locale::TextDomain 'App-witchcraft';

use Deeme::Obj -base;
use App::witchcraft;
use App::witchcraft::Utils
    qw(info error notice append spurt chwn uniq log_command send_report);
use App::witchcraft::Utils::Gentoo qw(atom);
use App::witchcraft::Utils::Sabayon
    qw(entropy_update conf_update calculate_missing dependencies_not_in_entropy);

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
            if ( App::witchcraft->instance->Config->param("FOLLOW_VERSIONING")
                and
                App::witchcraft->instance->Config->param("FOLLOW_VERSIONING")
                == 1
                and @equo_install == 0 )
            {
                push( @equo_install, &calculate_missing( $_, 1 ) )
                    for map { atom($_); $_ =~ s/\=//g; $_ } @_;
            }
            @equo_install = uniq(@equo_install);
            my @not_in_entropy = dependencies_not_in_entropy(@equo_install);
            return 0 if ( @equo_install == 0 );
            info(
                __xn(
                    "One dependency of the package is not present in the system, installing them with equo",
                    "{count} dependencies of the package are not present in the system, installing them with equo",
                    scalar(@equo_install),
                    count => scalar(@equo_install) ) );
            send_report(
                info(
                    __xn(
                        "One dependency of the packages is not present in entropy, will be installed with emerge",
                        "{count} dependencies of the packages are not present in entropy, installing them with emerge",
                        scalar(@not_in_entropy),
                        count => scalar(@not_in_entropy) )
                ),
                @not_in_entropy
            );
            info( "\t-" . $_ ) for @not_in_entropy;
            my $Installs = join( " ", @equo_install );
            info( __("Installing: ") );
            notice($_) for @equo_install;
            system("sudo equo i -q --relaxed $Installs");
            conf_update;

        } );

}

1;

