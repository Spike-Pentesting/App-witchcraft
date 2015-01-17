package App::witchcraft::Utils;
use warnings;
use strict;
use base qw(Exporter);
use Term::ANSIColor;
use constant debug => $ENV{DEBUG};
use Tie::File;
use Term::ReadKey;
use App::Nopaste 'nopaste';
use File::Basename;
use Fcntl qw(LOCK_EX LOCK_NB);
use Locale::TextDomain 'App-witchcraft';
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

our @EXPORT = qw(
    info
    error
    notice
    draw_up_line
    draw_down_line
    send_report
    on
    emit
);

our @EXPORT_OK = (
    qw(

        slurp
        spurt
        append

        uniq
        natural_order
        truncate_words

        build_processed
        build_processed_manually
        last_manual_build
        last_build

        daemonize

        vagrant_box_cmd
        log_command
        command
        vagrant_box_status
        chwn

        password_dialog
        dialog_yes_default
        print_list

        stage
        test_untracked
        test_ebuild
        clean_stash
        clean_untracked
        index_sync
        find_ext
        repo_update
        filetoatom

        last_md5

        on
        emit

        upgrade

        ), @EXPORT
);

=encoding utf-8

=head1 NAME

App::witchcraft::Utils - Various utilities functions


=head1 DESCRIPTION

Common functions used by modules

=cut

sub stage(@) {
    &emit( stage_changes => (@_) );
}

sub test_untracked(@) {
    &emit( test_untracked => (@_) );
}

sub clean_stash {
    &emit( clean_stash => (@_) );
}

sub clean_untracked {
    &emit( clean_untracked => (@_) );
}

sub index_sync {
    &emit( index_sync => (@_) );
}

sub on(@) {
    App::witchcraft->instance->on(@_);
}

sub emit(@) {
    App::witchcraft->instance->emit(@_);
}

sub spurt {
    my ( $content, $path ) = @_;
    croak __x(
        "Can't open file '{path}': {error}",
        path  => $path,
        error => $!
    ) unless open my $file, '>', $path;
    croak __x(
        "Can't write file '{path}': {error}",
        path  => $path,
        error => $!
    ) unless defined $file->syswrite($content);
    return $content;
}

sub repo_update {
    &emit("repositories.update");
}

sub last_md5() {
    open my $last,
          "<"
        . App::witchcraft->instance->Config->param('MD5_PACKAGES') . "."
        . App::witchcraft->instance->Config->param('OVERLAY_NAME')
        or (
        &send_report(
            __("Can't access to last compiled packages md5"),
            __x('Can\'t open {md5} -> {error}',
                md5 =>
                    App::witchcraft->instance->Config->param('MD5_PACKAGES'),
                error => $!
            )
        )
        and return undef
        );
    my $last_md5 = <$last>;
    close $last;
    return $last_md5;
}

sub slurp {
    my $path = shift;
    croak __x(
        "Can't open file '{path}': {error}",
        path  => $path,
        error => $!
    ) unless open my $file, '<', $path;
    my $content = '';
    while ( $file->sysread( my $buffer, 131072, 0 ) ) { $content .= $buffer }
    return $content;
}

sub find_ext($$) {
    my $dir = shift;
    my $ext = shift;
    my @EBUILDS;
    find(
        {   wanted => sub { push @EBUILDS, $_ if $_ =~ /\.$ext$/ },
            no_chdir => 1
        },
        $dir
    );
    return @EBUILDS;
}

