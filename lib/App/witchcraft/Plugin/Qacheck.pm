package App::witchcraft::Plugin::Qacheck;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error send_report uniq atom);
use Cwd;

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "after_test" => sub {
            my ( $witchcraft, $ebuild ) = @_;
            send_report(
                "Repoman output",
                "Repoman output for $ebuild",
                $self->repoman($ebuild)
            );
        }
    );
    $emitter->on(
        "after_emerge" => sub {
            my ( $witchcraft, @EBUILDS ) = @_;
            $emitter->emit( after_test => $_ ) for @EBUILDS;
        }
    );
}

sub repoman {
    my $self = shift;
    my $cwd  = cwd;
    local $_ = shift;
    atom();
    chdir( App::witchcraft->instance->Config->param('GIT_REPOSITORY') . "/"
            . $_ );
    my @repoman = qx/repoman scan/;
    chdir($cwd);
    return @repoman;
}
1;
