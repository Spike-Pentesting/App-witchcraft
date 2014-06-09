package App::witchcraft::Command::Clean;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils;
use warnings;
use strict;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Clean - Clean the repository from untracked files

=head1 SYNOPSIS

  $ witchcraft c
  $ witchcraft c <git_repository>

=head1 DESCRIPTION

Clean the repository from untracked files.
If an argument is supplied it clean that git repository.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::Witchcraft>, L<App::witchcraft::Command::Sync>

=cut
sub run {
    my $self = shift;
    my $dir
        = shift //  App::witchcraft->Config->param('GIT_REPOSITORY');
    error 'No GIT_REPOSITORY defined, or --root given' and exit 1 if(!$dir);
        info 'Cleaning all the untracked files in '.$dir;
    clean_untracked($dir);
}

1;
__DATA__
compat-wireless
linux-live
profiles
prism54
compat-drivers
acpid
layout.conf
linux-sources
genmenu
nvidia-drivers
ati-drivers
openrc
mkxf86config
genkernel
