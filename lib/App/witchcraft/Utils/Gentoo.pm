package App::witchcraft::Utils::Gentoo;
use base qw(Exporter);
our @EXPORT = ();
our @EXPORT_OK
    = qw(atom stripoverlay calculate_missing conf_update distrocheck depgraph find_logs clean_logs repo_update to_ebuild euscan);
use App::witchcraft::Utils qw(info error send_report uniq log_command);

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

#
#  name: to_ebuild
#  input:@DIFFS
#  output:@TO_EMERGE
# given an array contening atoms, finds the ebuilds in the overlay and generate an array

sub to_ebuild(@) {
    my @DIFFS = @_;
    my @TO_EMERGE;
    my $overlay = App::witchcraft->instance->Config->param('OVERLAY_PATH');
    foreach my $file (@DIFFS) {
        my @ebuild = <$overlay/$file/*>;
        foreach my $e (@ebuild) {
            push( @TO_EMERGE, $e ) if ( $e =~ /Manifest/i );
        }
    }
    return @TO_EMERGE;
}

sub repo_update {
    &log_command("eix-sync");
}

sub clean_logs {
    system("find /var/tmp/portage/ | grep build.log | xargs rm -rf")
        ;    #spring cleaning!
}

sub find_logs {
    my @FINAL;
    my @LOGS = `find /var/tmp/portage/ | grep build.log`;
    foreach my $file (@LOGS) {
        open FILE, "<$file";
        my @CONTENTS = <FILE>;
        close FILE;
        @CONTENTS = map { $_ .= "\n"; } @CONTENTS;
        unshift( @CONTENTS,
            "======================= Error log: $file ======================= "
        );
        my $C = "@CONTENTS";
        if ( $C =~ /Error|Failed/i ) {
            push( @FINAL, @CONTENTS );
        }
        unlink($file);
    }
    return @FINAL;
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

sub depgraph($$) {
    my $package = shift;
    my $depth   = shift;
    return
        map { $_ =~ s/\[.*\]|\s//g; &atom($_); $_ }
        qx/equery -C -q g --depth=$depth $package/;    #depth=0 it's all
}

sub conf_update {
    my $in        = "u\n";
    my @potential = < /etc/conf.d/..*>;
    $in .= "u\n" for @potential;
    run3( [ 'sudo', 'dispatch-conf' ], \$in );
}

1;
