package App::witchcraft::Plugin::Gentoo;
use Locale::TextDomain 'App-witchcraft';

use Deeme::Obj -base;
use App::witchcraft::Utils
    qw(info error notice append spurt chwn log_command send_report upgrade on emit draw_up_line draw_down_line uniq);
use App::witchcraft::Utils::Gentoo
    qw(stripoverlay clean_logs find_logs to_ebuild atom repo_update test_ebuild);
use Cwd;
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
    my ($self,$emitter ) = @_;
    $emitter->on( "repositories.update" => sub { repo_update(); } );
    $emitter->on(
        "packages.from_diff" => sub {
            my $cfg = App::witchcraft->instance->Config;
            repo_update;
            my $cwd = cwd();
            chdir( $cfg->param('OVERLAY_PATH') );
            my @FILES = map {
                $_ =~ s/.*\K\/.*?$//g;         #Removing the last part
                atom($_);                      #converting to atom
                $_ =~ s/.*\K\/Manifest$//g;    #removing manifest
                $_
                } grep {
                /Manifest$/i    #Only with the manifest are interesting
                } @_;

            #  system("git stash");
            #my $Clean = App::witchcraft::Command::Clean->new;
            #$Clean->run;
            my @EMERGING = map { $_ . "::" . $cfg->param('OVERLAY_NAME') }
                grep { -d $_ } @FILES;
            if ( @EMERGING > 0 ) {
                notice(
                    __('These are the packages that would be processed:') );
                draw_up_line;
                info "\t* " . $_ for @EMERGING;
                draw_down_line;
            }
            else {
                notice( __("No packages to emerge") );
            }

            #process( @EMERGING, $last_commit, 0 );
            App::witchcraft::Build->new(
                packages => @EMERGING,
                id       => last_commit(
                    $cfg->param('OVERLAY_PATH'),
                    ".git/refs/heads/master"
                ),
                track_build => 1
            )->build;
            chdir($cwd);
        }
    );

    $emitter->on(
        "packages.test" => sub {
            my $self=shift;
            my $opts     = shift;
            my $c        = 1;
            my $cb       = $opts->{cb} || sub { 1; };
            my $cwd      = $opts->{dir};
            my $ignore   = $opts->{ignore} || 0;
            my $password = $opts->{password} || undef;
            my @ignores;

            my @Untracked = @_;
            my @Atoms_Installed;
            my @Installed;
            my @Failed;
            foreach my $new_pos (@Untracked) {
                info(
                    __x("[{count}/{total}] Testing {atom}",
                        count => $c,
                        total => scalar(@Untracked),
                        atom  => $new_pos
                    )
                );
                my $atom = $new_pos;

                #$atom = filetoatom($atom);
                $c++;
                my $result = test_ebuild( $new_pos, 1, 1, $password );
                $new_pos =~ s/(.*\/[\w-]*)\/.*/$1/;

                if ( $result == 1 ) {
                    push( @Atoms_Installed, $atom );
                    push( @Installed,       $new_pos );
                }
                else {
                    push( @Failed, $new_pos );
                }
            }
            if ( $ignore and $ignore == 1 and @Failed > 0 ) {
                tie @ignores, 'Tie::File', ${App::witchcraft::IGNORE}
                    or die( error $!);
                send_report(
                    __( "Witchcraft need your attention, i'm asking you few questions"
                    )
                );
                foreach my $fail (@Failed) {
                    push( @ignores, $fail )
                        if (
                        dialog_yes_default(
                            __x("Add {failed} to the ignore list?",
                                failed => $fail
                            )
                        )
                        );
                }
            }
            if ( @Installed > 0 ) {
                &info(
                    __( "Those files where correctly installed, maybe you wanna check them: "
                    )
                );
                my $result;
                notice($_) and $result .= " " . $_
                    for ( uniq(@Atoms_Installed) );
                send_report(
                    __x("These ebuilds where correctly installed: {result}",
                        result => $result
                    )
                );
                info( __("Generating the command for maintenance") );
                notice("git add $result");
                notice("eix-sync");
                notice("emerge -av $result");
                notice("eit add $result");
                notice("eit push");
                $cb->(@Installed);
            }
            else {
                info(
                    __( "No files where tested because there weren't untracked files or all packages failed to install"
                    )
                );
            }
            chdir($cwd);

        }
    );

    $emitter->on(
        "packages.untracked" => sub {
            my $self=shift;
            my $opts = shift;

            my @Untracked = grep {/\.ebuild$/} @_;
            info(
                __x("Those are the file that would be tested: {untracked}",
                    untracked => "@Untracked"
                )
            );
            clean_logs;    #spring cleaning!
            emit( "packages.test" => $opts, @Untracked );

        }
    );
    $emitter->on(
        "packages.build" => sub {
            my ( undef, @Packages ) = @_;
            my $commit     = pop(@Packages);
            my $options    = pop(@Packages);
            my $on_success = pop(@Packages);

            repo_update;
            my @DIFFS = @Packages;
            notice( __x( "Processing {diffs}", diffs => "@DIFFS" ) );
            my $cfg          = App::witchcraft->instance->Config;
            my $overlay_name = $cfg->param('OVERLAY_NAME');
            my @CMD          = @DIFFS;
            @CMD = map { stripoverlay($_); $_ } @CMD;
            emit( "packages.build.before" => ( $commit, @CMD ) );
            my @ebuilds = to_ebuild(@CMD);

#at this point, @DIFFS contains all the package to eit, and @TO_EMERGE, contains all the packages to ebuild.
            send_report(
                __x( "Emerge in progress for commit {commit}", commit => $commit ),
                @DIFFS );
            if ( _emerge( $options, @DIFFS, $commit ) ) {
                send_report(
                    __x("<{commit}> Compiled: {diffs}",
                        commit => $commit,
                        diffs  => "@DIFFS"
                    )
                );
                emit( "packages.build.success" => ( $commit, @DIFFS ) );
                $on_success->(@DIFFS) if defined $on_success;
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
    my @DIFFS  = @_;
    my $commit = pop(@DIFFS);
    my @CMD    = @DIFFS;
    my @equo_install;
    my $rs = 1;

    @CMD = map { stripoverlay($_); $_ } @CMD;
    my $args = $emerge_options . " " . join( " ", @DIFFS );
    clean_logs;
    App::witchcraft->instance->emit(
        "packages.build.before.emerge" => ( @CMD, $commit ) );

    if ( log_command("nice -20 emerge --color n -v $args  2>&1") ) {
        info( __("All went smooth, HURRAY! packages merged correctly") );
        send_report( __("Packages merged successfully"), @DIFFS );
        App::witchcraft->instance->emit(
            "packages.build.after.emerge" => ( @DIFFS, $commit ) );
    }
    else {
        my @LOGS = find_logs();
        send_report( __x( "Logs for: {diffs}", diffs => "@DIFFS" ),
            join( " ", @LOGS ) );
        $rs = 0;
    }

    #Maintenance stuff
    upgrade;
    return $rs;
}

1;
