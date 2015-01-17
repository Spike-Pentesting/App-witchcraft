package App::witchcraft::Command::Test;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils qw(password_dialog stage test_untracked info error);
use warnings;
use strict;
use Locale::TextDomain 'App-witchcraft';

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
    (   "a|add"   => "ignore",
        "s|stage" => "stage"
    );
}

sub run {
    my $self = shift;
    my $add = $self->{'ignore'} ? 1 : 0;
    my $dir
        = shift // App::witchcraft->instance->Config->param('GIT_REPOSITORY');
    error __ 'No GIT_REPOSITORY defined, or --root given' and return 1
        if ( !$dir );
    info __x( 'Manifest & Install of the untracked files in {dir}',
        dir => $dir );
    test_untracked(
        { dir => $dir, ignore => $add, password => +password_dialog() } )
        and return
        if ( !$self->{stage} );
    test_untracked(
        {   dir      => $dir,
            ignore   => $add,
            password => +password_dialog(),
            callback => sub { stage(@_) }
        }
    );
    return;
}

1;
