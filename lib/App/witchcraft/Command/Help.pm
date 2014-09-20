package App::witchcraft::Command::Help;
use base 'App::CLI::Command::Help';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Help - Helper, print POD of the given command

=head1 SYNOPSIS

  $ witchcraft help # lists all commands
  $ witchcraft help <command> #print POD of the command

=head1 DESCRIPTION

Helper: if an argument is given it prints his POD else it prints all the avaible commands

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::witchcraft>, L<App::witchcraft::Command::Sync>

=cut

1;