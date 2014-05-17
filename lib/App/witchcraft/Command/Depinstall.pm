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

=head1 DESCRIPTION

Install all the listed depedencies of a package using equo

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
    my $self    = shift;
    my $package = shift;
    error "You must supply a package" and exit 1 if ( !$package );
    info 'Installing all dependencies for ' . $package . ' using equo';
    my $password = password_dialog;
    my @Packages = map { $_ =~ s/\[.*\]|\s//g; atom($_); $_ }
        qx/equery -C -q g --depth=1 $package/; #depth=0 it's all
    my @Installed_Packages = qx/equo q -q list installed/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    my $Installs = join(" ",@to_install);
    info "Installing $Installs";
    system("echo $password | sudo -S equo i -q $Installs");
#    info "Installing $_" and system("echo $password | sudo -S equo i -q $_")
#      for @to_install;
    exit;
}
