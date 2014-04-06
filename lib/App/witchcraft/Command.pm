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

--> Scan new packages and add to the git repository:
*    e|--euscan     "v|verbose", Verbose mode
                    "q|quiet"  , Quiet mode
                    "c|check"  , Only check updates
                    "u|update" , Add it to the git repository
                    "r|root"   , Set root of the git repository
                    "m|manifest", Manifest each ebuild found
                    "i|install", Also Install & Merge it
                    "g|git"    , Stages git add and commit for each ebuild

--> Checkout a repository and filter the ebuilds and add to the git repository
*    s|--sync       "u|update" , Add it to the git repository
                    "r|refactor=s", Modify the refactor term
                    "t|refactortarget=s", Modify the target of the refactoring
                    "r|root=s",  Set root of the git repository
                    "t|temp=s",  Temp directory for the svn checkout
                    "i|install", Try to install them, output the file that passed

*    l|--list [repository]     list repository packages
END
}

1;
