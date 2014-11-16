package App::witchcraft::Build;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(build_processed build_processed_manually emit);
has [qw(packages id  )];
has 'manual'      => 0;
has 'track_build' => 0;
has 'args'        => sub { {} };

sub build {
    emit(
        "packages.build" => (
            (   ( ref $_[0]->packages ) ? @{ $_[0]->packages }
                : $_[0]->packages
            ),
            ( $_[0]->track_build == 0 ) ? sub { }
            : ( $_[0]->manual == 1 )
            ? sub { build_processed_manually( $_[0]->id ) }
            : sub { build_processed( $_[0]->id ) }            # on success
            ,
            $_[0]->args,
            $_[0]->id                                         #commit id
        )
    );
}

sub test {
    emit(
        "packages.test" => (
            ( ref $_[0]->packages )
            ? @{ $_[0]->packages }
            : $_[0]->packages
        )
    );
}

1;
