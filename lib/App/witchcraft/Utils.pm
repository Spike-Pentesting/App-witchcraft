package App::witchcraft::Utils;
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
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use Expect;
use Digest::MD5;
use IO::Socket::INET;
use utf8;
use Encode;
use Cwd;

our @EXPORT = qw(_debug
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
    calculate_missing
    emerge
    git_index
);

our @EXPORT_OK
    = qw(conf_update save_compiled_commit process to_ebuild save_compiled_packages find_logs find_diff last_md5 last_commit compiled_commit remove_available);

sub conf_update {
    my $Expect = Expect->new;
    $Expect->raw_pty(1);
    $Expect->spawn("equo conf update")
        or send_report(
        "error executing equo conf update",
        "Cannot spawn equo conf update: $!\n"
        );

    $Expect->send("-5\n");
    $Expect->soft_close();
}

sub irc_msg(@) {
    my @MESSAGES = @_;
    my $cfg      = App::witchcraft->Config;
    return undef unless ( defined $cfg->param('IRC_IDENT') );
    my $ident    = $cfg->param('IRC_IDENT');
    my $realname = $cfg->param('IRC_REALNAME');
    my @channels = $cfg->param('IRC_CHANNELS');
    my $socket   = IO::Socket::INET->new(
        PeerAddr => $cfg->param('IRC_SERVER'),
        PeerPort => $cfg->param('IRC_PORT'),
        Proto    => "tcp",
        Timeout  => 10
    ) or &error("Couldn't connect to the irc server");
    &info("Sending notification also on IRC");
    $socket->autoflush(1);
    sleep 2;
    printf $socket "NICK " . $cfg->param('IRC_NICKNAME') . "\r\n";
    printf $socket "USER $ident $ident $ident $ident :$realname\r\n";

    while ( my $line = <$socket> ) {
          if ($line =~ m/^\:(.+?)\s+376/i) {
            foreach my $chan (@channels) {
                printf $socket "JOIN $chan\r\n";
                &info( "Joined $chan on " . $cfg->param('IRC_SERVER') );
                printf $socket "PRIVMSG $chan :$_\r\n" and sleep 2
                    for @MESSAGES;
                sleep 5;
            }
            printf $socket "QUIT\r\n";
        }
    }

}

#
#  name: process
#  input: @DIFFS
#  output: void
#  Questa funziona si occupa , da un array i quali elementi sono pacchetti di tipo: category/nomepacchetto
#  genera la lista che viene fatta compilare tramite emerge e poi aggiunta alla repository, ogni errore viene riportato
#
sub process(@) {
    my $use    = pop(@_);
    my $commit = pop(@_);
    my @DIFFS  = @_;
    &notice( "Processing " . join( " ", @DIFFS ) );
    my $cfg          = App::witchcraft->Config;
    my $overlay_name = $cfg->param('OVERLAY_NAME');
    my @CMD          = @DIFFS;
    @CMD = map { s/\:\:.*//g; $_ } @CMD;
    my @ebuilds = &to_ebuild(@CMD);

    if ( scalar(@ebuilds) == 0 and $use == 0 ) {
        &send_report("Packages removed, saving diffs.");
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
            &send_report(
                "[$commit] Pacchetti correttamente compilati:\n####################\n"
                    . join( "", @DIFFS ) );
            if ( $use == 0 ) {
                &save_compiled_commit($commit);
            }
            elsif ( $use == 1 ) {
                &save_compiled_packages($commit);
            }
        }
    }
}

