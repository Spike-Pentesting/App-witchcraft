package App::witchcraft::Utils::Gentoo;
use base qw(Exporter);
use  App::witchcraft::Utils::Base (@App::witchcraft::Utils::Base::EXPORT,@App::witchcraft::Utils::Base::EXPORT_OK);
our @EXPORT = (@App::witchcraft::Utils::Base::EXPORT);
our @EXPORT_OK =  (@App::witchcraft::Utils::Base::EXPORT_OK,qw(calculate_missing));
#here functs can be overloaded.

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = &depgraph( $package, $depth );    #depth=0 it's all
    &info( scalar(@Packages) . " dependencies found " );
    my @Installed_Packages = qx/EIX_LIMIT_COMPACT=0 eix -Inc -#/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    return @to_install;
}


1;
