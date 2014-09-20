package App::witchcraft::Plugin::Depcheck;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error send_report);

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "after_test" => sub {
            my ( $witchcraft, $ebuild ) = @_;
            my @RDEPEND = $self->depcheck($ebuild);
            if ( @RDEPEND > 0 ) {
                error "$ebuild seems missing that RDPENDs: @RDEPEND";
                send_report( "RDEPEND missing for $ebuild", @RDEPEND );
            }
        }
    );
    $emitter->on(
        "after_emerge" => sub {
            my ( $witchcraft, @EBUILDS ) = @_;
            foreach my $ebuild (@EBUILDS) {
                my @RDEPEND = $self->depcheck($ebuild);
                if ( @RDEPEND > 0 ) {
                    error "$ebuild seems missing that RDPENDs: @RDEPEND";
                    send_report( "RDEPEND missing for $ebuild", @RDEPEND );
                }
            }
        }
    );
}

sub depcheck {
    my $self     = shift;
    my $packet   = shift;
    my @depcheck = qx/depcheck $packet/;
    my @RDEPEND;
    foreach my $line (@depcheck) {
        push( @RDEPEND, split( / /, $1 ) )
            if ( $line =~ /RDEPEND on (.*)/ or $line =~ /RDEPEND: (.*)/ );
    }
    return @RDEPEND;
}
1;
