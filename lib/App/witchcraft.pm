package App::witchcraft;
use strict;
use 5.008_005;
use Deeme::Obj 'Deeme';
use App::CLI;
use Config::Simple;
use App::witchcraft::Loader;
our $VERSION = 0.016;
our $CONFIG_FILE = $ENV{WITCHCRAFT_CONFIG} // "witchcraft.conf"
    ;    #with this you can handle multiple repos configurations
our $IGNORE_FILE          = "ignored.packages";
our $WITCHCRAFT_DIRECTORY = ".witchcraft";
our $HOME                 = join( "/", $ENV{HOME}, $WITCHCRAFT_DIRECTORY );
our $CONFIG
    = -e join( "/", $HOME, $CONFIG_FILE )
    ? join( "/", $HOME, $CONFIG_FILE )
    : join( "/", '.',   $CONFIG_FILE );
$CONFIG = Config::Simple->new($CONFIG) if ( -e $CONFIG );
our $IGNORE
    = -e join( "/", $HOME, $IGNORE_FILE ) ? join( "/", $HOME, $IGNORE_FILE )
    : $CONFIG->isa("Config::Simple")
    ? join( "/", $CONFIG->param("GIT_REPOSITORY"), $IGNORE_FILE )
    : "";

our $HOSTNAME = `hostname`;
chomp($HOSTNAME);

my $singleton;

sub new { $singleton ||= shift->SUPER::new(@_); }


sub load_plugins {
    my $self   = shift;
    my $Loader = App::witchcraft::Loader->new;
    if ( my @PLUGINS = $self->Config->param("PLUGINS") ) {
        for (@PLUGINS) {
            my $Plugin = "App::witchcraft::Plugin::" . ucfirst($_);
            next if $Loader->load($Plugin);
            $Plugin->new->register($self);
        }
    }
}

has 'Config' => sub {
    $CONFIG;
};

*instance = \&new;
1;

=encoding utf-8

=head1 NAME

App::witchcraft - Continuous integration tool, repository manager for Gentoo or your Entropy server

=head1 SYNOPSIS

  $ witchcraft --help
  $ --> Scan new packages and add to the git repository:
    *    e|--euscan  "-v|--verbose" => Verbose mode
                                "-q|--quiet" => Quiet mode
                                "-c|--check" => Only check updates
                                "-u|--update" => Add it to the git repository
                                "-r|--root" => Set root of the git repository
                                "-m|--manifest" => Manifest each ebuild found
                                "-i|--install" => Also Install it
                                "-g|--git" => Stages git add and commit for each ebuild
                                "-f|--force" => Force the -i and -m also if the ebuild is already present

  $ --> Automatically bumps packages using euscan:
    *    bu|bump [full|scan]  "-n|--no-test" => skip tests
                                "-g|--git" => Stages git add and commit for each package
                                "-f|--force" => Force the -i and -m also if the ebuild is already present
           bump scan cat/atom

    --> Checkout a repository and filter the ebuilds and add to the git repository (supports multiple repository)
    *    s|--sync      "-u|--update" => Add it to the git repository
                                "-r|--refactor=s", Modify the refactor term
                                "-t|--refactortarget=s" => Modify the target of the refactoring
                                "-r|--root=s" =>  Set root of the git repository
                                "-t|--temp=s" => Temp directory for the svn checkout
                                "-i|--install" => Try to install them, output the file that passed
                                "-a|--add" => It asks to add the failed installed packages to ignore list
                                "-x|--ignore-existing" => ignore existing files from rsync copy to the git overlay.
                                "-g|--git" => add and push automatically to git repository
                                "-e|--eit" => add and push automatically to entropy repository
                                "-v|--verbose" => be more verbose

    -> Common fix and handling for overlays
    *   f|fix (ebuild_missing|digest|metagen) [dir]
                                ebuild_missing => remove atoms that doesn't contain ebuilds at all
                                digest  => digest each ebuild found
                                metagen => metagen -vm each atom that doesn't have it

    --> Install dependencies of a packages (if available) using equo
    *   d|depinstall   [package]
                                 "-d|--depth=i" => define the deepness of the depdence tree, 0 to take all dependencies

    --> List repository packages
    *    l|list [repository]

     --> List or delete package conflicts between other repository
    *    r|conflict
                                    "-d|delete" => automatically delete from the sabayon repository

    --> Emerge and push to entropy repository
    *    p|pack [package] [package2] ...

    --> Perform automatic mantaining tasks, you can choose the behaviour and ensamble commands executions
    *    m|mantain  "-a|--align"   => "align", alias of witchcraft align
                                    "-s|--sync"    => "sync", alias of witchcraft sync -iuxg
                                    "-u|--upgrade" => "upgrade", alias of witchcraft upgrade
                                    "-q|--quit"    => "quit", shutdown computer when finished
                                    "-l|--loop"    => "loop" enters an infinite loop
                                    "-e|--euscan" => "euscan", alias of witchcraft euscan -migu

    --> Align to the last compiled commit (or the specified one)
    *    a|align [commit]

    --> Upgrades the packages and push to the entropy repository
    *    u|upgrade [repo]

    --> Watch for ebuild change in the configured overlay
    *    w|watch
                                "-d|--daemon" => daemonize

    --> Manifest & install untracked files, giving a report of what packages succedeed
    *    t|test [repository dir]
                                 "-a|--add" => It asks to add the failed installed packages to ignore list

    --> Clean all untracked files from the given repository
    *    c|clean [repository dir]
                                "nostash"   => avoid "git stash"

    --> Manage your vagrant boxes
    *    b|box (list|status|halt|up|ssh|monitor_start|monitor_stop)
                                 "list"                => list your boxes
                                 "status"           => print the boxes status
                                 "halt"               => stop all the boxes
                                 "up"                 => starts all your boxes
                                 "ssh"               => spawn a new tmux window and do a vagrant ssh for the boxes
                                 "monitor_start" => spawn a process monitor for the boxes
                                 "monitor_stop" => kills the monitor process


