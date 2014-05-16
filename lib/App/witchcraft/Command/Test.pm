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
  $ witchcraft t  --add <git_repository>

=head1 DESCRIPTION

Takes all the untracked ebuilds and manifest & install them, with the --add flag you will be prompted for failed tests to be added in the ignore list

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
    ( "a|add" => "ignore" );
}

sub run {
    my $self = shift;
    my $add = $self->{'ignore'} ? 1 : 0;
    my $dir
        = shift // -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";
    info 'Manifest & Install of the untracked files in ' . $dir;
    test_untracked( $dir, $add, password_dialog() );
    exit;
}

1;