sub filetoatom {
    return map {
        my @pieces = split( /\//, $_ );
        $pieces[-3] . '/' . $pieces[-2];
    } @_;
}

sub append {
    my ( $content, $path ) = @_;
    croak __x(
        "Can't open file '{path}': {error}",
        path  => $path,
        error => $!
    ) unless open my $file, '>>', $path;
    croak __x(
        "Can't write file '{path}': {error}",
        path  => $path,
        error => $!
    ) unless defined $file->syswrite($content);
    return $content;
}

sub chwn {
    my $uid = getpwnam shift;
    my $gid = getgrnam shift;
    chown $uid, $gid, shift;
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

sub last_manual_build() {
    open my $last,
          "<"
        . App::witchcraft->instance->Config->param('MD5_PACKAGES') . "."
        . App::witchcraft->instance->Config->param('OVERLAY_NAME')
        or (
        &send_report(
            __("Can't access to last compiled packages md5"),
            __x('Can\'t open {md5} -> {error}',
                md5 =>
                    App::witchcraft->instance->Config->param('MD5_PACKAGES'),
                error => $!
            )
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
sub last_build() {
    open FILE,
          "<"
        . App::witchcraft->instance->Config->param('LAST_COMMIT') . "."
        . App::witchcraft->instance->Config->param('OVERLAY_NAME')
        or
        ( &notice( __("Nothing was previously compiled") ) and return undef );
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

sub build_processed($) {
    open my $fh,
          ">"
        . App::witchcraft->instance->Config->param('LAST_COMMIT') . "."
        . App::witchcraft->instance->Config->param('OVERLAY_NAME')
        or return 0;
    return 0 if !$fh;
    print $fh shift;
    close $fh;
    return 1;
}

sub build_processed_manually($) {
    open my $fh,
          ">"
        . App::witchcraft->instance->Config->param('MD5_PACKAGES') . "."
        . App::witchcraft->instance->Config->param('OVERLAY_NAME')
        or return 0;
    return 0 if !$fh;
    print $fh shift;
    close $fh;
    return 1;
}

sub truncate_words { shift =~ /(.{1,$_[0]}[\W\D])/gms; }

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
    &emit("before_$command");
    my @LOG = `$command 2>&1`;
    if ( $? == 0 ) {
        &notice( __x( "{command} succeded", command => $command ) );
        &emit("after_$command");
        return 1;
    }
    else {
        &error(
            __x( "Something went wrong with {command}", command => $command )
        );
        &send_report( __x( "Phase: {command} failed", command => $command ),
            "$command : ", @LOG );
        return 0;
    }
}

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
        &info( __('Manifest created successfully') );
        &clean_logs;
        &draw_down_line
            and return 1
            if ( defined $manifest and !defined $install );
        &info(
            __x( "Starting installation for {ebuild}", ebuild => $ebuild ) );
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
            &info( __x( '[{ebuild}] Installation OK', ebuild => $ebuild ) );
            return 1;
        }
        else {
            &send_report(
                __x("Emerge failed for {ebuild}",
                    ebuild => $specific_ebuild
                ),
                __x("Emerge failed for {ebuild}",
                    ebuild => $specific_ebuild
                ),
                join( " ", &find_logs() )
                )
                if App::witchcraft->instance->Config->param(
                "REPORT_TEST_FAILS")
                and
                App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
                == 1;
            &error( __("Installation failed") ) and return 0;
        }
    }
    else {
        &send_report(
            __x("Manifest phase failed for {ebuild} ... be more carefully next time!",
                ebuild => $ebuild
            )
            )
            if App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
            and App::witchcraft->instance->Config->param("REPORT_TEST_FAILS")
            == 1;
        &error( __("Manifest failed") ) and return 0;
    }
}

sub command {
    my $command = shift;
    &info("Phase: $command");
    &emit("before_$command");
    if ( system("$command 2>&1") == 0 ) {
        &notice( __x( "{command} succeeded", command => $command ) );
        &emit("after_$command");
        return 1;
    }
    else {
        &error(
            __x( "Something went wrong with {command}", command => $command )
        );
        &send_report( __x( "Phase: {command} failed", command => $command ) );
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
    &notice(">> $message ");

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
            &emit( send_report_body => ( $message, $log ) );
        }
        else {
            &emit( send_report_link => ( $message, $url ) );
        }
    }
    else {
        &emit( send_report_message => ($message) );
    }
    return $success;
}

sub daemonize($) {
    our ( $ProgramName, $PATH, $SUFFIX ) = fileparse($0);

    open( SELFLOCK, "<$0" )
        or die(
        __x( "Couldn't open {file}: {error}", file => $0, error => $! ) );

    flock( SELFLOCK, LOCK_EX | LOCK_NB )
        or die(
        _x( "Aborting: another {program} is already running",
            program => $ProgramName )
            . "\n"
        );
    open( STDOUT, "|-", "logger -t $ProgramName" )
        or
        die( __x( "Couldn't open logger output stream: {error}", error => $! )
            . "\n" );
    open( STDERR, ">&STDOUT" )
        or
        die( __x( "Couldn't redirect STDERR to STDOUT: {error}", error => $! )
            . "\n" );
    $| = 1; # Make output line-buffered so it will be flushed to syslog faster
            # chdir('/')
      #    ; # Avoid the possibility of our working directory resulting in keeping an otherwise unused filesystem in use
    exit if ( fork() );
    exit if ( fork() );
    sleep 1 until getppid() == 1;
    print __x(
        "{program} {pid} successfully daemonized",
        program => $ProgramName,
        pid     => $$
    ) . "\n";

}

sub _debug {
    print STDERR @_, "\n" if debug;
}

sub password_dialog {
    return undef if $> == 0;
    &info( __("Password: ") );
    ReadMode('noecho');    # don't echo
    chomp( my $password = <STDIN> );
    ReadMode(0);           # back to normal
    &notice(
        __( "Note: ensure to give the right password, or install tests would fail"
        )
    );
    $password = &password_dialog
        unless (
        system( 'echo ' . $password . ' | sudo -S echo Password OK' ) == 0 );
    return $password;
}

sub uniq {
    return keys %{ { map { $_ => 1 } @_ } };
}

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
