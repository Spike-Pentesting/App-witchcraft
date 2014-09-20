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
use Term::ANSIColor;
use Encode;
use utf8;
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

    system("find /var/tmp/portage/ | grep build.log | xargs rm -rf")
        ;                    #spring cleaning!

#reticulating splines here...
#  push(@equo_install, &calculate_missing($_,1)) for @CMD;
# &info(scalar(@equo_install)
#      . " are not present in the system, are deps of the selected packages and it's better to install them with equo (if they are provided)");
#  my $Installs = join( " ", @equo_install );
#  &info("Installing: ");
#  &notice($_) for @equo_install;
#  system("sudo equo i -q --relaxed $Installs");

    if ( &log_command("nice -20 emerge --color n -v $args  2>&1") ) {
        &info("All went smooth, HURRAY! packages merged correctly");
        &send_report("All went smooth, HURRAY! packages merged correctly");
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
1;
