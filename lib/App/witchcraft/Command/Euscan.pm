package App::witchcraft::Command::Euscan;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use File::stat;
use File::Copy;

sub options {
    (   "v|verbose"  => "verbose",
        "q|quiet"    => "quiet",
        "c|check"    => "check",
        "u|update"   => "update",
        "r|root"     => "root",
        "m|manifest" => "manifest",
        "i|install"  => "install"
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
    my $dir
        = $self->{root} || -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";
    my $atom = join( '/', $dir, $Package );
    info 'repository doesn\'t have that atom (' . $atom . ')' and return
        if ( !-d $atom );
    notice 'opening ' . $atom;
    opendir( DH, $atom );
    my @files = grep {/\.ebuild$/}
        sort { -M join( '/', $atom, $a ) <=> -M join( '/', $atom, $b ) }
        grep { -f join( '/', $atom, $_ ) } readdir(DH);
    closedir(DH);
    my $pack = shift @temp;
    $pack =~ s/.*?\/(.*?)\:.*/$1/g;
    my $updated = join( '/', $atom, $pack . '.ebuild' );

    info "Searching for $pack";
    info "Update to $Package already exists" and return
        if ( -f $updated );
    return if ( $self->{check} and -f $updated );
    my $last = shift @files;
    my $source = join( '/', $atom, $last );

    notice $last. ' was chosen to be the source of the new version';
    notice $updated . " updated"
        if defined $last and copy( $source, $updated );
    return if ( !$self->{manifest} );
    use Ebuild::Sub; #lazy load
    ebuild $updated. " manifest";
    return if ( !$self->{install} );
    ebuild $updated. " install";
    ebuild $updated. " merge";
}

1;
