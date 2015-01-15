package App::witchcraft::Command::Conflict;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils
    qw(send_report error info notice uniq log_command);
use App::witchcraft::Utils::Sabayon
    qw(list_available);
use warnings;
use strict;
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Conflict - Resolve repository conflict

=head1 SYNOPSIS

  $ witchcraft conflict
  $ witchcraft r

=head1 DESCRIPTION

Clean the sabayon repository from upstream conflicts

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

sub options {
    ( "d|delete" => "delete" );
}

sub run {
    my $self = shift;
    error __ 'You must run it with root permissions' and return 1 if $> != 0;
    my $overlay = shift
        // App::witchcraft->instance->Config->param('OVERLAY_NAME');
    error __('No OVERLAY_NAME defined') and return 1 if ( !$overlay );
    info __(
        'Calculating packages that are already in other sabayon repositories ');
    my @repos = qx|equo repo list -q|;
    chomp(@repos);
    @repos = grep { !/$overlay/ } @repos;
    info __x( "Searching packages in the following repositories: {repos}",
        repos => "@repos" );
    my @other_repos_packages
        = list_available( { "-q" => "", "-v" => "" }, @repos );
    info __x( "retrieving packages in the {overlay} repository",
        overlay => $overlay );
    my @repo_packages = list_available( { "-q" => "", "-v" => "" }, $overlay )
        ;    #also compare versions
    my %packs = map { $_ => 1 } @other_repos_packages;
    my @to_remove = uniq( grep( defined $packs{$_}, @repo_packages ) );
    info __ "Those are the packages that are already in other repository: ";
    notice "\t$_" for @to_remove;
    return if !$self->{delete};
    send_report( __ "[Conflict] Removing those packages ", @to_remove )
        if @to_remove > 0;
    log_command("eit remove --quick --nodeps --from $overlay $_ ")
        for @to_remove;
}

1;

