package App::witchcraft::Utils::Base;
use warnings;
use strict;
use base qw(Exporter);
use Term::ANSIColor;
use constant debug => $ENV{DEBUG};
use Git::Sub;
use Tie::File;
use Term::ReadKey;
use App::Nopaste 'nopaste';
use File::Basename;
use Fcntl qw(LOCK_EX LOCK_NB);

use LWP::UserAgent;
use Digest::MD5;
use IO::Socket::INET;
use utf8;
use Encode;
use File::Copy;
use File::Find;
use Carp;
use Cwd;
$|++;    # turn off output buffering;

our @EXPORT = qw( _debug
    info
    error
    notice
    draw_up_line
    draw_down_line
    send_report
    print_list
    test_untracked
    clean_untracked
    test_ebuild
    uniq
    password_dialog
    atom
    daemonize
    depgraph
    emerge
    git_index
    git_sync
    natural_order
    bump
);

our @EXPORT_OK = (
    qw( conf_update save_compiled_commit process to_ebuild save_compiled_packages find_logs find_diff last_md5 last_commit compiled_commit
        natural_order
        euscan
        command
        find_ebuilds
        vagrant_box_status
        filetoatom
        truncate_words
        upgrade
        chwn
        filetopackage
        slurp
        append
        spurt
        clean_stash
        vagrant_box_cmd
        log_command
        bump
        clean_logs
        eix_sync), @EXPORT
);

=encoding utf-8

=head1 NAME

App::witchcraft::Utils::Base - Various utilities functions


=head1 DESCRIPTION

Upgrade entropy repository packages.

=cut

