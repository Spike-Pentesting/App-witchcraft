package App::witchcraft::Build;
use Deeme::Obj -base;
use App::witchcraft::Utils qw(build_processed build_processed_manually emit);
has [qw(packages id  )];
has 'manual'      => 0;
has 'track_build' => 0;
has 'args'        => sub { { "--buildpkg" => '' } };
has 'options' => sub { { relaxed => 1 } }; #XXX: must be empty, just for debug

sub build {
    my $id = $_[0]->id;
    emit(
        "packages.build" => ( (
                ( ref $_[0]->packages ) ? @{ $_[0]->packages }
                : $_[0]->packages
            ),
            sub { },
            ( $_[0]->track_build == 0 ) ? sub { }
            : ( $_[0]->manual == 1 ) ? sub { build_processed_manually($id) }
            : sub { build_processed($id) }    # on success
            ,
            $_[0]->args,
            $_[0]->options,
            $_[0]->id                         #commit id
        ) );
}

sub test {
    emit(
        "packages.test" => (
            {},
            ( ref $_[0]->packages )
            ? @{ $_[0]->packages }
            : $_[0]->packages
        ) );
}

1;