=head1 DESCRIPTION

App::witchcraft is an evil tool for Entropy/Portage Continuous integration, that means that help to align your build machines with the repository of your overlay, we use it internally at spike-pentesting.org to build packages.
It allows you to merge more overlay into one in a safe way: it tests installations by running emerge and integrate automatically into your overlay those who passed.
But it's far beyond that, it also checks updates, send reports with pushes (using pushbullet.com), align build machines and much more, checkout the help (C<witchcraft help>).
It's strictly required a configuration file, located in ~/.witchcraft/witchcraft.conf, an example is shipped within the repo, it's so easy to configure and get up and running.
You can also setup up more configuration files, and specifying them using WITCHCRAFT_CONFIG env variable.

=head1 INSTALLATION

Just run ./Build and ./Build install

=head1 STRUCTURE

The software has two common use cases:

=over

=item standalone client for the developer (fixing ebuilds, testing, manual bump, repository mantainance)

=item agent mode on boot inside a vm

=back

Witchcraft operates over a set of vagrant vm (that can be set up also on a different path/user), bringing em up and starting the agent to the desired routine commands, for the operations customization, have a look at L<App::witchcraft::Command::Mantain>.

I'm a dev and don't want a testing vm -  you can still install it and use on your own machine, for autobumping, testing untracked ebuilds on repository, QA reports ...

I want to set up a vm! - It's just easy as 1...2...3... set up your vagrant machine, and specify it on the config file.
To perform witchcraft commands on boot, in the C<ex/> directory it's present a sample of systemd unit file that performs basically mantain operations and then shuts down the machine.

=head1 CONFIGURATION

Every customization and configuration must be explicitally set on your config file. There is a default configuration file (~/.witchcraft/witchcraft.conf) loaded if no one is specified with the WITCHCRAFT_CONFIG env variable (if you start it WITCHCRAFT_CONFIG = "builder" , a ~/.witchcraft/builder config file must be present).

=head2 Basic options

=head3 DISTRO

Tell to witchcraft what is your distribution that you intend to mantain

    DISTRO: sabayon #or gentoo

=head3 EQUO_DEPINSTALL (sabayon)

If enabled, before emerging packages, try to determine if its dependencies are already on entropy servers instead re-emerging them.

    EQUO_DEPINSTALL: 1

=head3 REPORT_TEST_FAILS

If enabled, reports also all failed tests (in every phase! this makes witchcraft a lot verbose!)

=head3 EMERGE_OPTS and EMERGE_UPGRADE_OPTS

Options to be passed to emerge

    EMERGE_OPTS: --autounmask-write
    EMERGE_UPGRADE_OPTS: -n

=head3 OVERLAY_PATH and OVERLAY_NAME

OVERLAY_PATH should be set to the layman path of the repository (usually /var/lib/layman/)

    OVERLAY_PATH: /var/lib/layman/some
    OVERLAY_NAME: some_overlay

=head3 OVERLAY_MANUAL_COMPILE_FILE

Here you can specify a file that would be watched during watching and syncronization phases, at each edit of the specified file, will be issued a compilation of the packages declared inside it.

    #Here you can specify the file that contains the package to be built manually
    OVERLAY_MANUAL_COMPILE_FILE: overlay_tools/packages.txt
    # where packages.txt contains packages at each line: x11-wm/something

=head3 SLEEP_TIME

Sets up the desired sleep between syncs (just required if you intend to use the L<App::witchcraft::Command::Watch> )

    #Sleep time for "watch" command
    SLEEP_TIME: 100

=head3 GIT_REPOSITORY

This is the path of the git repository where the builder will commit the changes (be sure to have the permission to write, without password asking)

    #Git repository locaiton where the builder will commits the modifications
    GIT_REPOSITORY:/home/something/gentoo-overlay

