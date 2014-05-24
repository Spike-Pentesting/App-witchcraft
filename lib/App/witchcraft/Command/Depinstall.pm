package App::witchcraft::Command::Depinstall;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils;
use warnings;
use strict;

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
    error "You must supply a package" and exit 1 if ( !$package );
    error 'You must run it with root permissions' and exit 1 if $> != 0;

    info 'Installing all dependencies for '
        . $package
        . ' with depth '
        . $depth
        . ' using equo';
    info 'Retrieving dependencies';
    my @to_install = calculate_missing($package,$depth);
    info scalar(@to_install)
        . " are not present in the systems and needs to be installed ";
    my $Installs = join( " ", @to_install );
    info "Installing: ";
    notice $_. "\t" for @to_install;
    exec("sudo equo i -q $Installs");

 #    info "Installing $_" and system("echo $password | sudo -S equo i -q $_")
 #      for @to_install;
    exit;
}
