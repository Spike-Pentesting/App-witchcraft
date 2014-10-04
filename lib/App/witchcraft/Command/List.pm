package App::witchcraft::Command::List;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils qw(distrocheck error);

=encoding utf-8

=head1 NAME

App::witchcraft::Command::List - List entropy repository packages

=head1 SYNOPSIS

  $ witchcraft l
  $ witchcraft l <repo>

=head1 DESCRIPTION

List entropy package, if argument provided will list the packages of that repository

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
    my $Repo = shift
        // App::witchcraft->instance->Config->param('OVERLAY_NAME');
    error "This feature is only available for Sabayon"
        and return 1
        unless distrocheck("sabayon");
    App::witchcraft->instance->emit("on_exit");
    exec("equo query list available $Repo -q");
}

1;
