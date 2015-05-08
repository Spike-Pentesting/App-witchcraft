package App::witchcraft::Plugin::Qacheck;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error send_report uniq log_command);
use App::witchcraft::Utils::Gentoo qw( atom stripoverlay);
use Cwd;
use Locale::TextDomain 'App-witchcraft';

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "packages.test.after" => sub {
            my ( $witchcraft, $ebuild, undef ) = @_;
            if ( $ebuild =~ /\=/ ) {
                $ebuild =~ s/=//g;
                $ebuild = stripoverlay($ebuild);
                $ebuild = atom($ebuild);
                info(
                    "XXX: FOR GOD SAKE it's "
                      . App::witchcraft->instance->Config->param(
                        'GIT_REPOSITORY')
                      . "/"
                      . $ebuild
                );
            }
            send_report(
                info(
                    __x(
                        "[QA] Repoman output for {ebuild}", ebuild => $ebuild
                    )
                ),
                $self->repoman($ebuild)
            );
        }
    );
    $emitter->on(
        "packages.build.after.emerge" => sub {
            my ( $witchcraft, $ebuild, undef ) = @_;
            send_report(
                info(
                    __x(
                        "[QA] Repoman output for {ebuild}", ebuild => $ebuild
                    )
                ),
                $self->repoman($ebuild)
            );
        }
    );
    $emitter->on(
        "packages.build.success" => sub {
            my ( $witchcraft, $ebuild, undef ) = @_;
            send_report(
                info(
                    __x(
                        "[QA] Repoman output for {ebuild}", ebuild => $ebuild
                    )
                ),
                $self->repoman($ebuild)
            );
        }
    );
}

sub repoman {
    shift;
    my $cwd = cwd;
    local $_ = shift;
    stripoverlay;
    atom;
    chdir(
        App::witchcraft->instance->Config->param('GIT_REPOSITORY') . "/" . $_ );
    my @repoman = qx/repoman scan/;
    chdir($cwd);
    return @repoman;
}
1;
