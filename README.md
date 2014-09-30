
# NAME

App::witchcraft - Continuous integration tool, repository manager for Gentoo or your Entropy server

# SYNOPSIS

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

# DESCRIPTION

App::witchcraft is an evil tool for Entropy server Continuous integration, that means that help to align your build muchines with the git repository of your overlay, we use it internally at spike-pentesting.org to build packages.
It allows you to merge more overlay into one in a safe way: it tests installations by running emerge and integrate automatically into your overlay those who passed.
But it's far beyond that, it also checks updates, send reports thru push (using pushbullet.com), align build machines and much more, checkout the help.
It's strictly required a configuration file, located in ~/.witchcraft/witchcraft.conf, an example is shipped within the repo, it's so easy to configure and get up and running.

# INSTALLATION

Just run ./Build and ./Build install, ensure to have all licenses accepted into your machine adding inside make.conf

    ACCEPT_LICENSE="*"

and run this:

    ls /usr/portage/licenses -1 | xargs -0 > /etc/entropy/packages/license.accept

to have all licenses accepted in entropy

# AUTHOR

mudler <mudler@dark-lab.net>, skullbocks <skullbocks@dark-lab.net>

# COPYRIGHT

Copyright 2014- mudler, skullbocks

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
[App::witchcraft::Command::Euscan](https://metacpan.org/pod/App::witchcraft::Command::Euscan), [App::witchcraft::Command::Sync](https://metacpan.org/pod/App::witchcraft::Command::Sync)
