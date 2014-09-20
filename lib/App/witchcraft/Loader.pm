package App::witchcraft::Loader;
use Deeme::Obj -base;

use File::Basename 'fileparse';
use File::Spec::Functions qw(catdir catfile splitdir);
use Carp;

my ( %BIN, %CACHE );
sub class_to_path { join '.', join( '/', split /::|'/, shift ), 'pm' }

sub load {
    my ( $self, $module ) = @_;

    # Check module name
    return 1 if !$module || $module !~ /^\w(?:[\w:']*\w)?$/;

    # Load
    return undef if $module->can('new') || eval "require $module; 1";

    # Exists
    return 1 if $@ =~ /^Can't locate \Q@{[class_to_path $module]}\E in \@INC/;

    # Real error
    return croak($@);
}

sub search {
    my ( $self, $ns ) = @_;

    my %modules;
    for my $directory (@INC) {
        next unless -d ( my $path = catdir $directory, split( /::|'/, $ns ) );

        # List "*.pm" files in directory
        opendir( my $dir, $path );
        for my $file ( grep /\.pm$/, readdir $dir ) {
            next if -d catfile splitdir($path), $file;
            $modules{ "${ns}::" . fileparse $file, qr/\.pm/ }++;
        }
    }

    return [ keys %modules ];
}

1;
