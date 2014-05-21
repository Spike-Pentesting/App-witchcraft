package App::witchcraft::Command::Watch;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils;
use warnings;
use strict;
use File::Find;
use Regexp::Common qw/URI/;
use Tie::File;
use Expect;
use Digest::MD5;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Watch - Automatic compile and equo push after a git commit of an ebuild

=head1 SYNOPSIS

  $ witchcraft watch
  $ witchcraft w [--daemon]

=head1 DESCRIPTION

Automatic compile and equo push after a git commit of an ebuild A.K.A spikemate

=head1 ARGUMENTS

=over 4

=item C<-d|--daemon>

Run in background

=item C<--help>

it prints the POD help.

=back

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<App::witchcraft>, L<App::witchcraft::Command::Euscan>

=cut

sub options {
    ( "d|daemon" => "daemon", );
}

sub run {
    my $self = shift;
    error 'You must run it with root permissions' and exit 1 if $> != 0;
    my $cfg = App::witchcraft->Config;
    info 'Watching overlay '
        . $cfg->param('OVERLAY_NAME')
        . ' every '
        . $cfg->param('SLEEP_TIME') . ' s';
    &daemonize if $self->{daemon};
    &send_report("I'm up!");

    while ( 1 ) {
        info "Checking for updates, and merging up!";
        if ( system("layman -S") == 0 ) {    #Launch layman -S first.
            system("eix-sync");
            &update( $cfg->param('OVERLAY_PATH'),
                $cfg->param('GIT_MASTER_FILE') );
            &manual_update( $cfg->param('OVERLAY_PATH') );
        }
        else {
            &send_report( "Layman coudn't sync", "Executing : layman -S " );
        }
     sleep $cfg->param('SLEEP_TIME');
    }

}

sub manual_update($) {
    my $overlay = shift;
    my $cfg     = App::witchcraft->Config;
    my $overlay_to_compile_packages
        = $cfg->param('OVERLAY_MANUAL_COMPILE_FILE');

    if ( -e $overlay . "/" . $overlay_to_compile_packages ) {
        open( my $fh, '<', $overlay . "/" . $overlay_to_compile_packages )
            or send_report(
            "Errore nell'apertura dei file da compilare",
            "Cannot open $overlay/$overlay_to_compile_packages: $!"
            );
        binmode($fh);
        my $calculated_md5 = Digest::MD5->new->addfile($fh)
            ->hexdigest
            ;    #Computing the md5 of the file containing the packages
        close $fh;
        my $last_md5 = last_md5();
        info("Last md5 $last_md5 of $overlay/$overlay_to_compile_packages");
        if ( $calculated_md5 ne $last_md5 )
        {        #If they are different, then proceed the compile them
            open( my $fh, '<', $overlay . "/" . $overlay_to_compile_packages )
                or send_report(
                "Errore nell'apertura dei file da compilare",
                "Cannot open $overlay/$overlay_to_compile_packages: $!"
                );

            my @DIFFS = <$fh>;
            close $fh;
            chomp(@DIFFS);
            send_report(
                "Issued a manual packages compile, start compiling process",
                @DIFFS );
            process( @DIFFS, $calculated_md5, 1 );
        }
        else {
            notice(
                "Are you looking at me? i have NOTHING better to do than sleeping... can you say the same?"
            );
        }
    }
}

#
#  name: update
#  input: $overlay,$master_file
#  output: void
#  Funzione che si occupa di gestire le chiamate alle funzioni in caso di compile tramite l'ausilio dei commit di git
#
sub update($$) {
    my $overlay     = shift;
    my $master_file = shift;
    my ( $commit, $line ) = last_commit( $overlay, $master_file );
    info("Last commit: $commit");
    my $compiled_commit = compiled_commit();
    info("Last COMPILED commit: $compiled_commit");
    if ( $commit eq $compiled_commit ) {
        info(
            "Are you looking at me? i have NOTHING better to do than sleeping... can you say the same?"
        );
    }
    else {
        notice("Commits seems differents, calculating the differencies.");
        my @DIFFS = find_diff( $overlay, $master_file );
        info(     "A total of "
                . scalar(@DIFFS)
                . " real changes were found, proceeding to compile them." );
        send_report(
            "Working on "
                . join( " ", @DIFFS )
                . ", i'll be in touch: commit\n $line",
            "Compiling " . join( " ", @DIFFS ) . " for you.."
        );
        process( @DIFFS, $commit, 0 );  # 0 to use with git, 1 with manual use
    }
}

