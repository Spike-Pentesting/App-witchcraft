package App::witchcraft::Plugin::Gentoo;
use Locale::TextDomain 'App-witchcraft';

use Deeme::Obj -base;
use App::witchcraft::Utils
  qw(info error notice append spurt chwn log_command send_report upgrade on emit draw_up_line draw_down_line uniq);
use App::witchcraft::Utils::Gentoo
  qw(stripoverlay clean_logs find_logs to_ebuild atom repo_update test_ebuild remove_emerge_packages);
use App::witchcraft::Utils::Git qw(last_commit get_commit_by_order);
use Cwd;
use App::witchcraft::Constants qw(BUILD_SUCCESS BUILD_FAILED BUILD_UNKNOWN);

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on( "repositories.update" => sub { repo_update(); } );
    $emitter->on(
        "packages.from_diff" => sub {
            my $self = shift;
            my $cfg  = App::witchcraft->instance->Config;
            my $cwd  = cwd();
            shift;
            my $id = get_commit_by_order(1);
            my @EMERGING;
            if (  !$cfg->param('FOLLOW_VERSIONING')
                or $cfg->param('FOLLOW_VERSIONING') != 1 )
            {
                my @FILES = map {

                    $_ =~ s/.*\K\/.*?$//g;    #Removing the last part
                    atom($_);                 #converting to atom

                    $_ =~ s/.*\K\/Manifest$//g;    #removing manifest
                    $_
                  } grep {
                    /Manifest$/i    #Only with the manifest are interesting
                  } @_;

                @EMERGING = map { $_ . "::" . $cfg->param('OVERLAY_NAME') }
                  grep { -d $_ and $_ =~ /\S/ } @FILES;

            }
            elsif ( $cfg->param('FOLLOW_VERSIONING')
                and $cfg->param('FOLLOW_VERSIONING') == 1 )
            {
                @EMERGING = map {
                    if ( $_ =~ /(.*?)\/.*\/(.*?)\.ebuild/ ) {
                        $_ = "="
                          . $1 . "/"
                          . $2 . "::"
                          . $cfg->param('OVERLAY_NAME');
                    }
                    $_;
                  } grep {
                    /\.ebuild$/i and -e $_    #Only ebuilds that exists worth
                  } @_;
            }

            #  system("git stash");
            #my $Clean = App::witchcraft::Command::Clean->new;
            #$Clean->run;
            if ( @EMERGING > 0 ) {
                notice( __('These are the packages that would be processed:') );
                draw_up_line;
                info "\t* " . $_ for @EMERGING;
                draw_down_line;
            }
            else {
                notice( __("No packages to emerge") );
            }

            App::witchcraft::Build->new(
                packages    => [@EMERGING],
                id          => $id,
                track_build => 1
            )->build;
            chdir($cwd);
        }
    );

    $emitter->on(
        "packages.test" => sub {
            my $self     = shift;
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
                    __x(
                        "[{count}/{total}] Testing {atom}",
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
                emit( "packages.after.test" => ($atom) );

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
                    __(
"Witchcraft need your attention, i'm asking you few questions"
                    )
                );
                foreach my $fail (@Failed) {
                    push( @ignores, $fail )
                      if (
                        dialog_yes_default(
                            __x(
                                "Add {failed} to the ignore list?",
                                failed => $fail
                            )
                        )
                      );
                }
            }
            if ( @Installed > 0 ) {
                &info(
                    __(
"Those files where correctly installed, maybe you wanna check them: "
                    )
                );
                my $result;
                notice($_) and $result .= " " . $_
                  for ( uniq(@Atoms_Installed) );
                send_report(
                    __x(
                        "These ebuilds where correctly installed: {result}",
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
                    __(
"No files where tested because there weren't untracked files or all packages failed to install"
                    )
                );
            }
            chdir($cwd);

        }
    );

    $emitter->on(
        "packages.untracked" => sub {
            my $self = shift;
            my $opts = shift;

            my @Untracked = grep { /\.ebuild$/ } @_;
            info(
                __x(
                    "Those are the file that would be tested: {untracked}",
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
            my $commit         = pop(@Packages);
            my $options        = pop(@Packages);
            my $emerge_options = pop(@Packages);
            my $on_success     = pop(@Packages);
            my $on_failed      = pop(@Packages);

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
                info(
                    __x(
                        "[{commit}] building packages: {packages}",
                        commit   => $commit,
                        packages => "@DIFFS"
                    )
                )
            );
            my $rs           = _emerge( $emerge_options, @DIFFS, $commit );
            my $build_status = $rs->[0];
            my @merged       = @{ $rs->[1] };
            my @unmerged     = @{ $rs->[2] };

            if ( $build_status == BUILD_SUCCESS
                or ( exists $options->{relaxed} and $options->{relaxed} == 1 ) )
            {
                send_report(
                    __x(
                        "[{commit}] Build completed for: {diffs}",
                        commit => $commit,
                        diffs  => "@DIFFS"
                    )
                );
                $on_success->(@DIFFS) if defined $on_success;
                emit( "packages.build.success" => ( $commit, @DIFFS ) );
            }

            if ( ( exists $options->{relaxed} and $options->{relaxed} == 1 ) ) {
                send_report(
                    __x(
                        "[{commit}] Merged: {merged} | Unmerged: {unmerged}",
                        commit   => $commit,
                        merged   => "@merged",
                        unmerged => "@unmerged"
                    )
                );
            }

            if ( $build_status == BUILD_FAILED ) {
                send_report(
                    __x(
                        "[{commit}] Failed: {diffs}",
                        commit => $commit,
                        diffs  => "@DIFFS"
                    )
                );
                $on_failed->(@DIFFS) if defined $on_failed;
                emit( "packages.build.failed" => ( $commit, @DIFFS ) );
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
    my $emerge_options = shift;

# App::witchcraft->instance->emit( "packages.build.before.emerge" => ($options) );

    $emerge_options =
      join( " ",
        map { "$_ " . $emerge_options->{$_} } keys %{$emerge_options} );
    $emerge_options .=
      " " . App::witchcraft->instance->Config->param('EMERGE_OPTS')
      if App::witchcraft->instance->Config->param('EMERGE_OPTS');

    my $commit = pop(@_);
    my @DIFFS  = @_;
    my @CMD    = @DIFFS;
    my @equo_install;
    my $rs = BUILD_SUCCESS;

    @CMD = map { stripoverlay($_); $_ } @CMD;
    my $args = $emerge_options . " " . join( " ", @DIFFS );
    clean_logs;
    emit( "packages.build.before.emerge" => ( @CMD, $commit ) );
    my @merged;
    my @unmerged;
    foreach my $package (@DIFFS) {
        $_ = $package;
        s/\=//g;
        atom;
        my $atom = $_;
        my $follow_revision = $atom eq $package ? 0 : 1;
        send_report( __x( "Building {package}", package => $package ) );
        emit( "package.$package.before.build" => ( $atom, $package, $commit ) );
        emit( "package.$atom.before.build"    => ( $atom, $package, $commit ) )
          if ( $follow_revision == 0 );

        if (
            log_command(
                "nice -20 emerge --color n -v $emerge_options $package  2>&1")
          )
        {
            push( @merged, $package );
            send_report(
                info(
                    __x(
                        "{package} builded successfully", package => $package
                    )
                )
            );
            emit( "package.$atom.after.build.success" =>
                  ( $atom, $package, $commit ) );
            emit( "package.$package.after.build.success" =>
                  ( $atom, $package, $commit ) )
              if ( $follow_revision == 0 );
            emit( "packages.build.after.emerge" => ( $package, $commit ) );
        }
        else {
            emit( "package.$atom.after.build.fail" =>
                  ( $atom, $package, $commit ) );
            emit( "package.$package.after.build.fail" =>
                  ( $atom, $package, $commit ) )
              if ( $follow_revision == 0 );
            push( @unmerged, $package );
            send_report( __x( "{package} build failed", package => $package ),
                join( " ", find_logs() ) );
            $rs = BUILD_FAILED;
        }

    }

    #Maintenance stuff
    upgrade;
    return [ $rs, \@merged, \@unmerged ];
}

1;
