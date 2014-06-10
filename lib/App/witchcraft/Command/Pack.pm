package App::witchcraft::Command::Pack;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils
    qw(error info notice draw_down_line draw_up_line  emerge);
use warnings;
use strict;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Align - Automatic compile from a commit

=head1 SYNOPSIS

  $ witchcraft process [package] [package2]...

=head1 DESCRIPTION

Automatic compile packages and push to the repository

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
    my $self     = shift;
    my @EMERGING = @_;
    info 'Emerging & Pushing ' . scalar(@EMERGING) . ' packages';
    my $cfg = App::witchcraft->Config;
    system("eix-sync");
    notice 'Those are the packages that would be processed:';
    draw_up_line;
    info "\t" . $_ for @EMERGING;
    draw_down_line;
    emerge({},@EMERGING);
}

1;

