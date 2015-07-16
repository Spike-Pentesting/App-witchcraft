package App::witchcraft::Utils::Gentoo;
use base qw(Exporter);
use App::witchcraft::Utils
    qw(info error notice send_report uniq log_command draw_down_line);

use Locale::TextDomain 'App-witchcraft';
use Term::ANSIColor;
use Encode;
use utf8;
use Carp;
use IPC::Run3;
use File::Copy;

our @EXPORT = ();
our @EXPORT_OK
    = qw(atom stripoverlay calculate_missing conf_update  depgraph find_logs clean_logs repo_update to_ebuild euscan test_ebuild bump remove_emerge_packages);

sub remove_emerge_packages {
    system("rm -rf /usr/portage/packages/*");
}

=head1 bump($atom,$newfile)

Bumps the $atom (cat/atom) to the $newfile (absolute path with PV included)

=head2 EMITS

=head3 bump => $atom,$updated

after the bump

=cut

#usage bump($atom,$PV)

sub bump {
    my $atom    = shift;
    my $updated = shift;
    notice( __x( 'opening {atom}', atom => $atom ) );
    opendir( DH, $atom )
        or ( error( __x( "Cannot open {atom}", atom => $atom ) )
        and return undef );
    my @files
        = sort { -M join( '/', $atom, $a ) <=> -M join( '/', $atom, $b ) }
        grep { -f join( '/', $atom, $_ ) and /\.ebuild$/ } readdir(DH);
    closedir(DH);
    my $last = shift @files;
    error( __x( "No ebuild could be found in {atom}", atom => $atom ) )
        and return undef
        if ( !defined $last );
    my $source = join( '/', $atom, $last );
    notice(
        __x('Using =====> {ebuild} <===== as a skeleton for the new version',
            ebuild => $last
        ) );
    notice( __("Copying") );
    send_report(
        __x("Automatic bump: {atom} -> {updated}",
            atom    => $atom,
            updated => $updated
        ) );
    info( __x( "Bumped: {updated} ", updated => $updated ) )
        and App::witchcraft->instance->emit( bump => ( $atom, $updated ) )
        and return 1
        if defined $last
        and copy( $source, $updated );
    return undef;
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

#
#  name: clean_logs
#  input: void
#  output: void
# clean portage logs

sub clean_logs {
    system("find /var/tmp/portage/ | grep build.log | xargs rm -rf")
        ;    #spring cleaning!
}

#
#  name: find_logs
#  input: void
#  output: @Logs
# search for logs and return an array containing the lines of the log

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

#  name: euscan
#  input: package
#  output:@output
# Launches euscan for the supplied package

sub euscan {
    my $Package = shift;
    my @temp    = `euscan -q -C $Package`;
    chomp(@temp);
    return @temp;
}

#  name: atom
#  input: package
#  output: package
# return the atom of a package

sub atom { s/-[0-9]{1,}.*$//; }

#  name: stripoverlay
#  input: package
#  output: package
# return the package cleaned from the ::overlay part

sub stripoverlay { s/\:\:.*//g; }

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = &depgraph( $package, $depth );    #depth=0 it's all
    info(
        __xn(
            "One dependency found",
            "{count} dependencies found ",
            scalar(@Packages),
            count => scalar(@Packages) ) );
    my @Installed_Packages = qx/EIX_LIMIT_COMPACT=0 eix -Inc -#/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    return @to_install;
}

sub depgraph {
    my $package = shift;
    my $depth   = shift // 1;
    my $atom    = shift
        // App::witchcraft->instance->Config->param("DEPGRAPH_ATOM") // 0;
    return
        map{ $_=~s/^.*\]|\s|\n//g; &atom($_) if $atom; $_ } grep{/\]/}
        qx/emerge -poq --color n $package/;    #depth=0 it's all
}

sub conf_update {
    my $in        = "u\n";
    my @potential = < /etc/conf.d/..*>;
    $in .= "u\n" for @potential;
    run3( [ 'sudo', 'dispatch-conf' ], \$in );
}

sub test_ebuild {

    #XXX: to add repoman scan here
    my $ebuild   = shift;
    my $manifest = shift || undef;
    my $install  = shift || undef;
    my $password = shift || undef;
    if ( $> != 0 ) {
        $password = $password ? "echo $password | sudo -S " : "sudo";
    }
    else {
        $password = "";
    }
    system( $password. " ebuild $ebuild clean" )
        ;    #Cleaning before! at least it fails :P
    if ( defined $manifest and system("ebuild $ebuild manifest") == 0 ) {
        info( __('Manifest created successfully') );
        clean_logs;
        draw_down_line
            and return 1
            if ( defined $manifest and !defined $install );
        info(
            __x( "Starting installation for {ebuild}", ebuild => $ebuild ) );
        $ebuild =~ s/\.ebuild//;
        my @package = split( /\//, $ebuild );
        $ebuild = $package[0] . "/" . $package[2];
        my $specific_ebuild = "=" . $ebuild;
        system(   $password
                . " PORTDIR_OVERLAY='"
                . App::witchcraft->instance->Config->param('GIT_REPOSITORY')
                . "' emerge --onlydeps $specific_ebuild" )
            if ( defined $install );
        App::witchcraft->instance->emit( before_test => ($ebuild) );

        if (defined $install
            and system( $password
                    . " PORTDIR_OVERLAY='"
                    . App::witchcraft->instance->Config->param(
                    'GIT_REPOSITORY')
                    . "' emerge -B  --nodeps $specific_ebuild"
            ) == 0
            )
        {
            App::witchcraft->instance->emit( after_test => ($ebuild) );
            info( __x( '[{ebuild}] Installation OK', ebuild => $ebuild ) );
            return 1;
        }
        else {
            send_report(
                __x("Emerge failed for {ebuild}",
                    ebuild => $specific_ebuild
                ),
                __x("Emerge failed for {ebuild}",
                    ebuild => $specific_ebuild
                ),
                join( " ", find_logs() ) )
                if App::witchcraft->instance->Config->param(
                "REPORT_TEST_FAILS")
                and
                App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
                == 1;
            error( __("Installation failed") ) and return 0;
        }
    }
    else {
        send_report(
            __x("Manifest phase failed for {ebuild} ... be more carefully next time!",
                ebuild => $ebuild
            ) )
            if App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
            and App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
            == 1;
        error( __("Manifest failed") ) and return 0;
    }
}

1;