=head3 REMOTE_OVERLAY and REFACTOR_*

This is needed if your repo will be a result of overlay merge(s).
You can specify here a list of svn/git repo url that could be checked out or cloned.

    #here you can specify the overlay that should be merged
    REMOTE_OVERLAY: some_svn_url,some_git_url,other_git_overlay,other_svn_overlay,....

when merging repository, could be useful to refactor the ebuilds (e.g. hardcoded paths /opt/something -> /opt/something_refactored, or just einfo messages)

You can specify here a list of terms that will be replaced in the corresponding overlays

    REFACTOR: original_1st_overlay_contains, original_2nd_overlay_contains
    REFACTOR_TO: new_name_for_1st_overlay, new_name_for_2nd_overlay

e.g. replace "sunrise" with "myrepo"

    REMOTE_OVERLAY: sunrise_uri
    REFACTOR: sunrise
    REFACTOR_TO: myrepo

=head3 WITCHCRAFT_GIT

Enables cpanm automatic updates at each mantain, specifying the url of the module

    #This will make automatic updates, synced with the github repo
    WITCHCRAFT_GIT: ssh://git@github.com:Spike-Pentesting/App-Witchcraft.git

Note: you can also use pinto urls, this argument is just being passed at cpanm

=head3 FAKE_ENV_HOME, FAKE_ENV_VAGRANT_HOME , VAGRANT_BOXES

To set up your vagrant boxes, you have also the possibility to fake a vagrant environment.
For example, if you wish to have the default directories of vagrant in another location rather than your home, first set up HOME and VAGRANT_HOME accordingly to suit your needs, then tell witchcraft where are located

    #Vagrant options, required only if you plan to use the "box" command
    FAKE_ENV_HOME: /mnt/usb/vagrantuser
    FAKE_ENV_VAGRANT_HOME: /mnt/usb/vagrantuser/.vagrant.d
    VAGRANT_BOXES: /mnt/usb/vagrantuser/Builder64,/mnt/usb/vagrantuser/Builder32

=head3 Advanced options

You usually don't need to touch these options, but here there are for the most curious:

    LAST_COMMIT: /var/tmp/lastcommit.witchcraft # here relies the last successfull compiled commit
    MD5_PACKAGES: /var/tmp/md5_packages.witchcraft # here it's stored the md5 of the OVERLAY_MANUAL_COMPILE_FILE

    #temporary directory, used during cvs/git clone phases (merging)
    CVS_TMP:/var/tmp/spike-trunk


=head2 Plugins

You can enable/disable feature, specifying what you need on the config file:

e.g.

    PLUGINS: depcheck, irc, pushbullet, log, git, qacheck

will load:

=over

=item depcheck plugin for RDEPEND checks

=item irc for irc notifications

=item pushbullet uses pushbullet.com api to deliver pushes notifications

=item log enable logging on /var/log/witchcraft

=item git tells to witchcraft that the repo to handle it's a git one

=item Qacheck calls repoman on each passed ebuild

=item ...

=back

=head3 Plugin configuration

Plugins can require more specific fine grained options, the sample configuration file provided, it's configured for a full usage, feel free to cut up the pieces that you don't need.

=head4 IRC

The irc plugin, for example, requires those fields to be set, otherwise are unnecessary:

    IRC_SERVER: chat.freenode.net
    IRC_PORT: 6667
    IRC_CHANNELS: #spike-pentesting-dev
    IRC_NICKNAME: Witchcraft_Build
    IRC_IDENT: WitchCraft
    IRC_REALNAME: Witch

This example will spawn an IRC bot for status report on the #spike-pentesting-dev channel, on the freenode network.

=head4 PUSHBULLET

If you are registered on pushbullet, there is a good news for you, well at least if you are a report enthusiast.

e.g.

    ALERT_BULLET: key1,key2

If you enable the pushbullet plugin, specify here the api keys (that you can obtain on pushbullet.com) that would receive the build statuses.

=head4 LOG

The log plugin, enables logging:

    LOGS_DIR: /var/log/witchcraft
    LOGS_USER: root

Those configuration options are explicitally needed, but you can leave as default if you don't know what are you doing.

=head1 NOTES
For sabayon vm:
ensure to have all licenses accepted into your machine adding inside make.conf

    ACCEPT_LICENSE="*"

and then run this:

    ls /usr/portage/licenses -1 | xargs -0 > /etc/entropy/packages/license.accept

to have all licenses accepted in entropy

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>, skullbocks E<lt>skullbocks@dark-lab.netE<gt>

=head1 IRC

chat.freenode.net - #spike-pentesting-dev

=head1 COPYRIGHT

Copyright 2014- mudler, skullbocks

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::witchcraft::Command::Euscan>, L<App::witchcraft::Command::Sync>

=cut

