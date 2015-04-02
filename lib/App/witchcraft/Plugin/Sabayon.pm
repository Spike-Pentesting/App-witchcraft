package App::witchcraft::Plugin::Sabayon;
use Locale::TextDomain 'App-witchcraft';

use Deeme::Obj "App::witchcraft::Plugin::Gentoo";
use App::witchcraft;
use App::witchcraft::Utils
    qw(info error notice append spurt chwn log_command send_report);
use App::witchcraft::Utils::Gentoo
    qw(stripoverlay clean_logs find_logs to_ebuild remove_emerge_packages);

use App::witchcraft::Utils::Sabayon
    qw(entropy_update conf_update entropy_rescue calculate_missing);
use IPC::Run3;

sub register {
    my ( $self, $emitter ) = @_;
    $self->SUPER::register(@_);
    $emitter->on( "repositories.update" => sub { entropy_update(); } );

    $emitter->on(
        "packages.build.success" => sub {
            if (defined App::witchcraft->instance->Config->param(
                    'KERNEL_UPGRADE')
                and App::witchcraft->instance->Config->param('KERNEL_UPGRADE')
                == 1 )
            {

                my ($kernel)
                    = `equo match -q --installed virtual/linux-binary`;
                chomp($kernel);
                my ($current_kernel)
                    = `equo match --installed "$kernel" -q --showslot`;
                chomp($current_kernel);

                my ($available_kernel) = `equo match "$kernel" -q --showslot`;
                chomp($available_kernel);
                if ( $current_kernel != $available_kernel ) {
                    system("kernel-switcher switch $available_kernel");
                }

            }

        }

    );

    $emitter->on(
        "packages.build.success" => sub {
            shift;
            my ( $commit, @PACKAGES ) = @_;
            App::witchcraft->instance->emit(
                "packages.build.after.compression" => (@PACKAGES) );
            App::witchcraft->instance->emit(
                "packages.build.after.push" => ( @PACKAGES, $commit ) )
                if ( log_command("eit push --quick") );
        }
    );

    $emitter->on(
        "packages.build.before.emerge" => sub {
            shift;
            my $commit = pop @_;
            my @equo_install;
            entropy_update;
            return
                if !App::witchcraft->instance->Config->param(
                'EQUO_DEPINSTALL')
                or App::witchcraft->instance->Config->param('EQUO_DEPINSTALL')
                != 1;

            #reticulating splines here...
            push( @equo_install, &calculate_missing( $_, 1 ) ) for @_;
            info(
                __xn(
                    "One dependency of the package is not present in the system, installing them with equo",
                    "{count} dependencies of the package are not present in the system, installing them with equo",
                    scalar(@equo_install),
                    count => scalar(@equo_install)
                )
            );
            my $Installs = join( " ", @equo_install );
            info( __("Installing: ") );
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
    $emitter->on( "packages.build.after.compression" => sub { conf_update; }
    );

    $emitter->on(
        "packages.build.after.emerge" => sub {
            shift;
            local $ENV{EDITOR}             = "cat";    #quick hack
            local $ENV{ETP_NONINTERACTIVE} = "1";      #quick hack
            my $commit = pop @_;
            my @DIFFS  = @_;
            info(
                __x("Compressing {count} package(s): {packages}",
                    count    => scalar(@DIFFS),
                    packages => "@DIFFS"
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
            # system(
            #     'echo | eit inject `find /usr/portage/packages -name "*.tbz2" | xargs echo`'
            # );

            remove_emerge_packages;
        }
    );

}

1;

