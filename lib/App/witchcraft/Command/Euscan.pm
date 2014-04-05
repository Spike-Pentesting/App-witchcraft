package App::witchcraft::Command::Euscan;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use File::stat;
use File::Copy;
use Git::Sub qw(add commit);

sub options {
    (   "v|verbose"  => "verbose",
        "q|quiet"    => "quiet",
        "c|check"    => "check",
        "u|update"   => "update",
        "r|root"     => "root",
        "m|manifest" => "manifest",
        "i|install"  => "install",
        "g|git"      => "git"
    );
}

sub run {
    my $self     = shift;
    my $Repo     = shift // "spike";
    my @Packages = `equo query list available $Repo -q`;
    chomp(@Packages);
    my @Updates;
    foreach my $Package (@Packages) {
        notice $Package if $self->{verbose};
        my @temp = `euscan -q -C $Package`;
        chomp(@temp);
        if ( !$self->{quiet} ) {
            info "\t" . $_, for @temp;
        }
        push( @Updates, @temp );
        $self->update( $Package, @temp ) if ( @temp > 0 );
    }
    if ( @Updates > 0 ) {
        print $_ . "\n" for @Updates;
    }

}

sub update {
    my $self    = shift;
    my $Package = shift;
    my @temp    = @_;
    return if ( !$self->{update} and !$self->{check} );
    error "\n";
    error "|===================================================\\";
    my $dir
        = $self->{root} || -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";
    my $atom = join( '/', $dir, $Package );
    info '|| - repository doesn\'t have that atom (' . $atom . ')' and return
        if ( !-d $atom );
    notice '|| - opening ' . $atom;
    opendir( DH, $atom );
    my @files = grep {/\.ebuild$/}
        sort { -M join( '/', $atom, $a ) <=> -M join( '/', $atom, $b ) }
        grep { -f join( '/', $atom, $_ ) } readdir(DH);
    closedir(DH);
    my $pack = shift @temp;
    $pack =~ s/.*?\/(.*?)\:.*/$1/g;
    my $updated = join( '/', $atom, $pack . '.ebuild' );
    info "|| - Searching for $pack";

    if ( !-f $updated ) {
        return if ( $self->{check} and -f $updated );
        my $last = shift @files;
        my $source = join( '/', $atom, $last );
        notice "|| - ".$last. ' was chosen to be the source of the new version';
        notice "|| - ".$updated . " updated"
            if defined $last and copy( $source, $updated );
    }
    else {
        info "|| - Update to $Package already exists";
    }
    return if ( !$self->{manifest} );
    if ( system("ebuild $updated manifest") == 0 ) {
        notice '|| - Manifest created successfully';
        return if ( !$self->{install} );
        if ( system("ebuild $updated install") == 0 ) {
            info '|| - Installation OK';
            if ( system("sudo ebuild $updated merge") == 0 ) {
                notice "|| - ".$updated. " merged";
                chdir($atom);
                git::add './' and info '|| - Added to git index of the repository'
                    if ( $self->{git} );
                git::commit -m => 'added ' . $pack
                    and info '|| - Committed with "' . 'added ' . $pack . "'"
                    if ( $self->{git} );
            }
        }
    }
    error "||\n";
    error "|===================================================/";
}

1;
