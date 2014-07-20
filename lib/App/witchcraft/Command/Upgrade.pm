package App::witchcraft::Command::Upgrade;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use App::witchcraft::Utils qw(list_available);


=encoding utf-8

=head1 NAME

App::witchcraft::Command::Upgrade - Upgrade entropy repository packages

=head1 SYNOPSIS

  $ witchcraft upgrade [repo]
  $ witchcraft u

=head1 DESCRIPTION

Upgrade entropy repository packages.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::witchcraft>, L<App::witchcraft::Command::Sync>

=cut

sub run {
    error 'You must run it with root permissions' and exit 1 if $> != 0;
   my $self = shift;
    my $Repo = shift // App::witchcraft->Config->param('OVERLAY_NAME');
    info 'Upgrade of the Sabayon repository ' . $Repo;
    my $password = password_dialog();
    info "Retrevieng packages in the repository" if $self->{verbose};
    my @Packages = list_available({},$Repo);
    return emerge( { '-n' => "" }, @Packages );
}

1;
