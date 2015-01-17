package App::witchcraft::Plugin::Git;

use Deeme::Obj -base;
use App::witchcraft::Utils
    qw(info error notice append dialog_yes_default send_report spurt chwn uniq draw_up_line draw_down_line on emit compiled_commit);
use Cwd;
use Git::Sub;
use Git::Sub qw(diff stash);
use Locale::TextDomain 'App-witchcraft';
use App::witchcraft::Build;



sub register {
    my ( $self, $emitter ) = @_;
    my $cfg = App::witchcraft->instance->Config;
    $emitter->on(
        "index_sync" => sub {
            chdir(
                App::witchcraft->instance->Config->param('GIT_REPOSITORY') );
            eval { git::pull; };
            if ($@) {
                send_report( __ "Error pulling from remote repository", $@ );
                error($@);
            }
            else {
                notice(
                    __x("Git pull for [{repository}]",
                        repository =>
                            App::witchcraft->instance->Config->param(
                            'GIT_REPOSITORY')
                    )
                );
            }
        }
    );
    $emitter->on(
        "stage_changes" => sub {
            my ( $witchcraft, @Atoms ) = @_;
            return ( 1, undef ) if ( @Atoms == 0 );
            my $cwd    = cwd();
            my $return = 1;
            emit "index_sync";
            foreach my $atom (@Atoms) {
                eval { git::add $atom; };
                if ($@) {
                    send_report(
                        __x("Error indexing {atom} to remote repository",
                            atom => $atom
                        ),
                        $@
                    );
                    error($@);
                }
                eval {
                    git::commit -m => __x(
                        '[{atom}] automatically added/updated by witchcraft',
                        atom => $atom
                    );
                };
                if ($@) {
                    send_report(
                        __x("Error committing {atom} to remote repository",
                            atom => $atom
                        ),
                        $@
                    );
                    error($@);
                }
                else {
                    send_report(
                        __x( "Indexing: commit for {atom}", atom => $atom ) );
                }
                eval { git::push; };
                if ($@) {
                    send_report(
                        __x("Error pushin {atom} to remote repository",
                            atom => $atom
                        ),
                        $@
                    );
                    error($@);
                }
            }
            chdir($cwd);

        }
    );

    $emitter->on(
        "test_untracked" => sub {
            shift;
            my $opts = shift;
            my $cwd  = cwd();
            return if !exists $opts->{dir};
            chdir( $opts->{dir} );
            $opts->{dir} = $cwd;
            my @Untracked = git::ls_files '--others', '--exclude-standard';
            push( @Untracked, git::diff_files '--name-only' );
            info __x('No untracked file found') and return if @Untracked == 0;
            emit( "packages.untracked" => $opts, @Untracked );
        }
    );

    $emitter->on(
        "align_to" => sub {
            shift;
            my $last_commit = shift // compiled_commit();
            error(
                __('No compiled commit could be found, you must specify it') )
                and return 1
                if ( !defined $last_commit );
            info __x( 'Emerging packages from commit {commit}',
                commit => $last_commit );
            send_report(
                __x("Align start, building commit from {commit}",
                    commit => $last_commit
                )
            );
            emit( "packages.from_diff" =>
                    git::diff( $last_commit, '--name-only' ) );
        }
    );

    $emitter->on(
        "clean_untracked" => sub {
            shift;
            my $dir = shift;
            my @Installed;
            my $cwd = cwd;
            chdir($dir);
            system(
                "git ls-files --others --exclude-standard | xargs rm -rfv");
            notice( __
                    "Launch 'git stash' if you want to rid about all the modifications"
            );
            chdir($cwd);
        }
    );

    $emitter->on(
        "clean_stash" => sub {
            shift;
            my $dir = shift;
            my @Installed;
            my $cwd = cwd;
            chdir($dir);
            system("git stash");
            send_report( __x( "error happened stashing {dir}", dir => $dir ) )
                if $? != 0;
            chdir($cwd);
        }
    );

}

1;
