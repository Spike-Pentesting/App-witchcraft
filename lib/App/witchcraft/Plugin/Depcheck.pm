package App::witchcraft::Plugin::Depcheck;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error send_report uniq);
use Locale::TextDomain 'App-witchcraft';

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "packages.test.after" => sub {
            my ( $witchcraft, $ebuild, undef ) = @_;
            $self->test($ebuild);
        }
    );
    $emitter->on(
        "packages.build.after.emerge" => sub {
            my ( $witchcraft, $ebuild, undef ) = @_;
            $self->test($ebuild);
        }
    );
}

sub test {
    my ( $self, $ebuild ) = @_;
    my @RDEPEND = uniq( $self->depcheck($ebuild) );
    if ( @RDEPEND > 0 ) {
        send_report(
            error(
                __x(
                    "[Depcheck] {ebuild} seems missing that RDPENDs: {RDEPEND}",
                    RDEPEND => "@RDEPEND",
                    ebuild  => $ebuild
                ),
                @RDEPEND
            )
        );
    }
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
