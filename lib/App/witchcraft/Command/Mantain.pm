package App::witchcraft::Command::Mantain;

use base qw(App::witchcraft::Command);
use Carp::Always;
use warnings;
use strict;
use App::witchcraft::Utils;
use App::witchcraft::Command::Align;
use App::witchcraft::Command::Sync;
use App::witchcraft::Command::Upgrade;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Mantain - Automatic mantainance command

=head1 SYNOPSIS

  $ witchcraft mantain

=head1 DESCRIPTION

Automatic mantainance command: it executes align, sync and upgrade

=head1 ARGUMENTS

=over 4

=item C<--help>

it prints the POD help.

=back

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<App::witchcraft>, L<App::witchcraft::Command::Euscan>

=cut

sub run {
    error 'You must run it with root permissions' and exit 1 if $> != 0;
    my $self    = shift;
    my $Align   = App::witchcraft::Command::Align->new;
    my $Sync    = App::witchcraft::Command::Sync->new;
    my $Upgrade = App::witchcraft::Command::Upgrade->new;
    $Sync->{'install'}         = 1;
    $Sync->{'update'}          = 1;
    $Sync->{'ignore-existing'} = 1;
    $Sync->{'git'}             = 1;
    $Align->run();
    $Sync->run();
    $Upgrade->run();
}

1;

