package App::witchcraft::Plugin::Depcheck;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error send_report uniq);
use Locale::TextDomain 'App-witchcraft';

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "after_test" => sub {
            my ( $witchcraft, $ebuild ) = @_;
            my @RDEPEND = uniq( $self->depcheck($ebuild) );
            if ( @RDEPEND > 0 ) {
                error __x(
                    "{ebuild} seems missing that RDPENDs: {RDEPEND}",
                    ebuild  => $ebuild,
                    RDEPEND => "@RDEPEND"
                );
                send_report(
                    __x( "RDEPEND missing for {ebuild}", ebuild => $ebuild ),
                    @RDEPEND
                );
            }
        }
    );
    $emitter->on(
        "packages.build.after.emerge" => sub {
            my ( $witchcraft, @EBUILDS ) = @_;
            $emitter->emit( after_test => $_ ) for @EBUILDS;
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
