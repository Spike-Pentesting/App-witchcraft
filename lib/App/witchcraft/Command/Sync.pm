package App::witchcraft::Command::Sync;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils;
use warnings;
use strict;
use File::Find;
use Regexp::Common qw/URI/;
use Tie::File;
use Git::Sub;
use File::Path qw(remove_tree);

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Sync - Synchronize from a remote repository, perform changes and add new ebuilds to the local repository

=head1 SYNOPSIS

  $ witchcraft sync
  $ witchcraft s [--help] [-a|--add] [-r|--refactor] [-t|--refactortarget] [-u|--update] [-i|--install] [-r git_repository] <remote_repository>

=head1 DESCRIPTION

Euscan entropy repository packages.

=head1 ARGUMENTS

=over 4

=item C<-t|refactortarget <term>>

if given C<<term>> the substitution will search for that.

=item C<-a|--add>

It asks to add the failed installed packages to ignore list

=item C<-u|--update>

it saves new ebuilds in to the current git_repository.

=item C<-i|--install>

it runs C<ebuild <name> install> against the ebuild.

=item C<-x|--ignore-existing>

ignore existing files from rsync copy to the git overlay.

=item C<-r|--root <git_root>>

you can specify the git repository(C<-r|--root <git_root>>) directory where the modifications will be copied.

=item C<-t|--temp <temp_dir>>

allow to set a different temporary checkout directory.

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

sub options {
    (   "r|refactor=s"       => "refactor",          #Who is to refactor?
        "t|refactortarget=s" => 'refactor_target',   #Who is the substitution?
        "u|update"  => "update",    #Wanna transfer directly the new files?
        "r|root=s"  => "root",      #where is the git repository?
        "i|install" => "install",
        "t|temp=s"  => "temp",      #temp directory for the svn checkout
        "a|add"     => "ignore",
        "x|ignore-existing" => "ignore-existing"
    );
}

sub run {
    my $self      = shift;
    my @REMOTES   = shift // App::witchcraft->Config->param('REMOTE_OVERLAY');
    my $password  = password_dialog();
    my @REFACTORS = $self->{'refactor'}
        // App::witchcraft->Config->param('REFACTOR');
    my @ignores;
    my $temp = $self->{'temp'} // App::witchcraft->Config->param('CVS_TMP');
    my $refactor_target = $self->{'refactor_target'}
        // App::witchcraft->Config->param('REFACTOR_TO');
    tie @ignores, 'Tie::File', ${App::witchcraft::IGNORE} or die( error $!);
    system( "rm -rfv " . $temp . '*' );
    my $i = 0;

    foreach my $RepoUrl (@REMOTES) {
        $self->synchronize( $REFACTORS[$i], $refactor_target, $RepoUrl,
            $temp . int( rand(10000) ),
            $password, @ignores );
        $i++;
    }

    exit;
}

sub synchronize {
    my $self            = shift;
    my $refactor        = shift;
    my $refactor_target = shift;
    my $RepoUrl         = shift;
    my $temp            = shift;
    my $password        = shift;
    my @ignores         = @_;
    my $add             = $self->{'ignore'} ? 1 : 0;
    my $flatten         = join( "|", @ignores );
    my $l_r             = lc($refactor);
    my $u_r             = uc($refactor);
    my $m_r = uc( substr( $refactor, 0, 1 ) ) . substr( $refactor, 1 );
    my $l_t = lc($refactor_target);
    my $u_t = uc($refactor_target);
    my $m_t = uc( substr( $refactor_target, 0, 1 ) )
        . substr( $refactor_target, 1 );
    my @Installed;

    if ( system("git ls-remote $RepoUrl") == 0 ) {
        info 'The repository is a git one!';
        notice git::clone $RepoUrl, $temp;
    }
    else {
        info 'This is a svn repository!';
        system( "svn checkout $RepoUrl " . $temp );
    }
    finddepth(
        sub {
            my $file      = $File::Find::name;
            my $file_name = $_;

            # info "Refactor term is $refactor";
            if (   $file_name =~ /$refactor/i
                or $file =~ /$refactor/i
                or $file =~ /$flatten/i )
            {
                error $file. " removed";
                unlink($file) if ( -f $file );
                rmdir($file)  if ( -d $file );
                return;
            }

            if ( -f $file
                and $file_name =~ /\.ebuild$/ )
            {
                info "[File] analyzing $file ";

                my $new_pos = $file;

                # $new_pos =~ s/$l_r/$l_t/gi;
                # move( $file, $new_pos );
                # notice "$file moved to $new_pos";
                # unlink($file);
                open FILE, "<$new_pos";
                my @LINES = <FILE>;
                close FILE;

                for (@LINES) {
                    next
                        if (
                        m!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!
                        );
                    if (/$u_r/) {
                        $_ =~ s/$u_r/$u_t/g;
                        info "$_ -------------> $new_pos";

                    }
                    elsif (/$l_r/) {
                        $_ =~ s/$l_r/$l_t/g;
                        info "$_ -------------> $new_pos";

                    }
                    elsif (/$m_r/) {
                        $_ =~ s/$m_r/$m_t/g;
                        info "$_ -------------> $new_pos";
                    }
                }
                open FILE, ">$new_pos";
                print FILE @LINES;
                close FILE;

            }
            else {
                notice "$file ignored";
            }

        },
        $temp
    );

    #unlink( $temp . "/.svn" );
    remove_tree( $temp . '/.svn' );
    remove_tree( $temp . '/.git' );

    return if ( !$self->{update} );
    info "Copying content to git directory";
    my $dir
        = $self->{root} // App::witchcraft->Config->param('GIT_REPOSITORY');
    error 'No GIT_REPOSITORY defined, or --root given' and exit 1
        if ( !$dir );
    info $self->{'ignore-existing'}
        ? "rsync --progress --ignore-existing -avp " . $temp . "/* $dir\/"
        : "rsync --progress -avp " . $temp . "/* $dir\/";
    system( $self->{'ignore-existing'}
        ? "rsync --progress --ignore-existing -avp " . $temp . "/* $dir\/"
        : "rsync --progress -avp " . $temp . "/* $dir\/"
    );
    notice 'Cleaning';
    system( "rm -rfv " . $temp . '*' );

    return if ( !$self->{install} );
    test_untracked( $dir, $add, $password );
}

1;
