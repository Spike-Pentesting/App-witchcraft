package App::witchcraft::Build;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(build_processed build_processed_manually);
has [qw(packages id)];
has 'manual' => 0;

sub build {
    App::witchcraft->instance->emit(
        "packages.build" => (
            (   ( ref $_[0]->packages ) ? @{ $_[0]->packages }
                : $_[0]->packages
            ),
            ( $self->manual == 1 )
            ? sub { build_processed_manually( $_[0]->id ) }
            : sub { build_processed( $_[0]->id ) }            # on success
            ,
            $_[0]->id
        )
    );
}

sub test {
    App::witchcraft->instance->emit(
        "packages.test" => (
            ( ref $_[0]->packages )
            ? @{ $_[0]->packages }
            : $_[0]->packages
        )
    );
}

1;
