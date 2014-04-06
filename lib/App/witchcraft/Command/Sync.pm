package App::witchcraft::Command::Sync;

use base qw(App::witchcraft::Command);
use App::witchcraft::Utils;
use warnings;
use strict;
use File::Find;
use File::Copy;
use Regexp::Common qw/URI/;
use File::Xcopy;

sub options {
    (   "r|refactor=s"       => "refactor",          #Who is to refactor?
        "t|refactortarget=s" => 'refactor_target',   #Who is the substitution?
        "u|update" => "update",    #Wanna transfer directly the new files?
        "r|root=s" => "root",      #where is the git repository?
        "i|install" => "install",
        "t|temp=s" => "temp"       #temp directory for the svn checkout
    );
}

sub run {
    my $self     = shift;
    my $RepoUrl  = shift // 'http://pentoo.googlecode.com/svn/portage/trunk';
    my $refactor = $self->{'refactor'} // 'pentoo';
    my $temp     = $self->{'temp'} // '/var/tmp/spike-trunk';
    my $refactor_target = $self->{'refactor_target'} // 'spike';
    my @ignores         = <DATA>;
    chomp(@ignores);
    my $flatten = join( "|", @ignores );
    my $l_r     = lc($refactor);
    my $u_r     = uc($refactor);
    my $m_r     = uc( substr( $refactor, 0, 1 ) ) . substr( $refactor, 1 );
    my $l_t     = lc($refactor_target);
    my $u_t     = uc($refactor_target);
    my $m_t     = uc( substr( $refactor_target, 0, 1 ) )
        . substr( $refactor_target, 1 );

    my @Installed;

    system( "svn checkout $RepoUrl " . $temp );
    finddepth(
        sub {
            my $file      = $File::Find::name;
            my $file_name = $_;

            # info "Refactor term is $refactor";
            if (   $file_name =~ /$refactor/i
                or $file =~ /$refactor/i
                or $file =~ /$flatten/i )
            {
                error $file. " removed";
                unlink($file) if ( -f $file );
                rmdir($file)  if ( -d $file );
                return;
            }

            if ( -f $file
                and $file_name =~ /\.ebuild$/ )
            {
                info "[File] $file contains pentoo";

                my $new_pos = $file;

                # $new_pos =~ s/$l_r/$l_t/gi;
                # move( $file, $new_pos );
                # notice "$file moved to $new_pos";
                # unlink($file);
                open FILE, "<$new_pos";
                my @LINES = <FILE>;
                close FILE;

                for (@LINES) {
                    next
                        if (
                        m!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!
                        );
                    if (/$u_r/) {
                        $_ =~ s/$u_r/$u_t/g;
                        info "$_ -------------> $new_pos";

                    }
                    elsif (/$l_r/) {
                        $_ =~ s/$l_r/$l_t/g;
                        info "$_ -------------> $new_pos";

                    }
                    elsif (/$m_r/) {
                        $_ =~ s/$m_r/$m_t/g;
                        info "$_ -------------> $new_pos";
                    }
                }
                open FILE, ">$new_pos";
                print FILE @LINES;
                close FILE;
  

            }
            else {
                #   info "$file ignored";
            }

        },
        $temp
    );

    #unlink( $temp . "/.svn" );
    return if ( !$self->{update} );
    info "Copying content to git directory";
    my $dir
        = $self->{root} || -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";

    system( "rsync --ignore-existing -avp " . $temp . "/* $dir\/" );
    unlink($dir.'/.svn');
    return if(!$self->{install});
    test_untracked($dir);
    exit;
}


1;
__DATA__
compat-wireless
linux-live
profiles
prism54
compat-drivers
acpid
layout.conf
linux-sources
genmenu
nvidia-drivers
ati-drivers
openrc
mkxf86config
genkernel
