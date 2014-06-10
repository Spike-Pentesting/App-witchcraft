package App::witchcraft::Command;
use App::witchcraft;
use base qw(App::CLI::Command App::CLI);

use constant global_options => ( 'h|help' => 'help' );

sub alias {
    (   "l" => "list",
        "s" => "sync",
        "e" => "euscan",
        "t" => "test",
        "c" => "clean",
        "d" => "depinstall",
        "w" => "watch",
        "a" => "align",
        "p" => "pack",
        "u" => "upgrade"
    );
}

sub invoke {
    my ( $pkg, $cmd, @args ) = @_;
    local *ARGV = [ $cmd, @args ];
    if ( @args > 0 or defined $cmd ) {
        my $ret = eval { $pkg->dispatch(); };
        if ($@) {
            warn $@;
        }
    }
    else {
        &global_help;
    }
}

sub global_help {
    print <<'END';
App::witchcraft
____________

help (--help for full)
    - show help message

--> Scan new packages and add to the git repository:
*    e|euscan     "v|verbose", Verbose mode
                    "q|quiet"  , Quiet mode
                    "c|check"  , Only check updates
                    "u|update" , Add it to the git repository
                    "r|root"   , Set root of the git repository
                    "m|manifest", Manifest each ebuild found
                    "i|install", Also Install it
                    "g|git"    , Stages git add and commit for each ebuild
                    "f|force", Force the -i and -m also if the ebuild is already present

--> Checkout a repository and filter the ebuilds and add to the git repository
*    s|sync       "u|update" , Add it to the git repository
                    "r|refactor=s", Modify the refactor term
                    "t|refactortarget=s", Modify the target of the refactoring
                    "r|root=s",  Set root of the git repository
                    "t|temp=s",  Temp directory for the svn checkout
                    "i|install", Try to install them, output the file that passed
                    "a|add", It asks to add the failed installed packages to ignore list
                    "-x|--ignore-existing", ignore existing files from rsync copy to the git overlay.
                    "-g|--git", add and push automatically to git and entropy repository
                    "-v|--verbose", be more verbose

--> Install dependencies of a packages (if available) using equo
*   d|depinstall   [package]
                    "d|depth=i", define the deepness of the depdence tree, 0 to take all dependencies

--> List repository packages
*    l|list [repository]

--> Emerge and push to entropy repository
*    p|pack [package] [package2] ...

--> Align to the last compiled commit (or the specified one)
*    a|align [commit]

--> Upgrades the packages and push to the entropy repository
*    u|upgrade [repo]

--> Watch for ebuild change in the configured overlay
*    w|watch
                     "d|daemon", daemonize

--> Manifest & install untracked files, giving a report of what packages succedeed
*    t|test [repository dir]
                     "a|add", It asks to add the failed installed packages to ignore list

--> Clean all untracked files from the given repository
*    c|clean [repository dir]

You can inspect further doing "witchcraft help <command>"

END
}

1;
