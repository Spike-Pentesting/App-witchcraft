package App::witchcraft::Utils::Sabayon;
use base qw(Exporter);
use App::witchcraft::Utils::Base (
    @App::witchcraft::Utils::Base::EXPORT,
    @App::witchcraft::Utils::Base::EXPORT_OK
);
our @EXPORT    = (@App::witchcraft::Utils::Base::EXPORT);
our @EXPORT_OK = (
    @App::witchcraft::Utils::Base::EXPORT_OK,
    qw(calculate_missing list_available entropy_update entropy_rescue remove_available)
);

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
    &log_command("echo -5 | equo conf update");
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
    my $rs     = 1;
    my $EDITOR = $ENV{EDITOR};
    $ENV{EDITOR} = "cat";    #quick hack

    $ENV{EDITOR} = $EDITOR and return 1 if ( @DIFFS == 0 );
    @CMD = map { s/\:\:.*//g; $_ } @CMD;
    my $args = $emerge_options . " " . join( " ", @DIFFS );

    system("find /var/tmp/portage/ | grep build.log | xargs rm -rf")
        ;                    #spring cleaning!
    &entropy_update;

#reticulating splines here...
#  push(@equo_install, &calculate_missing($_,1)) for @CMD;
# &info(scalar(@equo_install)
#      . " are not present in the system, are deps of the selected packages and it's better to install them with equo (if they are provided)");
#  my $Installs = join( " ", @equo_install );
#  &info("Installing: ");
#  &notice($_) for @equo_install;
#  system("sudo equo i -q --relaxed $Installs");

    &conf_update;    #EXPECT per DISPATCH-CONF
    if ( &log_command("nice -20 emerge --color n -v $args  2>&1") ) {
        App::witchcraft->instance->emit( after_emerge => (@DIFFS) );
        &info(    "Compressing "
                . scalar(@DIFFS)
                . " packages: "
                . join( " ", @DIFFS ) );
        &conf_update;
        ##EXPECT PER EIT ADD
        my $Expect = Expect->new;
        App::witchcraft->instance->emit( before_compressing => (@DIFFS) );

        #       unshift( @CMD, "add" );
        #     push( @CMD, "--quick" );
        # $Expect->spawn( "eit", "add", "--quick", @CMD )
        $Expect->spawn( "eit", "commit", "--quick" )
            or send_report("Eit add gives error! Cannot spawn eit: $!\n");
        $Expect->expect(
            undef,
            [   qr/missing dependencies have been found|nano|\?/i => sub {
                    my $exp = shift;
                    $exp->send("\cX");
                    $exp->send("\r");
                    $exp->send("\r\n");
                    $exp->send("\r");
                    $exp->send("\r\n");
                    $exp->send("\r");
                    $exp->send("\n");
                    exp_continue;
                },
                'eof' => sub {
                    my $exp = shift;
                    $exp->soft_close();
                    }
            ],
        );
        if ( !$Expect->exitstatus() or $Expect->exitstatus() == 0 ) {
            &conf_update;    #EXPECT per DISPATCH-CONF
            App::witchcraft->instance->emit( before_compressing => (@DIFFS) );

            if ( &log_command("eit push --quick") ) {
                &info("All went smooth, HURRAY!");
                &send_report(
                    "All went smooth, HURRAY! do an equo up to checkout the juicy stuff"
                );
                App::witchcraft->instance->emit( after_push => (@DIFFS) );
                &entropy_rescue;
                &entropy_update;
            }

        }
        else {
            my @LOGS = &find_logs();
            &send_report( "Error occured during compression phase",
                join( " ", @LOGS ) );
            $rs = 0;
        }
    }
    else {
        my @LOGS = &find_logs();
        &send_report( "Logs for " . join( " ", @DIFFS ), join( " ", @LOGS ) );
        $rs = 0;
    }

    #Maintenance stuff
    &upgrade;
    $ENV{EDITOR} = $EDITOR;    #quick hack
    return $rs;
}

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = &depgraph( $package, $depth );    #depth=0 it's all
    &info( scalar(@Packages) . " dependencies found " );
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
    &notice( "Processing " . join( " ", @DIFFS ) );
    my $cfg          = App::witchcraft->instance->Config;
    my $overlay_name = $cfg->param('OVERLAY_NAME');
    my @CMD          = @DIFFS;
    @CMD = map { s/\:\:.*//g; $_ } @CMD;
    App::witchcraft->instance->emit( before_process => (@CMD) );
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
        &send_report( "Emerge in progress for $commit", @DIFFS );
        if ( &emerge( {}, @DIFFS ) ) {
            &send_report( "<$commit> Compiled: " . join( " ", @DIFFS ) );
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
    &log_command("equo up && equo u");
}

sub entropy_rescue {
    &log_command("equo rescue spmsync");
}

1;
