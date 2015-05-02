package App::witchcraft::Command::Fix;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils qw(notice error info);
use warnings;
use strict;
use File::Find;
use Cwd;
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Fix - Common utils to mantain ebuilds

=head1 SYNOPSIS

  $ witchcraft f
  $ witchcraft f metagen
  $ witchcraft f ebuild_missing /path/to/dir

=head1 DESCRIPTION

Various utilities for ebuild mantain

=head1 ACTIONS

=head2 metagen

Recursive automatic metagen generation (if not found) in the packages that misses it.

=head2 digest

Recursive automatic digest generation.

=head2 ebuild_missing

Lists atoms that doesn't have an ebuild

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
    (
        "ns|nostash" => "no_stash",
        "f|force"    => "force"
    );
}
our @AVAILABLE_CMDS = qw(metagen ebuild_missing digest);

sub run {
    my ( $self, $action, $dir ) = @_;
    my $cfg = App::witchcraft->new->Config;
    error __x( "At leat one of this action must be specified: {cmds}",
        cmds => "@AVAILABLE_CMDS" )
      and return 1
      if !defined $action
      or !( grep { $_ eq $action } @AVAILABLE_CMDS );
    $dir ||= $cfg->param('GIT_REPOSITORY');
    $self->$action($dir);
}

sub metagen {
    my $self = shift;
    my $dir  = shift;
    find(
        {
            wanted => sub {
                my $file = $File::Find::name;
                return if ( !-d $file );
                return if ( $file =~ /files/ );
                return if !grep { /\.ebuild/ } <*>;
                return if !grep { /metadata/ } <*>;
                system("metagen -vm");
            }
        },
        $dir
    );
}

sub ebuild_missing {
    my $self = shift;
    my $dir  = shift;
    find(
        {
            wanted => sub {
                my $file = $File::Find::name;
                return if ( !-d $file );
                return if ( $file =~ /files/ );
                return if !grep { /Manifest/ } <*>;
                return if grep { /\.ebuild/ } <*>;
                info "$file";
            }
        },
        $dir
    );
}

sub digest {
    my $self = shift;
    my $dir  = shift;
    finddepth(
        {
            wanted => sub {
                my $file = $File::Find::name;

                return if ( !-e $file );
                return if ( $file =~ /files/ );
                return if ( $file !~ /.ebuild/ );
                system("ebuild $file digest");
            }
        },
        $dir
    );
}

1;
