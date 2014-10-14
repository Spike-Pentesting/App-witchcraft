package App::witchcraft::Plugin::Gentoo;

use Deeme::Obj -base;
use App::witchcraft::Utils
    qw(info error notice append spurt chwn log_command send_report);
use App::witchcraft::Utils::Gentoo
    qw(stripoverlay clean_logs find_logs upgrade to_ebuild);
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

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "packages.build" => sub {
            my ( undef, @Packages ) = @_;
            my $commit = pop(@Packages);
            my $on_success = pop(@Packages);

            my @DIFFS      = @Packages;
            notice( __x( "Processing {diffs}", diffs => @DIFFS ) );
            my $cfg          = App::witchcraft->instance->Config;
            my $overlay_name = $cfg->param('OVERLAY_NAME');
            my @CMD          = @DIFFS;
            @CMD = map { stripoverlay($_); $_ } @CMD;
            App::witchcraft->instance->emit(
                "packages.build.before" => ( $commit, @CMD ) );
            my @ebuilds = to_ebuild(@CMD);

            $on_success->() and return
                if ( scalar(@ebuilds) == 0 and $use == 0 );

#at this point, @DIFFS contains all the package to eit, and @TO_EMERGE, contains all the packages to ebuild.
            send_report(
                __x( "Emerge in progress for {commit}", commit => $commit ),
                @DIFFS );
            if ( _emerge( {}, @DIFFS , $commit) ) {
                send_report(
                    __x("<{commit}> Compiled: {diffs}",
                        commit => $commit,
                        diffs  => @DIFFS
                    )
                );
                App::witchcraft->instance->emit(
                    "packages.build.success" => ( $commit, @DIFFS ) );
                $on_success->();
            }

        }
    );
}

=head1 _emerge(@Atoms,$commit,$usage)

emerges the given atoms

=head2 EMITS

=head3 before_emerge => ($options)

=head3 after_emerge => (@ATOMS)

=cut

sub _emerge(@) {
    my $options = shift;

# App::witchcraft->instance->emit( "packages.build.before.emerge" => ($options) );

    my $emerge_options
        = join( " ", map { "$_ " . $options->{$_} } keys %{$options} );
    $emerge_options
        .= " " . App::witchcraft->instance->Config->param('EMERGE_OPTS')
        if App::witchcraft->instance->Config->param('EMERGE_OPTS');
    my @DIFFS = @_;
    my $commit = pop(@DIFFS);
    my @CMD   = @DIFFS;
    my @equo_install;
    my $rs     = 1;
    my $EDITOR = $ENV{EDITOR};
    $ENV{EDITOR} = "cat";    #quick hack

    $ENV{EDITOR} = $EDITOR and return 1 if ( @DIFFS == 0 );
    @CMD = map { stripoverlay($_); $_ } @CMD;
    my $args = $emerge_options . " " . join( " ", @DIFFS );
    clean_logs;
    App::witchcraft->instance->emit(
        "packages.build.before.emerge" => (@CMD,$commit) );

    if ( log_command("nice -20 emerge --color n -v $args  2>&1") ) {
        info( __ "All went smooth, HURRAY! packages merged correctly" );
        send_report( __("Packages merged successfully"), @DIFFS );
        App::witchcraft->instance->emit(
            "packages.build.after.emerge" => (@DIFFS,$commit) );
    }
    else {
        my @LOGS = find_logs();
        send_report( __x( "Logs for {diffs}", diffs => @DIFFS ),
            join( " ", @LOGS ) );
        $rs = 0;
    }

    #Maintenance stuff
    upgrade;
    $ENV{EDITOR} = $EDITOR;    #quick hack
    return $rs;
}

1;
