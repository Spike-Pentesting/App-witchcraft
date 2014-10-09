package App::witchcraft::Command::Depinstall;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils qw(calculate_missing info log_command distrocheck
    error notice);
use warnings;
use strict;
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Depinstall - Install a package dependencies using equo

=head1 SYNOPSIS

  $ witchcraft d <package>
  $ witchcraft d --depth 0 <package>

=head1 DESCRIPTION

Install all the listed depedencies of a package using equo

=head1 OPTIONS

-d or --depth <i> define the deepness of the dependency tree

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
    ( "d|depth=s" => "depth" );
}

sub run {
    my $self    = shift;
    my $package = shift;
    my $depth   = $self->{depth} // 1;
    error __ "You must supply a package" and return 1 if ( !$package );
    error __ 'You must run it with root permissions' and return 1 if $> != 0;
    error __ "This feature is only available for Sabayon"
        and return 1
        unless distrocheck("sabayon");

    info __x(
        'Installing all dependencies for {package} with depth {depth} using equo',
        package => $package,
        depth   => $depth
    );
    info __ 'Retrieving dependencies';
    my @to_install = calculate_missing( $package, $depth );
    info __nx(
        "One package isn't present in the system and needs to be installed",
        "{count} packages aren't present in the system and needs to be installed",
        scalar(@to_install),
        count => scalar(@to_install)
    );
    info __ "Installing" . " :";
    notice $_. "\t" for @to_install;
    log_command( "sudo equo i -q " . join( " ", @to_install ) );
}

1;