sub emerge(@) {
    my $options = shift;
    my $emerge_options
        = join( " ", map { "$_ " . $options->{$_} } keys %{$options} );
    my @DIFFS = @_;
    my @CMD   = @DIFFS;
    return 1 if ( @DIFFS == 0 );
    @CMD = map { s/\:\:.*//g; $_ } @CMD;
    system("find /var/tmp/portage/ | grep build.log | xargs rm -rf")
        ;    #spring cleaning!
    &info( "Emerging... " . scalar(@DIFFS) . " packages" );
    &conf_update;    #EXPECT per DISPATCH-CONF
    &notice(
        "nice -20 emerge --color n -v --autounmask-write $emerge_options "
            . join( " ", @DIFFS ) );

    if (system(
            "nice -20 emerge --color n -v --autounmask-write $emerge_options "
                . join( " ", @DIFFS )
        ) == 0
        )
    {
        &info(    "Compressing "
                . scalar(@DIFFS)
                . " packages: "
                . join( " ", @DIFFS ) );
        ##EXPECT PER EIT ADD
        my $Expect = Expect->new;

        #       unshift( @CMD, "add" );
        #     push( @CMD, "--quick" );
        $Expect->spawn( "eit", "add", "--quick", @CMD )
            or send_report(
            "Errore nell'esecuzione di eit add, devi intervenire! Cannot spawn eit: $!\n"
            );
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
            &conf_update;
            if ( system("eit push --quick") == 0 ) {
                &info("All went smooth, HURRAY!");
                return 1;
            }
            else {
                &send_report(
                    "nice -20 eit sync --quick gave an error, check out!");
                return 0;
            }
        }
        else {
            my @LOGS = &find_logs();
            &send_report( "Errore nella compressione dei pacchetti",
                join( " ", @LOGS ) );
            return 0;
        }
    }
    else {
        my @LOGS = &find_logs();
        &send_report(
            "Errore nel merge dei pacchetti: " . join( " ", @DIFFS ),
            join( " ", @LOGS ) );
        return 0;
    }
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

#
#  name: to_ebuild
#  input:@DIFFS
#  output:@TO_EMERGE
#  Dato un'array contenente i pacchetti nel formato categoria/pacchetto, trova gli ebuild nell'overlay e genera un array
#
#.
sub to_ebuild(@) {
    my @DIFFS = @_;
    my @TO_EMERGE;
    my $overlay = App::witchcraft::Config->param('OVERLAY_PATH');
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
#  Data una path di una repository git e il suo master file, restituisce l'id dell'ultimo commit sulla repository git
#
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
        . App::witchcraft::Config->param('MD5_PACKAGES')
        or (
        &send_report(
            "Errore nella lettura dell'ultimo md5 compilato",
            'Can\'t open '
                . App::witchcraft::Config->param('MD5_PACKAGES') . ' -> '
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
#  output: Ultimo commit
#
sub compiled_commit() {
    open FILE, "<" . App::witchcraft::Config->param('LAST_COMMIT')
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
#  Funzione che salva nel file indicato dalla variabile $save_last_commit l'argomento passato
#
sub save_compiled_commit($) {
    open FILE, ">" . App::witchcraft::Config->param('LAST_COMMIT');
    print FILE shift;
    close FILE;
}

sub save_compiled_packages($) {
    open FILE, ">" . App::witchcraft::Config->param('MD5_PACKAGES');
    print FILE shift;
    close FILE;
}

#
#  name: find_diff
#  input: git_path_repository, master
#  output: @DIFFS
#  Questa funzione prende in ingresso la path della repository git e la locazione del master file,
#  procede poi a vedere le differenze tra il commit attuale e quello di cui è stato compilato correttamente,
#  restituisce i pacchetti da compilare.
sub find_diff($$) {
    my $git_repository_path = $_[0];
    my $master              = $_[1];
    my $commit = &compiled_commit // &previous_commit( $git_repository_path,
        App::witchcraft::Config->param('GIT_HISTORY_FILE') );
    my $git_cmd = App::witchcraft::Config->param('GIT_DIFF_COMMAND');
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

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = &depgraph( $package, $depth );     #depth=0 it's all
    &info( scalar(@Packages) . " dependencies found " );
    my @Installed_Packages = qx/equo q -q list installed/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    return @to_install;
}

sub depgraph($$) {
    my $package = shift;
    my $depth   = shift;
    return
        map { $_ =~ s/\[.*\]|\s//g; &atom($_); $_ }
        qx/equery -C -q g --depth=$depth $package/;    #depth=0 it's all
}

sub send_report {
    my $message = shift;
    my $ua      = LWP::UserAgent->new;
    &info( 'Sending ' . $message );
    my $hostname = $App::witchcraft::HOSTNAME;
    my @BULLET   = App::witchcraft::Config->param('ALERT_BULLET');
    my $success  = 0;
    if (@_) {
        my $log = join( "\n", @_ );
        &notice( 'Attachment ' . $log );
        my $url = nopaste(
            text    => $log,
            private => 1,      # default: 0

           # this is the default, but maybe you want to do something different
            error_handler => sub {
                my ( $error, $service ) = @_;
                warn "$service: $error";
            },

            warn_handler => sub {
                my ( $warning, $service ) = @_;
                warn "$service: $warning";
            },

            # you may specify the services to use - but you don't have to
            #     services => [ "pastie" ],
        );

        foreach my $BULL (@BULLET) {
            my $req = POST 'https://api.pushbullet.com/v2/pushes',
                [
                type  => 'link',
                title => "Witchcraft\@$hostname: " . $message,
                url   => $url
                ];
            $req->authorization_basic($BULL);
            my $res = $ua->request($req)->as_string;
            if ( $res =~ /HTTP\/1.1 200 OK/mg ) {
                &notice("Push sent correctly!");
                $success = 1;
            }
            else {
                &error("Error sending the push!");
                $success = 0;
            }
        }
        &irc_msg( "Witchcraft\@$hostname: "
                . $message
                . " - Nopaste link:"
                . $url );
    }
    else {
        &info('WOOOW BULLETS!');
        foreach my $BULL (@BULLET) {
            my $req = POST 'https://api.pushbullet.com/v2/pushes',
                [
                type  => 'note',
                title => 'Witchcraft@' . $hostname,
                body  => $message
                ];
            $req->authorization_basic($BULL);
            my $res = $ua->request($req)->as_string;
            if ( $res =~ /HTTP\/1.1 200 OK/mg ) {
                &notice("Push sent correctly!");
                $success = 1;
            }
            else {
                &error("Error sending the push!");
                $success = 0;
            }
        }
        &irc_msg( "Witchcraft\@$hostname: " . $message );
    }
    return $success;
}

sub remove_available(@) {
    my @Packages  = shift;
    my @Available = `equo q list -q available sabayonlinux.org`;
    chomp(@Available);
    my %available = map { $_ => 1 } @Available;
    return grep( !defined $available{$_}, @Packages );
}

sub git_index(@) {
    my @Atoms = @_;
    return ( 1, undef ) if ( @Atoms == 0 );
    my $cwd    = cwd();
    my $return = 1;
    chdir( App::witchcraft->Config->param('GIT_REPOSITORY') );
    eval { &notice(git::pull); };
    if ($@) {
        &error($@);
    }
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

    #  flock( SELFLOCK, LOCK_EX | LOCK_NB )
    #      or die("Aborting: another $ProgramName is already running\n");
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
    chdir($dir);
    system("git ls-files --others --exclude-standard | xargs rm -rfv");
    &notice(
        "Launch 'git stash' if you want to rid about all the modifications");
}

sub uniq {
    return keys %{ { map { $_ => 1 } @_ } };
}

sub test_ebuild {
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
        &draw_down_line
            and return 1
            if ( defined $manifest and !defined $install );
        &info("Starting installation");
        $ebuild =~ s/\.ebuild//;
        my @package = split( /\//, $ebuild );
        $ebuild = $package[0] . "/" . $package[2];
        $ebuild = "=" . $ebuild;
        &info(    "PORTDIR_OVERLAY='"
                . App::witchcraft::Config->param('GIT_REPOSITORY')
                . "' emerge "
                . $ebuild );

        if (defined $install
            and system( $password
                    . " PORTDIR_OVERLAY='"
                    . App::witchcraft::Config->param('GIT_REPOSITORY')
                    . "' emerge $ebuild"
            ) == 0
            )
        {
            &info('Installation OK');
            return 1;
        }
        else { &error("Installation failed") and return 0; }
    }
    else { &error("Manifest failed") and return 0; }
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

    foreach my $new_pos (@Untracked) {
        &info( "[$c/" . scalar(@Untracked) . "] Testing $new_pos" );
        $c++;
        my $result = &test_ebuild( $new_pos, 1, 1, $password );
        $new_pos =~ s/(.*\/[\w-]*)\/.*/$1/;
        if ( $result == 1 ) {

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
        &notice($_) and $result .= " " . $_ for ( &uniq(@Installed) );
        &send_report("Those ebuilds where correctly installed: $result");
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
