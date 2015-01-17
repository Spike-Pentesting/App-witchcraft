package App::witchcraft::Utils::Sabayon;
use base qw(Exporter);
our @EXPORT = ();
our @EXPORT_OK
    = qw(calculate_missing conf_update  list_available remove_available entropy_rescue entropy_update);
use Locale::TextDomain 'App-witchcraft';
use constant DEBUG => $ENV{DEBUG} || 0;
use IPC::Run3;
use App::witchcraft::Utils  qw(info error notice uniq send_report save_compiled_packages save_compiled_commit log_command upgrade);
use App::witchcraft::Utils::Gentoo  qw(clean_logs find_logs depgraph);

#here functs can be overloaded.

=head1 emerge(@Atoms,$commit,$usage)

emerges the given atoms

=head2 EMITS

=head3 before_emerge => ($options)

=head3 after_emerge => (@ATOMS)

=head3 before_compressing => (@ATOMS)

=head3 after_compressing => (@ATOMS)

=head3 after_push => (@ATOMS)

=cut

sub conf_update {
    log_command("echo -5 | equo conf update");
}

sub emerge(@) {
    my $options = shift;
    App::witchcraft->instance->emit( before_emerge => ($options) );
    my $emerge_options
        = join( " ", map { "$_ " . $options->{$_} } keys %{$options} );
    $emerge_options
        .= " " . App::witchcraft->instance->Config->param('EMERGE_OPTS')
        if App::witchcraft->instance->Config->param('EMERGE_OPTS');
    my @DIFFS = @_;
    my @CMD   = @DIFFS;
    my @equo_install;
    my $rs = 0;
    local $ENV{EDITOR} = "cat";    #quick hack
    @CMD = map { &stripoverlay($_); $_ } @CMD;
    my $args = $emerge_options . " " . join( " ", @DIFFS );
    clean_logs;
    entropy_update;

    if (    App::witchcraft->instance->Config->param('EQUO_DEPINSTALL')
        and App::witchcraft->instance->Config->param('EQUO_DEPINSTALL') == 1 )
    {
        #reticulating splines here...
        push( @equo_install, calculate_missing( $_, 1 ) ) for @CMD;
        info(
            __xn(
                "One dependency of the package is not present in the system, installing them with equo",
                "{count} dependencies of the package are not present in the system, installing them with equo",
                scalar(@equo_install),
                count => scalar(@equo_install)
            )
        );
        my $Installs = join( " ", @equo_install );
        info( __ "Installing: " );
        notice($_) for @equo_install;
        system("sudo equo i -q --relaxed $Installs");
    }

    conf_update;    #EXPECT per DISPATCH-CONF
    if ( log_command("nice -20 emerge --color n -v $args  2>&1") ) {
        App::witchcraft->instance->emit( after_emerge => (@DIFFS) );
        info(
            __x("Compressing {count} packages: {packages}",
                count    => scalar(@DIFFS),
                packages => "@DIFFS"
            )
        );
        conf_update;
        App::witchcraft->instance->emit( before_compressing => (@DIFFS) );

        #       unshift( @CMD, "add" );
        #     push( @CMD, "--quick" );
        # $Expect->spawn( "eit", "add", "--quick", @CMD )
        #$Expect->spawn( "eit", "commit", "--quick",";echo ____END____" )
        #   or send_report("Cannot spawn eit: $!\n");
        sleep 1;
        send_report( __("Compressing packages"), @DIFFS );

        my ( $out, $err );
        run3(
            [ 'eit', 'commit', '--quick' ],
            \"Si\n\nYes\n\nSi\n\nYes\n\nSi\r\nYes\r\nSi\r\nYes\r\n",
            \$out, \$err
        );

        if ( $? == 0 ) {
            conf_update;    #EXPECT per DISPATCH-CONF
            App::witchcraft->instance->emit( before_compressing => (@DIFFS) );

            if ( log_command("eit push --quick") ) {
                info( __("All went smooth, HURRAY!") );
                send_report(
                    __( "All went smooth, HURRAY! do an equo up to checkout the juicy stuff"
                    )
                );
                App::witchcraft->instance->emit( after_push => (@DIFFS) );
                $rs = 1;
                entropy_rescue;
                entropy_update;
            }
        }
        else {
            send_report(
                __( "Error in compression phase, you have to manually solve it"
                ),
                $out, $err
            );
        }
    }
    else {
        my @LOGS = find_logs();
        send_report( __x( "Logs for {diffs} ", diffs => "@DIFFS" ),
            join( " ", @LOGS ) );
    }

    #Maintenance stuff
    upgrade;
    return $rs;
}

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = depgraph( $package, $depth );    #depth=0 it's all
    info(
        __x("{package}: has {deps} dependencies ",
            package => $package,
            deps    => scalar(@Packages)
        )
    );
    my @Installed_Packages = qx/equo q -q list installed/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    return @to_install;
}
#
#  name: process
#  input: @DIFFS
#  output: void
# from an array of atoms ("category/atom","category/atom2")
# it generates then a list that would be emerged and then added to the repo, each error would be reported

=head1 process(@Atoms,$commit,$usage)

Processes the atoms, can also be given in net-im/something::overlay type

=head2 EMITS

=head3 before_process => (@ATOMS)

=head3 after_process => (@ATOMS)

=cut

sub process(@) {
    my $use    = pop(@_);
    my $commit = pop(@_);
    my @DIFFS  = @_;
    &notice( __x( "Processing {diffs}", diffs => "@DIFFS" ) );
    my $cfg          = App::witchcraft->instance->Config;
    my $overlay_name = $cfg->param('OVERLAY_NAME');
    my @CMD          = @DIFFS;
    @CMD = map { &stripoverlay($_); $_ } @CMD;
    App::witchcraft->instance->emit( before_process => ( $commit, @CMD ) );
    my @ebuilds = &to_ebuild(@CMD);

    if ( scalar(@ebuilds) == 0 and $use == 0 ) {
        if ( $use == 0 ) {
            &save_compiled_commit($commit);
        }
        elsif ( $use == 1 ) {
            &save_compiled_packages($commit);
        }
    }
    else {
#at this point, @DIFFS contains all the package to eit, and @TO_EMERGE, contains all the packages to ebuild.
        &send_report(
            __x( "Emerge in progress for {commit}", commit => $commit ),
            @DIFFS );
        if ( &emerge( {}, @DIFFS ) ) {
            &send_report(
                __x("<{commit}> Compiled: {diffs}",
                    commit => $commit,
                    diffs  => "@DIFFS"
                )
            );
            App::witchcraft->instance->emit( after_process => (@DIFFS) );
            if ( $use == 0 ) {
                &save_compiled_commit($commit);
            }
            elsif ( $use == 1 ) {
                &save_compiled_packages($commit);
            }
        }
    }
}

sub list_available {
    my $options = shift;
    my $equo_options
        = join( " ", map { "$_ " . $options->{$_} } keys %{$options} );
    my @r;
    push( @r, &uniq(`equo query list available $_ $equo_options`) ) for @_;
    chomp @r;
    return @r;
}

sub remove_available(@) {
    my @Packages  = shift;
    my @Available = `equo q list -q available sabayonlinux.org`;
    chomp(@Available);
    my %available = map { $_ => 1 } @Available;
    return grep( !defined $available{$_}, @Packages );
}

sub entropy_update {
    log_command("equo up && equo u");
}

sub entropy_rescue {
    log_command("equo rescue spmsync");
}

1;
