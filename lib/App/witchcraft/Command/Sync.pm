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
  $ witchcraft s [--help] [-e|--eit] [-a|--add] [-r|--refactor] [-t|--refactortarget] [-u|--update] [-i|--install] [-r git_repository] [-g|--git] <remote_repository>

=head1 DESCRIPTION

Euscan entropy repository packages.

=head1 ARGUMENTS

=over 4

=item C<-t|refactortarget <term>>

if given C<<term>> the substitution will search for that.

=item C<-a|--add>

It asks to add the failed installed packages to ignore list

=item C<-g|--git>

Automatic add, push to git  repository

=item C<-e|--eit>

Automatic add, push to the entropy repository

=item C<-u|--update>

it saves new ebuilds in to the current git_repository.

=item C<-i|--install>

it runs C<ebuild <name> install> against the ebuild.

=item C<-x|--ignore-existing>

ignore existing files from rsync copy to the git overlay.

=item C<-r|--root <git_root>>

you can specify the git repository(C<-r|--root <git_root>>) directory where the modifications will be copied.

=item C<-t|--temp <temp_dir>>

allow to set a different temporary checkout directory

=item C<-v|--verbose>

Be more verbose.

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
        "x|ignore-existing" => "ignore-existing",
        "g|git"             => "git",
        "e|eit"             => "eit",
        "v|verbose"         => "verbose"
    );
}

sub run {
    my $self = shift;
    my @REMOTES = shift // App::witchcraft->Config->param('REMOTE_OVERLAY');
    info "Syncing with remote repository and merging into one!";
    my $password  = password_dialog();
    my @REFACTORS = $self->{'refactor'}
        // App::witchcraft->Config->param('REFACTOR');
    my @ignores;
    my $temp = $self->{'temp'} // App::witchcraft->Config->param('CVS_TMP');
    my $refactor_target = $self->{'refactor_target'}
        // App::witchcraft->Config->param('REFACTOR_TO');
    git_sync;
    tie @ignores, 'Tie::File', ${App::witchcraft::IGNORE} or die( error $!);
    system( "rm -rf " . $temp . '*' );
    my $i = 0;
    draw_up_line;

    foreach my $RepoUrl (@REMOTES) {
        $self->synchronize( $REFACTORS[$i], $refactor_target, $RepoUrl,
            $temp . int( rand(10000) ),
            $password, @ignores );
        $i++;
    }
    draw_down_line;
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
    chomp(@ignores);
    my $flatten
        = join( "|", map { $_ = quotemeta($_); $_ = qr/$_/; $_ } @ignores );
    my $l_r = lc($refactor);
    my $u_r = uc($refactor);
    my $m_r = uc( substr( $refactor, 0, 1 ) ) . substr( $refactor, 1 );
    my $l_t = lc($refactor_target);
    my $u_t = uc($refactor_target);
    my $m_t = uc( substr( $refactor_target, 0, 1 ) )
        . substr( $refactor_target, 1 );
    my @Installed;
    info "Refactoring: $refactor" if $self->{verbose};
    info "Ignores: $flatten"      if $self->{verbose};
    sleep 2;

    if ( system("git ls-remote $RepoUrl") == 0 ) {
        info $RepoUrl. ' is a git one!' if $self->{verbose};
        git::clone $RepoUrl, $temp;
    }
    else {
        info $RepoUrl. ' is a svn one!' if $self->{verbose};
        system( "svn checkout -q $RepoUrl " . $temp );
    }
    info "Starting the refactoring/selection process" if $self->{verbose};
    finddepth(
        sub {
            my $file      = $File::Find::name;
            my $file_name = $_;
            if (   $file_name =~ /$refactor/i
                or $file =~ /$refactor/i
                or ( @ignores > 0 and $file =~ /$flatten/i ) )
            {
                unlink($file)             if ( -f $file );
                rmdir($file)              if ( -d $file );
                error "Removed: " . $file if $self->{verbose};
                return;
            }

            if ( -f $file
                and $file_name =~ /\.ebuild$/ )
            {
                info "[File] analyzing $file " if $self->{verbose};

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
                        info "$_ -------------> $new_pos" if $self->{verbose};

                    }
                    elsif (/$l_r/) {
                        $_ =~ s/$l_r/$l_t/g;
                        info "$_ -------------> $new_pos" if $self->{verbose};

                    }
                    elsif (/$m_r/) {
                        $_ =~ s/$m_r/$m_t/g;
                        info "$_ -------------> $new_pos" if $self->{verbose};
                    }
                }
                open FILE, ">$new_pos";
                print FILE @LINES;
                close FILE;

            }
            elsif ( $self->{verbose} ) {
                notice "$file ignored";
            }

        },
        $temp
    );

    #unlink( $temp . "/.svn" );
    remove_tree( $temp . '/.svn' );
    remove_tree( $temp . '/.git' );

    return if ( !$self->{update} );
    info "Copying content to git directory" if $self->{verbose};
    my $dir
        = $self->{root} // App::witchcraft->Config->param('GIT_REPOSITORY');
    error 'No GIT_REPOSITORY defined, or --root given' and exit 1
        if ( !$dir );

    #   info $self->{'ignore-existing'}
    #      ? "rsync --progress --ignore-existing -avp " . $temp . "/* $dir\/"
    #     : "rsync --progress --update -avp " . $temp . "/* $dir\/";
    system( $self->{'ignore-existing'}
        ? "rsync --progress --ignore-existing -avp " . $temp . "/* $dir\/"
        : "rsync --progress --update -avp " . $temp . "/* $dir\/"
    );
    notice 'Cleaning' . $temp . '*' if $self->{verbose};
    system( "rm -rfv " . $temp . '*' );

    return if ( !$self->{install} );
    @Installed = test_untracked( $dir, $add, $password );
    return if ( !$self->{git} );
    git_index(@Installed);
    return if ( !$self->{eit} );
    emerge(
        { '-n' => '' },
        map { $_ . "::" . App::witchcraft->Config->param('OVERLAY_NAME') }
            @Installed
    );

}

1;