sub filetoatom {
    return map {
        my @pieces = split( /\//, $_ );
        $pieces[-3] . '/' . $pieces[-2];
    } @_;
}

sub filetopackage {
    return map {
        my @pieces = split( /\//, $_ );
        $_ = $pieces[-3] . '/' . $pieces[-1];
        s/\.ebuild//;
        $_;
    } @_;
}

sub spurt {
    my ( $content, $path ) = @_;
    croak qq{Can't open file "$path": $!} unless open my $file, '>', $path;
    croak qq{Can't write to file "$path": $!}
        unless defined $file->syswrite($content);
    return $content;
}

sub slurp {
    my $path = shift;
    croak qq{Can't open file "$path": $!} unless open my $file, '<', $path;
    my $content = '';
    while ( $file->sysread( my $buffer, 131072, 0 ) ) { $content .= $buffer }
    return $content;
}

sub append {
    my ( $content, $path ) = @_;
    croak qq{Can't open file "$path": $!} unless open my $file, '>>', $path;
    croak qq{Can't write to file "$path": $!}
        unless defined $file->syswrite($content);
    return $content;
}

sub chwn {
    my $uid = getpwnam shift;
    my $gid = getgrnam shift;
    chown $uid, $gid, shift;
}

sub conf_update {
    croak
        "conf_update is not implemented by App::witchcraftUtils::Base class";
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
    &notice( 'opening ' . $atom );
    opendir( DH, $atom ) or ( &error("Cannot open $atom") and return undef );
    my @files
        = sort { -M join( '/', $atom, $a ) <=> -M join( '/', $atom, $b ) }
        grep { -f join( '/', $atom, $_ ) and /\.ebuild$/ } readdir(DH);
    closedir(DH);
    my $last = shift @files;
    &error("No ebuild could be found in $atom") and return undef
        if ( !defined $last );
    my $source = join( '/', $atom, $last );
    &notice(  'Using =====> '
            . $last
            . ' <===== as a skeleton for the new version' );
    &notice("Copying");
    &info( "Bumped: " . $updated )
        and App::witchcraft->instance->emit( bump => ( $atom, $updated ) )
        and return 1
        if defined $last
        and copy( $source, $updated );
    return undef;
}

sub upgrade {
    my $cfg = App::witchcraft->instance->Config;
    &log_command( "cpanm " . $cfg->param('WITCHCRAFT_GIT') )
        if ( $cfg->param('WITCHCRAFT_GIT') );
}

sub natural_order {
    my @a = @_;
    return [
        @a[    #natural sort order for strings containing numbers
            map { unpack "N", substr( $_, -4 ) } #going back to normal representation
            sort
            map {
                my $key = $a[$_];
                $key =~ s[(\d+)][ pack "N", $1 ]ge
                    ;    #transforming all numbers in ascii representation
                $key . pack "CNN", 0, 0, $_
            } 0 .. $#a
        ]
    ];
}

sub process(@) {
    croak "process is not implemented by App::witchcraftUtils::Base class";
}

sub emerge(@) {
    croak "emerge is not implemented by App::witchcraftUtils::Base class";
}

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

sub clean_logs {
    system("find /var/tmp/portage/ | grep build.log | xargs rm -rf")
        ;    #spring cleaning!
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

#
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

sub previous_commit($$) {
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
    close $FH;
    my ( $last_commit, $all ) = split( / /, $FILE[-1] );
    return $last_commit;
}

sub last_md5() {
    open my $last,
        "<"
        . App::witchcraft->instance->Config->param('MD5_PACKAGES')
        or (
        &send_report(
            "Errore nella lettura dell'ultimo md5 compilato",
            'Can\'t open '
                . App::witchcraft->instance->Config->param('MD5_PACKAGES')
                . ' -> '
                . $!
        )
        and return undef
        );
    my $last_md5 = <$last>;
    close $last;
    return $last_md5;
}

#
#  name: compiled_commit
#  input: none
#  output: last commit
#
sub compiled_commit() {
    open FILE, "<" . App::witchcraft->instance->Config->param('LAST_COMMIT')
        or ( &notice("Nothing was previously compiled") and return undef );
    my @LAST = <FILE>;
    close FILE;
    chomp(@LAST);
    return $LAST[0];
}
#
#  name: save_compiled_commit
#  input: $commit
#  output: void
#  it just saves the last commit on the specified file

sub save_compiled_commit($) {
    open FILE, ">" . App::witchcraft->instance->Config->param('LAST_COMMIT');
    print FILE shift;
    close FILE;
}

sub save_compiled_packages($) {
    open FILE, ">" . App::witchcraft->instance->Config->param('MD5_PACKAGES');
    print FILE shift;
    close FILE;
}

#
#  name: find_diff
#  input: git_path_repository, master
#  output: @DIFFS
# takes as argument the git path repository and the master file
# generate  diff from the last build and returns the packages to compile

sub find_diff($$) {
    my $git_repository_path = $_[0];
    my $master              = $_[1];
    my $commit = &compiled_commit // &previous_commit( $git_repository_path,
        App::witchcraft->instance->Config->param('GIT_HISTORY_FILE') );
    my $git_cmd
        = App::witchcraft->instance->Config->param('GIT_DIFF_COMMAND');
    $git_cmd =~ s/\[COMMIT\]/$commit/g;
    my @DIFFS;
    open CMD, "cd $git_repository_path;$git_cmd | ";  # Parsing the git output
    while (<CMD>) {
        my ( $diff, $all ) = split( / /, substr( $_, 1, -3 ) );
        push( @DIFFS, $1 ) if $diff =~ /(.*)\/Manifest/;
    }
    chomp(@DIFFS);
    return ( &uniq(@DIFFS) );
}

sub find_ebuilds($) {
    my $dir = shift;
    my @EBUILDS;
    find(
        {   wanted => sub { push @EBUILDS, $_ if $_ =~ /\.ebuild$/ },
            no_chdir => 1
        },
        $dir
    );
    return @EBUILDS;
}

sub depgraph($$) {
    my $package = shift;
    my $depth   = shift;
    return
        map { $_ =~ s/\[.*\]|\s//g; &atom($_); $_ }
        qx/equery -C -q g --depth=$depth $package/;    #depth=0 it's all
}

sub truncate_words {
    my $string = shift;
    my @pieces;
    my $maxlength = shift;
    if ( $string =~ /^(.{0,$maxlength})\b(.*)$/ ) {
        push( @pieces, "$1..." );
        push( @pieces, &truncate_words($2,$maxlength) ) if $2;
    }
    return @pieces;
}


=head1 log_command($command)

log each fail on a given command, and return it's fail/succeeded state

=head2 EMITS

=head3 before_$command

Emitted before the execution of the given $command

=head3 after_$command

Emitted after the execution of the given $command

=cut

sub log_command {
    my $command = shift;
    &info("Phase: $command");
    App::witchcraft->instance->emit("before_$command");
    my @LOG = `$command 2>&1`;
    if ( $? == 0 ) {
        &notice("$command succeded");
        App::witchcraft->instance->emit("after_$command");
        return 1;
    }
    else {
        &error("Something went wrong with $command");
        &send_report( "Phase: $command failed", @LOG );
        return 0;
    }
}

sub command {
    my $command = shift;
    &info("Phase: $command");
    App::witchcraft->instance->emit("before_$command");
    if ( system("$command 2>&1") == 0 ) {
        &notice("$command succeded");
        App::witchcraft->instance->emit("after_$command");
        return 1;
    }
    else {
        &error("Something went wrong with $command");
        &send_report("Phase: $command failed");
        return 0;
    }
}

=head1 send_report ($message, @lines)

send report status back to the user
Tries to generate a nopaste url if @lines are given, emits the following depending if the link was generated

=head2 EMITS

=head3 send_report_body => $message, $log

No paste link could be generated, $log contains now all your lines squashed by \n

=head3 send_report_message => $message

The report should contain only a message

=head3 send_report_link => $message,$link

The @lines where successfully posted, $link is the url of the nopaste

=cut

#usage send_report("Message Title", @_);
sub send_report {
    my $message = shift;
    return undef
        unless ( App::witchcraft->instance->Config->param('ALERT_BULLET')
        or App::witchcraft->instance->Config->param('IRC_CHANNELS') );
    &info("Sending report status");

    #  &info( 'Sending ' . $message );
    my $hostname = $App::witchcraft::HOSTNAME;
    my $success  = 0;
    if (@_) {
        my $log = join( "\n", @_ );

        #   &notice( 'Attachment ' . $log );
        my $url;
        eval {
            $url = nopaste(
                text          => $log,
                private       => 1,
                error_handler => sub {
                    my ( $error, $service ) = @_;
                    warn "$service: $error";
                },
                warn_handler => sub {
                    my ( $warning, $service ) = @_;
                    warn "$service: $warning";
                },
                services => [ "Pastie", "Shadowcat" ],
            );
            1;
        };
        if ($@) {
            App::witchcraft->instance->emit(
                send_report_body => ( $message, $log ) );
        }
        else {
            App::witchcraft->instance->emit(
                send_report_link => ( $message, $url ) );
        }
    }
    else {
        App::witchcraft->instance->emit( send_report_message => ($message) );
    }
    return $success;
}

sub eix_sync {
    &log_command("eix-sync");
}

######## END

sub git_sync() {
    chdir( App::witchcraft->instance->Config->param('GIT_REPOSITORY') );
    eval {
        &notice(  "Git pull for ["
                . App::witchcraft->instance->Config->param('GIT_REPOSITORY')
                . "] "
                . git::pull );
    };
    if ($@) {
        &error($@);
    }
}

sub git_index(@) {
    my @Atoms = @_;
    return ( 1, undef ) if ( @Atoms == 0 );
    my $cwd    = cwd();
    my $return = 1;
    &git_sync;
    foreach my $atom (@Atoms) {
        eval { &notice( git::add $atom); };
        if ($@) {
            &error($@);
            $return = 0;
        }
        eval {
            &notice(
                git::commit -m => 'witchcraft: automatically added/updated '
                    . $atom );
        };
        if ($@) {
            &error($@);
            $return = 0;
        }
    }
    eval { &notice(git::push); };
    if ($@) {
        &error($@);
        $return = 0;
    }
    chdir($cwd);
    return ( $return, $@ );
}

sub daemonize($) {
    our ( $ProgramName, $PATH, $SUFFIX ) = fileparse($0);

    open( SELFLOCK, "<$0" ) or die("Couldn't open $0: $!\n");

    flock( SELFLOCK, LOCK_EX | LOCK_NB )
        or die("Aborting: another $ProgramName is already running\n");
    open( STDOUT, "|-", "logger -t $ProgramName" )
        or die("Couldn't open logger output stream: $!\n");
    open( STDERR, ">&STDOUT" )
        or die("Couldn't redirect STDERR to STDOUT: $!\n");
    $| = 1; # Make output line-buffered so it will be flushed to syslog faster
            # chdir('/')
      #    ; # Avoid the possibility of our working directory resulting in keeping an otherwise unused filesystem in use
    exit if ( fork() );
    exit if ( fork() );
    sleep 1 until getppid() == 1;
    print "$ProgramName $$ successfully daemonized\n";

}

sub atom { s/-[0-9]{1,}.*$//; }

sub _debug {
    print STDERR @_, "\n" if debug;
}

sub password_dialog {
    return undef if $> == 0;
    &info("Password: ");
    ReadMode('noecho');    # don't echo
    chomp( my $password = <STDIN> );
    ReadMode(0);           # back to normal
    &notice(
        "Note: ensure to give the right password, or install tests would fail"
    );
    $password = &password_dialog
        unless (
        system( 'echo ' . $password . ' | sudo -S echo Password OK' ) == 0 );
    return $password;
}

sub clean_untracked {
    my $dir = shift;
    my @Installed;
    my $cwd = cwd;
    chdir($dir);
    system("git ls-files --others --exclude-standard | xargs rm -rfv");
    &notice(
        "Launch 'git stash' if you want to rid about all the modifications");
    chdir($cwd);
    return $? == 0 ? 1 : 0;
}

sub clean_stash {
    my $dir = shift;
    my @Installed;
    my $cwd = cwd;
    chdir($dir);
    system("git stash");
    &info("$dir stashed") if $? == 0;
    chdir($cwd);
    return $? == 0 ? 1 : 0;
}

sub uniq {
    return keys %{ { map { $_ => 1 } @_ } };
}

sub euscan {
    my $Package = shift;
    my @temp    = `euscan -q -C $Package`;
    chomp(@temp);
    return @temp;
}

=head1 test_ebuild ($ebuild, manifest:1, install:1,$password)

test the ebuild, creating the manifest and call the install phase if requested

=head2 EMITS

=head3 before_test => $ebuild

Called before testing, giving the ebuild path

=head3 after_test => $ebuild

Called after a successfully test phase

=cut

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
        &info('Manifest created successfully');
        &clean_logs;
        &draw_down_line
            and return 1
            if ( defined $manifest and !defined $install );
        &info("Starting installation");
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
            &info('Installation OK');
            return 1;
        }
        else {
            &send_report( "Emerge failed for $specific_ebuild",
                join( " ", &find_logs() ) )
                if App::witchcraft->instance->Config->param(
                "REPORT_TEST_FAILS")
                and
                App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
                == 1;
            &error("Installation failed") and return 0;
        }
    }
    else {
        &send_report(
            "Manifest phase failed for $ebuild ... be more carefully next time!"
            )
            if App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
            and App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
            == 1;
        &error("Manifest failed") and return 0;
    }
}

sub test_untracked {
    my $dir      = shift;
    my $ignore   = shift || 0;
    my $password = shift || undef;
    my @Installed;
    chdir($dir);
    my @Failed;
    my @ignores;
    my @Untracked = git::ls_files '--others', '--exclude-standard';
    push( @Untracked, git::diff_files '--name-only' );
    @Untracked = grep {/\.ebuild$/} @Untracked;
    &info( "Those are the file that would be tested: "
            . join( " ", @Untracked ) );
    system("find /var/tmp/portage/ | grep build.log | xargs rm -rfv")
        ;    #spring cleaning!
    my $c = 1;
    my @Atoms_Installed;

    foreach my $new_pos (@Untracked) {
        &info( "[$c/" . scalar(@Untracked) . "] Testing $new_pos" );
        my $atom = $new_pos;

        #$atom = filetoatom($atom);
        $c++;
        my $result = &test_ebuild( $new_pos, 1, 1, $password );
        $new_pos =~ s/(.*\/[\w-]*)\/.*/$1/;

        if ( $result == 1 ) {
            push( @Atoms_Installed, $atom );

            #  &info( $new_pos . " was correctly installed" );
            push( @Installed, $new_pos );
        }
        else {
            # &error( $new_pos . " installation failed" );
            push( @Failed, $new_pos );
        }
    }
    if ( $ignore == 1 and @Failed > 0 ) {
        tie @ignores, 'Tie::File', ${App::witchcraft::IGNORE}
            or die( error $!);
        &send_report(
            "Witchcraft need your attention, i'm asking you few questions");
        foreach my $fail (@Failed) {
            push( @ignores, $fail )
                if (
                &dialog_yes_default(
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
        &notice($_) and $result .= " " . $_ for ( &uniq(@Atoms_Installed) );
        &send_report("These ebuilds where correctly installed: $result");
        &info("Generating the command for maintenance");
        &notice("git add $result");
        &notice("eix-sync");
        &notice("emerge -av $result");
        &notice("eit add $result");
        &notice("eit push");
        return @Installed;
    }
    else {
        &info(
            "No files where tested because there weren't untracked files or all packages failed to install"
        );
        return ();
    }
}

#################### vagrant functs

sub vagrant_box_status {
    (   split /,/,    #splitting --machine-readable output
        (   &vagrant_box_cmd( "status --machine-readable",
                shift )    #taking just the output, ignoring the return status
            )[1]->[1]      # the second line of the output contain the status
    )[3];                  #the third column has the status
}

sub vagrant_box_cmd {
    my $cmd = shift;
    my $cwd = cwd;
    chdir(shift);
    my @v = `vagrant $cmd 2>&1`;
    chomp @v;
    chdir($cwd);
    return ( $?, \@v );
}

########################################################
########################################################
####################Output Functions########################
########################################################

sub print_list {
    my @lines = @_;

    my $column_w = 0;

    map { $column_w = length( $_->[0] ) if length( $_->[0] ) > $column_w; }
        @lines;

    my $screen_width = 92;

    for my $arg (@lines) {
        my $title   = shift @$arg;
        my $padding = int($column_w) - length($title);

        if ( $ENV{WRAP}
            && ( $column_w + 3 + length( join( " ", @$arg ) ) )
            > $screen_width )
        {
            # wrap description
            my $string
                = color('bold')
                . $title
                . color('reset')
                . " " x $padding . " - "
                . join( " ", @$arg ) . "\n";

            $string =~ s/\n//g;

            my $cnt       = 0;
            my $firstline = 1;
            my $tab       = 4;
            my $wrapped   = 0;
            while ( $string =~ /(.)/g ) {
                $cnt++;

                my $c = $1;
                print $c;

                if ( $c =~ /[ \,]/ && $firstline && $cnt > $screen_width ) {
                    print "\n" . " " x ( $column_w + 3 + $tab );
                    $firstline = 0;
                    $cnt       = 0;
                    $wrapped   = 1;
                }
                elsif ($c =~ /[ \,]/
                    && !$firstline
                    && $cnt > ( $screen_width - $column_w ) )
                {
                    print "\n" . " " x ( $column_w + 3 + $tab );
                    $cnt     = 0;
                    $wrapped = 1;
                }
            }
            print "\n";
            print "\n" if $wrapped;
        }
        else {
            print color 'bold';
            print $title;
            print color 'reset';
            print " " x $padding;
            print " - ";
            $$arg[0] = ' ' unless $$arg[0];
            print join " ", @$arg;
            print "\n";
        }

    }
}

sub draw_up_line {
    &notice(
        encode_utf8(
            "▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼"
        )
    );
}

sub draw_down_line {
    &notice(
        encode_utf8(
            "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲"
        )
    );
}

sub error {
    my @msg = @_;
    print STDERR color 'bold red';
    print STDERR encode_utf8('☢☢☢ ☛  ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub info {
    my @msg = @_;
    print STDERR color 'bold green';
    print STDERR encode_utf8('╠ ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub notice {
    my @msg = @_;
    print STDERR color 'bold yellow';
    print STDERR encode_utf8('☛ ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub dialog_yes_default {
    my $msg = shift;
    local $|;
    print STDERR color 'bold blue';
    print STDERR '~~> ' . $msg;
    print STDERR ' (Y/n) ';
    print STDERR color 'reset';
    my $a = <STDIN>;
    chomp $a;

    if ( $a =~ /n/ ) {
        return 0;
    }
    return 1 if $a =~ /y/;
    return 1;    # default to Y
}

1;

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::witchcraft>, L<App::witchcraft::Command::Sync>

=cut
