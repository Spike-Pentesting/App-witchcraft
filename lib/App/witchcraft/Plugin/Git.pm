package App::witchcraft::Plugin::Git;

use Deeme::Obj -base;
use App::witchcraft::Utils
    qw(info error notice append dialog_yes_default send_report spurt chwn index_sync test_ebuild clean_logs uniq compiled_commit  process draw_up_line draw_down_line eix_sync atom);
use Cwd;
use Git::Sub;
use Git::Sub qw(diff stash);


#  name: last_commit
#  input: git_path_repository, master
#  output: last_commit
# Given a path of a git repo and his master file, it returns the last commit id
sub last_commit($$) {
    my $git_repository_path = $_[0];
    my $master              = $_[1];
    open my $FH,
          "<"
        . $git_repository_path . "/"
        . $master
        or (
        &error(
                  'Something is terribly wrong, cannot open '
                . $git_repository_path . "/"
                . $master
        )
        and exit 1
        );
    my @FILE = <$FH>;
    chomp(@FILE);
    close $FH;
    return $FILE[0];
}

sub register {
    my ( $self, $emitter ) = @_;
    my $cfg = App::witchcraft->instance->Config;
    $emitter->on(
        "index_sync" => sub {
            chdir(
                App::witchcraft->instance->Config->param('GIT_REPOSITORY') );
            eval {
                notice(
                    "Git pull for ["
                        . App::witchcraft->instance->Config->param(
                        'GIT_REPOSITORY')
                        . "] "
                        . git::pull
                );
            };
            if ($@) {
                send_report( "'Error pulling from remote repository", $@ );
                error($@);
            }
        }
    );
    $emitter->on(
        "stage_changes" => sub {
            my ( $witchcraft, @Atoms ) = @_;
            return ( 1, undef ) if ( @Atoms == 0 );
            my $cwd    = cwd();
            my $return = 1;
            index_sync;
            foreach my $atom (@Atoms) {
                eval { git::add $atom; };
                if ($@) {
                    send_report( "'Error indexing $atom to remote repository",
                        $@ );
                    error($@);
                }
                eval {
                          git::commit -m => '['
                        . $atom
                        . '] automatically added/updated by witchcraft';
                };
                if ($@) {
                    send_report(
                        "'Error committing $atom to remote repository", $@ );
                    error($@);
                }
                else {
                    send_report("Indexing: commit for $atom");
                }
                eval { git::push; };
                if ($@) {
                    send_report( "'Error pushing $atom to remote repository",
                        $@ );
                    error($@);
                }
            }
            chdir($cwd);

        }
    );

    $emitter->on(
        "untracked_test" => sub {
            shift;
            my $opts     = shift;
            my $dir      = $opts->{dir};
            my $ignore   = $opts->{ignore} || 0;
            my $password = $opts->{password} || undef;
            my $cb       = $opts->{callback} || sub { 1; };
            my $cwd      = cwd();
            return if !$dir;
            my @Installed;
            chdir($dir);
            my @Failed;
            my @ignores;
            my @Untracked = git::ls_files '--others', '--exclude-standard';
            push( @Untracked, git::diff_files '--name-only' );
            @Untracked = grep {/\.ebuild$/} @Untracked;
            info( "Those are the file that would be tested: "
                    . join( " ", @Untracked ) );
            clean_logs;    #spring cleaning!
            my $c = 1;
            my @Atoms_Installed;

            foreach my $new_pos (@Untracked) {
                info( "[$c/" . scalar(@Untracked) . "] Testing $new_pos" );
                my $atom = $new_pos;

                #$atom = filetoatom($atom);
                $c++;
                my $result = test_ebuild( $new_pos, 1, 1, $password );
                $new_pos =~ s/(.*\/[\w-]*)\/.*/$1/;

                if ( $result == 1 ) {
                    push( @Atoms_Installed, $atom );
                    push( @Installed, $new_pos );
                }
                else {
                    push( @Failed, $new_pos );
                }
            }
            if ( $ignore and $ignore == 1 and @Failed > 0 ) {
                tie @ignores, 'Tie::File', ${App::witchcraft::IGNORE}
                    or die( error $!);
                send_report(
                    "Witchcraft need your attention, i'm asking you few questions"
                );
                foreach my $fail (@Failed) {
                    push( @ignores, $fail )
                        if (
                        dialog_yes_default(
                            "Add " . $fail . " to the ignore list?"
                        )
                        );
                }
            }
            if ( @Installed > 0 ) {
                &info(
                    "Those files where correctly installed, maybe you wanna check them: "
                );
                my $result;
                notice($_) and $result .= " " . $_
                    for ( uniq(@Atoms_Installed) );
                send_report(
                    "These ebuilds where correctly installed: $result");
                info("Generating the command for maintenance");
                notice("git add $result");
                notice("eix-sync");
                notice("emerge -av $result");
                notice("eit add $result");
                notice("eit push");
                $cb->(@Installed);
            }
            else {
                info(
                    "No files where tested because there weren't untracked files or all packages failed to install"
                );
            }
            chdir($cwd);
        }
    );

    $emitter->on(
        "align_to" => sub {
            shift;
            my $last_commit = shift // compiled_commit();
            error 'No compiled commit could be found, you must specify it'
                and return 1
                if ( !defined $last_commit );
            info 'Emerging packages from commit ' . $last_commit;
            send_report("Align start, building commit from $last_commit");
            my $cfg = App::witchcraft->instance->Config;
            eix_sync;
            $emitter->emit( build_start => $last_commit );
            my $cwd = cwd;
            chdir( $cfg->param('OVERLAY_PATH') );
            my @FILES = map {
                $_ =~ s/.*\K\/.*?$//g;         #Removing the last part
                atom($_);                      #converting to atom
                $_ =~ s/.*\K\/Manifest$//g;    #removing manifest
                $_
                } grep {
                /Manifest$/i    #Only with the manifest are interesting
                } git::diff( $last_commit, '--name-only' );

            #  system("git stash");
            #my $Clean = App::witchcraft::Command::Clean->new;
            #$Clean->run;
            my @EMERGING = map { $_ . "::" . $cfg->param('OVERLAY_NAME') }
                grep { -d $_ } @FILES;
            if ( @EMERGING > 0 ) {
                notice 'These are the packages that would be processed:';
                draw_up_line;
                info "\t* " . $_ for @EMERGING;
                draw_down_line;
            }
            else {
                notice "No packages to emerge";
            }
            $last_commit = last_commit( $cfg->param('OVERLAY_PATH'),
                ".git/refs/heads/master" );
            process( @EMERGING, $last_commit, 0 );
            chdir($cwd);
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
            &notice(
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
            send_report("error happened stashing $dir") if $? != 0;
            chdir($cwd);
        }
    );

}

1;
