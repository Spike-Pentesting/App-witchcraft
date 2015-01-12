package App::witchcraft::Command::Upgrade;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use App::witchcraft::Utils qw(password_dialog uniq);
use App::witchcraft::Utils::Sabayon qw(list_available);
use App::witchcraft::Build;
use Locale::TextDomain 'App-witchcraft';

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
    error __('You must run it with root permissions') and return 1 if $> != 0;
    my $self = shift;
    my $Repo = shift
        // App::witchcraft->instance->Config->param('OVERLAY_NAME');
    info __x( 'Upgrade of the repository {repo}', repo => $Repo );
    my $password = password_dialog();
    info __("Retrevieng packages in the repository") if $self->{verbose};
    my @Packages = list_available( { '-q' => "" }, $Repo );
    App::witchcraft::Build->new(
        packages => @Packages,
        args     => {
            +App::witchcraft->instance->Config->param('EMERGE_UPGRADE_OPTS')
                // '-n' => ""
        }
    )->build;

    sleep 5;    #assures to propagate the messages
    return 1;
}

1;