#
#  name: process
#  input: @DIFFS
#  output: void
#  Questa funziona si occupa , da un array i quali elementi sono pacchetti di tipo: category/nomepacchetto
#  genera la lista che viene fatta compilare tramite emerge e poi aggiunta alla repository, ogni errore viene riportato
#
sub process() {
    my $use          = pop(@_);
    my $commit       = pop(@_);
    my @DIFFS        = @_;
    my $cfg          = App::witchcraft->Config;
    my $overlay_name = $cfg->param('OVERLAY_NAME');
    my @ebuilds      = to_ebuild(@DIFFS);
    my @TO_EMERGE    = @DIFFS;
    @TO_EMERGE = map { $_ . "::" . $overlay_name } @TO_EMERGE;

    if ( scalar(@ebuilds) == 0 and $use == 0 ) {
        send_report("Packages removed, saving diffs.");
        if ( $use == 0 ) {
            save_compiled_commit($commit);
        }
        elsif ( $use == 1 ) {
            save_compiled_packages($commit);
        }
    }
    else {

#at this point, @DIFFS contains all the package to eit, and @TO_EMERGE, contains all the packages to ebuild.
        info( "Emerging... " . scalar(@TO_EMERGE) . " packages" );

        #EXPECT per DISPATCH-CONF
        my $Expect = Expect->new;
        $Expect->raw_pty(1);
        $Expect->spawn("dispatch-conf")
            or send_report(
            "error executing dispatch-conf",
            "Cannot spawn dispatch-conf: $!\n"
            );
        $Expect->expect(
            4,
            [   qr/use-new/ => sub {
                    my $exp = shift;
                    $exp->send("u\n");
                    }
            ],
            [ 'eof', sub { my $exp = shift; $exp->soft_close(); } ]
        );
        $Expect->soft_close();
        $Expect = Expect->new;
        if (system(
                "nice -20 emerge --color n -v --autounmask-write "
                    . join( " ", @TO_EMERGE )
            ) == 0
            )
        {
            info(     "Compressing "
                    . scalar(@DIFFS)
                    . " packages: "
                    . join( " ", @DIFFS ) );
            ##EXPECT PER EIT ADD
            my @CMD = @DIFFS;
            unshift( @CMD, "add" );
            push( @CMD, "--quick" );
            $Expect->spawn( "eit", @CMD )
                or send_report(
                "Errore nell'esecuzione di eit add, devi intervenire!",
                "Cannot spawn eit: $!\n" );
            $Expect->expect(
                '-re', 'nano',
                sub {
                    my $exp = shift;
                    $exp->send("\cX");
                    exp_continue;
                },
                'eof',
                sub {
                    my $exp = shift;
                    $exp->soft_close();
                }
            );
            if ( !$Expect->exitstatus()  or $Expect->exitstatus() == 0  ) {
                if ( system("eit push --quick") == 0 ) {
                    info(
                        "Fiuuuu..... tutto e' andato bene... aggiorno il commit che e' stato compilato correttamente"
                    );
                    send_report("Tutto ok, ultimo commit compilato:$commit");
                    send_report(
                        "Pacchetti compilati",
                        "Pacchetti correttamente compilati:\n####################\n"
                            . join( "", @DIFFS )
                    );
                    if ( $use == 0 ) {
                        save_compiled_commit($commit);
                    }
                    elsif ( $use == 1 ) {
                        save_compiled_packages($commit);
                    }
                }
                else {
                    send_report(
                        "Error pushing to sabayon repository",
                        "nice -20 eit sync --quick gave an error, check out!"
                    );
                }
            }
            else {
                my @LOGS = find_logs();
                send_report( "Errore nella compressione dei pacchetti",
                    join( " ", @LOGS ) );
            }
        }
        else {
            my @LOGS = find_logs();
            send_report(
                "Errore nel merge dei pacchetti: " . join( " ", @TO_EMERGE ),
                join( " ", @LOGS )
            );
        }
    }
}

