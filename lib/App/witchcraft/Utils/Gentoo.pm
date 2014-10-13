package App::witchcraft::Utils::Gentoo;
use base qw(Exporter);
use App::witchcraft::Utils::Base (
    @App::witchcraft::Utils::Base::EXPORT,
    @App::witchcraft::Utils::Base::EXPORT_OK
);
our @EXPORT = ();
our @EXPORT_OK
    = qw(euscan atom stripoverlay calculate_missing conf_update distrocheck);
use Locale::TextDomain 'App-witchcraft';
use Term::ANSIColor;
use Encode;
use utf8;
use Carp;
use IPC::Run3;

sub distrocheck {
    return App::witchcraft->instance->Config->param("DISTRO") =~ /gentoo/i
        ? 1
        : 0;
}

sub euscan {
    my $Package = shift;
    my @temp    = `euscan -q -C $Package`;
    chomp(@temp);
    return @temp;
}

sub atom { s/-[0-9]{1,}.*$//; }

sub stripoverlay { s/\:\:.*//g; }

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = &depgraph( $package, $depth );    #depth=0 it's all
    &info(
        __xn(
            "One dependency found",
            "{count} dependencies found ",
            scalar(@Packages),
            count => scalar(@Packages)
        )
    );
    my @Installed_Packages = qx/EIX_LIMIT_COMPACT=0 eix -Inc -#/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    return @to_install;
}

sub conf_update {
    my $in        = "u\n";
    my @potential = < /etc/conf.d/..*>;
    $in .= "u\n" for @potential;
    run3( [ 'sudo', 'dispatch-conf' ], \$in );
}

1;
