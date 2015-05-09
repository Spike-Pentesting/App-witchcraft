package App::witchcraft::Command::Clean;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils qw(clean_untracked clean_stash error info);
use warnings;
use strict;
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Clean - Clean the repository from untracked files

=head1 SYNOPSIS

  $ witchcraft c
  $ witchcraft c <git_repository> (--nostash)

=head1 DESCRIPTION

Clean the repository from untracked files.
If an argument is supplied it clean that git repository.

=head1 OPTIONS

=head2 --nostash

Avoid to C<git stash> inside the directory of the repository.

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
    ( "ns|nostash" => "no_stash" );
}

sub run {
    my $self = shift;
    my $dir  = shift
        // App::witchcraft->instance->Config->param('GIT_REPOSITORY');
    error __ 'No GIT_REPOSITORY defined, or --root given' and return 1
        if ( !$dir );
    info __x( 'Cleaning all the untracked files in {dir}', dir => $dir );
    clean_untracked($dir);
    clean_stash($dir) unless ( $self->{no_stash} );
}

1;
