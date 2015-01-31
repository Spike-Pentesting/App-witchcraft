package App::witchcraft::Command::Githook;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils qw(notice error info emit);
use warnings;
use strict;
use File::Find;
use Cwd;
use Locale::TextDomain 'App-witchcraft';


sub run {
    notice(__("Starting githook server"));
    emit("githook.server.start");
}

1;

__END__
=encoding utf-8

=head1 NAME

App::witchcraft::Command::Githook - Starts the githook server

=head1 SYNOPSIS

  $ witchcraft g

=head1 DESCRIPTION

Starts the plackup server with Github::Hooks::Receiver

=head1 DESCRIPTION

you have to explicitly set in your config file the Githook plugin and configure it (listening port and secret word). Then you can setup your github or gitlab to the url of your machine. When he receive a push it does an align (see L<App::witchcraft::Align>)

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::Witchcraft>, L<App::witchcraft::Command::Sync>, L<App::witchcraft::Command::Align>

=cut
