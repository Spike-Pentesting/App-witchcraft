# NAME

App::witchcraft - Helps the overlay mantainer doing is dirty job

# SYNOPSIS

    $ witchcraft --help
    $     --> Scan new packages and add to the git repository:
          *    e|--euscan     "v|verbose", Verbose mode
                              "q|quiet"  , Quiet mode
                              "c|check"  , Only check updates
                              "u|update" , Add it to the git repository
                              "r|root"   , Set root of the git repository
                              "m|manifest", Manifest each ebuild found
                              "i|install", Also Install it
                              "g|git"    , Stages git add and commit for each ebuild

          --> Checkout a repository and filter the ebuilds and add to the git repository
          *    s|--sync       "u|update" , Add it to the git repository
                              "r|refactor=s", Modify the refactor term
                              "t|refactortarget=s", Modify the target of the refactoring
                              "r|root=s",  Set root of the git repository
                              "t|temp=s",  Temp directory for the svn checkout
                              "i|install", Try to install them, output the file that passed

          --> List repository packages
          *    l|--list [repository]     

          --> Manifest & install untracked files, giving a report of what packages succedeed
          *    t|--test [repository dir] 

          --> Clean all untracked files from the given repository
          *    c|--clean [repository dir]

# DESCRIPTION

App::witchcraft is an evil tool that do a lot of tasks: performs euscan for the atoms in a sabayon repository, test and update them, committing to the git repository...
Just invoke --help to see all the features

# AUTHOR

mudler <mudler@dark-lab.net>, skullbocks <skullbocks@dark-lab.net>

# COPYRIGHT

Copyright 2014- mudler, skullbocks

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
