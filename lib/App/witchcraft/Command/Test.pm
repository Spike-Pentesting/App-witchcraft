package App::witchcraft::Command::Test;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils;
use warnings;
use strict;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Test - Test untracked files

=head1 SYNOPSIS

  $ witchcraft test
  $ witchcraft t <git_repository>

=head1 DESCRIPTION

Takes all the untracked ebuilds and manifest & install them

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
        = shift // -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";
    info 'Manifest & Install of the untracked files in ' . $dir;
    test_untracked( $dir, 0, password_dialog());
    exit;
}

1;
