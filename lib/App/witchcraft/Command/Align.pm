package App::witchcraft::Command::Align;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils qw(error emit);
use App::witchcraft::Command::Clean;
use warnings;
use strict;
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Align - Automatic compile from a commit

=head1 SYNOPSIS

  $ witchcraft align [commit]
  $ witchcraft a

=head1 DESCRIPTION

Automatic compile from a commit or the last automatic compiled

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
    error( __('You must run it with root permissions') ) and return 1
        if $> != 0;
    my $self        = shift;
    my $last_commit = shift;
    emit( "align_to" => $last_commit );
}

1;

