package App::witchcraft::Utils;
use warnings;
use strict;
use base qw(Exporter);
use Term::ANSIColor;
use constant debug => $ENV{DEBUG};
use Git::Sub;

our @EXPORT = qw(_debug
    info
    error
    notice
    print_list
    test_untracked
);

sub _debug {
    print STDERR @_, "\n" if debug;
}

sub test_untracked {
    my $dir = shift;
    my @Installed;
    chdir($dir);
    my @Untracked = git::ls_files '--others', '--exclude-standard';
    @Untracked = grep {/\.ebuild$/} @Untracked;
    foreach my $new_pos (@Untracked) {
        if ( system("ebuild $new_pos manifest") == 0 ) {
            &info( "created manifest for " . $new_pos );
            if ( system("ebuild $new_pos install") == 0 ) {
                $new_pos = s/(.*\/[\w-]*)\//$1/;
                &info("Installation OK");
                push( @Installed, $new_pos );
            }

        }
    }

    &info(
        "Those files where correctly installed, maybe you wanna check them: "
    );
    my $result;
    &notice($_) and $result .= " " . $_ for (@Installed);
    &info("Generating the command for git add");

    &notice("git add $result");
}

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

sub error {
    my @msg = @_;
    print STDERR color 'red';
    print STDERR '@@@@WitchCraft@@@@ '.join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub info {
    my @msg = @_;
    print STDERR color 'green';
    print STDERR '<WitchCraft> '.join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub notice {
    my @msg = @_;
    print STDERR color 'bold yellow';
    print STDERR '!WitchCraft! '.join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub dialog_yes_default {
    my $msg = shift;
    local $|;
    print STDERR '! WitchCraft-> '.$msg;
    print STDERR ' (Y/n) ';

    my $a = <STDIN>;
    chomp $a;
    if ( $a =~ /n/ ) {
        return 0;
    }
    return 1 if $a =~ /y/;
    return 1;    # default to Y
}

1;