sub send_report {
    my $message = shift;
    info 'Sending ' . $message;
    my $hostname   = $App::witchcraft::HOSTNAME;
    my @MAIL_ALERT = App::witchcraft::Config->param('ALERT_EMAIL');
    if ( my $log = shift ) {
        notice 'Attachment ' . $log;
        open my $FILE, ">/tmp/report.log";
        print $FILE $log;
        close $FILE;
        system(
            "echo \"$message\" | mutt -s '$hostname - Report from SpikeMate' '$_' -a '/tmp/report.log'"
        ) for @MAIL_ALERT;
    }
    else {
        system(
            "echo \"$message\" | mutt -s '$hostname - Good news from SpikeMate' '$_'"
        ) for @MAIL_ALERT;
    }
}

sub find_logs() {
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
sub to_ebuild() {
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
#  name: save_compiled_commit
#  input: $commit
#  output: void
#  Funzione che salva nel file indicato dalla variabile $save_last_commit l'argomento passato
#
sub save_compiled_commit() {
    open FILE, ">" . App::witchcraft::Config->param('LAST_COMMIT');
    print FILE shift;
    close FILE;
}

sub save_compiled_packages() {
    open FILE, ">" . App::witchcraft::Config->param('MD5_PACKAGES');
    print FILE shift;
    close FILE;
}

#
#  name: compiled_commit
#  input: none
#  output: Ultimo commit
#
sub compiled_commit() {
    open FILE, "<" . App::witchcraft::Config->param('LAST_COMMIT');
    my @LAST = <FILE>;
    close FILE;
    chomp(@LAST);
    return $LAST[0];
}

#
#  name: find_diff
#  input: git_path_repository, master
#  output: @DIFFS
#  Questa funzione prende in ingresso la path della repository git e la locazione del master file,
#  procede poi a vedere le differenze tra il commit attuale e quello di cui è stato compilato correttamente,
#  restituisce i pacchetti da compilare.
sub find_diff() {
    my $git_repository_path = $_[0];
    my $master              = $_[1];
    my ( $commit, $line ) = &last_commit( $git_repository_path, $master );
    my $git_cmd = App::witchcraft::Config->param('GIT_DIFF_COMMAND');
    $git_cmd =~ s/\[COMMIT\]/$commit/g;
    my @DIFFS;
    open CMD, "cd $git_repository_path;$git_cmd | ";  # Parsing the git output
    while (<CMD>) {
        my $line = $_;
        my ( $diff, $all ) = split( / /, substr( $line, 1, -3 ) );
        push( @DIFFS, $1 ) if $diff =~ /(.*)\/Manifest/;
    }
    chomp(@DIFFS);
    return ( uniq(@DIFFS) );
}

#
#  name: last_commit
#  input: git_path_repository, master
#  output: last_commit
#  Data una path di una repository git e il suo master file, restituisce l'id dell'ultimo commit sulla repository git
#
sub last_commit() {
    my $git_repository_path = $_[0];
    my $master              = $_[1];
    open my $FH, "<" . $git_repository_path . "/" . $master;
    my @FILE = <$FH>;
    close $FH;
    my ( $last_commit, $all ) = split( / /, $FILE[-1] );
    return $last_commit, $all;
}

sub last_md5() {
    open my $last,
        "<"
        . App::witchcraft::Config->param('MD5_PACKAGES')
        or send_report(
        "Errore nella lettura dell'ultimo md5 compilato",
        'Can\'t open '
            . App::witchcraft::Config->param('MD5_PACKAGES') . ' -> '
            . $!
        );
    my $last_md5 = <$last>;
    close $last;
    return $last_md5;
}
1;
