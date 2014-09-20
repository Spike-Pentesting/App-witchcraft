package App::witchcraft::Utils::Gentoo;
use base qw(Exporter);
use App::witchcraft::Utils::Base (
    @App::witchcraft::Utils::Base::EXPORT,
    @App::witchcraft::Utils::Base::EXPORT_OK
);
our @EXPORT = (@App::witchcraft::Utils::Base::EXPORT);
our @EXPORT_OK
    = ( @App::witchcraft::Utils::Base::EXPORT_OK, qw(calculate_missing) );
use Expect;

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

sub conf_update {
    my $Expect = Expect->new;
    $Expect->raw_pty(1);
    $Expect->spawn("sudo dispatch-conf")
        or send_report(
        "error executing equo conf update",
        "Cannot spawn equo conf update: $!\n"
        );

    $Expect->send("u\n");
    my @potential = < /etc/conf.d/..*>;
    $Expect->send("u\n") for @potential;
    $Expect->soft_close();
}

1;
