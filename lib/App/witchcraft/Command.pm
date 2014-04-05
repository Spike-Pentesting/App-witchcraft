package App::witchcraft::Command;
use App::witchcraft;
use base qw(App::CLI::Command App::CLI);

use constant global_options => ( 'help' => 'help' );

sub alias {
    (   "l" => "list",
        "s" => "sync",
        "e" => "euscan"
    );
}

sub invoke {
    my ( $pkg, $cmd, @args ) = @_;
    local *ARGV = [ $cmd, @args ];
    my $ret = eval { $pkg->dispatch(); };
    if ($@) {
        warn $@;
    }
}

sub run() {
    my $self = shift;
    $self->global_help if ( $self->{help} );
}

sub global_help {
    print <<'END';
App::witchcraft
____________

help (--help for full)
    - show help message

add something, here
    - lol


END
}

1;
