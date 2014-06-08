package App::witchcraft::Command::Euscan;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use File::stat;
use File::Copy;
use Git::Sub qw(add commit push);

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Euscan - Euscan entropy repository packages

=head1 SYNOPSIS

  $ witchcraft euscan
  $ witchcraft e [-v|--verbose] [-q|--quiet] [-c|--check] [-u|--update] [-m|--manifest] [-f|--force] [-g|--git] [-i|--install] [-r git_repository] <repo>

=head1 DESCRIPTION

Euscan entropy repository packages.

=head1 ARGUMENTS

=over 4

=item C<-u|--update>

it saves new ebuilds in to the current git_repository.

=item C<-f|--force>

-m and -i will have effect also on ebuilds that are marked as "to update" but already are in the repository.
This is useful when you want to re-ebuild all the new found.

=item C<-i|--install>

it runs C<ebuild <name> install> against the ebuild.

=item C<-c|--check>

only performs scan of the new packages and return the list

=item C<-m|--manifest>

it runs C<ebuild <name> manifest> against the ebuild

=item C<-g|--git>

it add the ebuild into the git index of the repository and commit with the "added ${P}"

=item C<-r|--root <REPOSITORY_DIRECTORY>>

provided perform the git changes on C<<REPOSITORY_DIRECTORY>>

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
L<App::witchcraft>, L<App::witchcraft::Command::Sync>

=cut

sub options {
    (   "v|verbose"  => "verbose",
        "q|quiet"    => "quiet",
        "c|check"    => "check",
        "u|update"   => "update",
        "r|root=s"   => "root",
        "m|manifest" => "manifest",
        "i|install"  => "install",
        "f|force"    => "force",
        "g|git"      => "git"
    );
}

sub run {
    my $self = shift;
    my $Repo = shift // "spike";
    info 'Euscan of the Sabayon repository ' . $Repo;
    my $password = password_dialog();
    info "Retrevieng packages in the repository" if $self->{verbose};
    my @Packages = `equo query list available $Repo -q`;
    chomp(@Packages);
    my @Updates;
    my @Added;
    my $c = 1;
    info "Starting Euscan of " . join( " ", @Packages ) if $self->{verbose};
    foreach my $Package (@Packages) {
        draw_up_line;
        notice "[$c/" . scalar(@Packages) . "] " . $Package;
        my @temp = `euscan -q -C $Package`;
        chomp(@temp);
        if ( !$self->{quiet} ) {
            info "** " . $_ for @temp;
        }
        push( @Updates, @temp );
        push( @Added, $self->update( $Package, $password, @temp ) )
            if ( @temp > 0 );
        $c++;
    }
    eval { notice git::push; };
    if ($@) {
        error $@;
        send_report("Error while pushing to git $@");
    }
    if ( @Updates > 0 ) {
        print $_ . "\n" for @Updates;
    }
    if ( $self->{git} ) {
        system( "echo " . $password . " | sudo -S eix-sync" )
            && system( "echo "
                . $password
                . " | sudo -S emerge -av "
                . join( " ", @Added ) )
            && system( "echo " . $password . " | sudo -S eit commit" )
            && system( "echo " . $password . " | sudo -S eit push" )
            && send_report("Successfully committed to sabayon repository");
    }
}

sub update {
    my $self     = shift;
    my $Package  = shift;
    my $password = shift;

    my @temp = @_;
    return () if ( !$self->{update} and !$self->{check} );
    my $dir
        = $self->{root} // App::witchcraft->Config->param('GIT_REPOSITORY');
    error 'No GIT_REPOSITORY defined, or --root given' and exit 1
        if ( !$dir );
    my $atom = join( '/', $dir, $Package );
    info 'repository doesn\'t have that atom (' . $atom . ')'
        and draw_down_line
        and return ()
        if ( !-d $atom );
    notice 'opening ' . $atom;
    opendir( DH, $atom );
    my @files
        = sort { -M join( '/', $atom, $a ) <=> -M join( '/', $atom, $b ) }
        grep { -f join( '/', $atom, $_ ) and /\.ebuild$/ } readdir(DH);
    closedir(DH);

    my @Temp = @temp[    #natural sort order for strings containing numbers
        map { unpack "N", substr( $_, -4 ) } #going back to normal representation
        sort
        map {
            my $key = $temp[$_];
            $key =~ s[(\d+)][ pack "N", $1 ]ge
                ;    #transforming all numbers in ascii representation
            $key . pack "CNN", 0, 0, $_
        } 0 .. $#temp
    ];
    my $pack = shift @temp;

    $pack =~ s/.*?\/(.*?)\:.*/$1/g;
    my $updated = join( '/', $atom, $pack . '.ebuild' );
    info "Searching for $pack";

    if ( !-f $updated ) {
        draw_down_line
            and return ()
            if ( $self->{check} and -f $updated );
        my $last = shift @files;
        my $source = join( '/', $atom, $last );
        notice $last . ' was chosen to be the source of the new version';
        notice $updated . " updated"
            if defined $last and copy( $source, $updated );
    }
    else {
        info "Update to $Package already exists";
        draw_down_line;
        return () if ( !$self->{force} );
    }
    draw_down_line
        and return ()
        if ( !$self->{manifest} );
    my $Test = $updated;
    $Test =~ s/$dir\/?//g;
    if (test_ebuild( $Test, $self->{manifest}, $self->{install}, $password ) )
    {
        if ( $self->{git} ) {
            chdir($atom);
            eval { notice git::add './'; };
            if ($@) {
                error $@;
            }
            else {
                info 'Added to git index of the repository';
            }
            send_report(
                "'witchcraft: automatically updated $pack to remote git repository"
            );
            eval {
                notice git::commit -m => 'witchcraft: automatically updated '
                    . $pack;
            };
            if ($@) {
                error $@;
            }
            else {
                info 'Committed with "' . 'added ' . $pack . "'";
            }
        }
    }
    else {
        return ();
    }
    draw_down_line;
    return join( "/", $Package, $pack );

}

1;
