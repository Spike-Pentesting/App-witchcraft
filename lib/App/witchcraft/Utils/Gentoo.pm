package App::witchcraft::Utils::Gentoo;
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

#here functs can be overloaded.
sub info {
    my @msg = @_;
    print STDERR color 'bold green';
    print STDERR encode_utf8('>> ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

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
    my $in        = "u\n";
    my @potential = < /etc/conf.d/..*>;
    $in .= "u\n" for @potential;
    run3( [ 'sudo', 'dispatch-conf' ], \$in );
}

=head1 emerge(@Atoms,$commit,$usage)

emerges the given atoms

=head2 EMITS

=head3 before_emerge => ($options)

=head3 after_emerge => (@ATOMS)

=cut

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
    &clean_logs;
    if ( &log_command("nice -20 emerge --color n -v $args  2>&1") ) {
        &info("All went smooth, HURRAY! packages merged correctly");
        &send_report( "Packages merged successfully", @DIFFS );
        App::witchcraft->instance->emit( after_emerge => (@DIFFS) );
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
        &send_report( "Emerge in progress for $commit", @DIFFS );
        if ( &emerge( {}, @DIFFS ) ) {
            &send_report( "<$commit> Compiled: " . join( " ", @DIFFS ) );
            App::witchcraft->instance->emit( after_process => ($commit,@DIFFS) );
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
    croak
        "list_available is not implemented by App::witchcraft::Utils::Gentoo class";
}

sub remove_available(@) {
    croak
        "remove_available is not implemented by App::witchcraft::Utils::Gentoo class";
}

sub entropy_update {
    croak
        "entropy_update is not implemented by App::witchcraft::Utils::Gentoo class";
}

sub entropy_rescue {
    croak
        "entropy_rescue is not implemented by App::witchcraft::Utils::Gentoo class";
}

1;
