package App::witchcraft::Plugin::Log;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error notice append spurt chwn);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use File::Path qw(make_path);
use DateTime;

sub register {
    my ( $self, $emitter ) = @_;
    my $hostname = $App::witchcraft::HOSTNAME;
    return undef unless $emitter->Config->param('LOGS_DIR');
    info "Registering Log hooks";
    $emitter->on(
        "send_report_body" => sub {
            my ( $witchcraft, $message, $log ) = @_;
            my $dir = $self->prepare_dir;
            append(
                $message
                    . "\n\n########################################\n"
                    . $log
                    . "\n\n############END##########\n",
                $dir . "/" . DateTime->now->day . ".txt"
            ) if $dir;
        }
    );
    $emitter->on(
        "send_report_link" => sub {
            my ( $witchcraft, $message, $url ) = @_;
            my $dir = $self->prepare_dir;
            append( $url . ":" . $message,
                $dir . "/" . DateTime->now->day . ".txt" )
                if $dir;
        }
    );
    $emitter->on(
        "send_report_message" => sub {
            my ( $witchcraft, $message ) = @_;
            my $dir = $self->prepare_dir;
            append( $message, $dir . "/" . DateTime->now->day . ".txt" )
                if $dir;
        }
    );

}

sub prepare_dir {
    my $self = shift;
    my $dt   = DateTime->now;
    my $cfg  = App::witchcraft->instance->Config;
    my $dir  = $cfg->param('LOGS_DIR') . "/" . $dt->year . "/" . $dt->month;
    make_path($dir);
    if ( $cfg->param('LOGS_USER') ) {
        chwn $cfg->param('LOGS_USER'),
            $cfg->param('LOGS_USER'),
            $cfg->param('LOGS_DIR');
        chwn $cfg->param('LOGS_USER'),
            $cfg->param('LOGS_USER'),
            $cfg->param('LOGS_DIR') . "/" . $dt->year;
        chwn $cfg->param('LOGS_USER'), $cfg->param('LOGS_USER'), $dir;
    }
    return $dir;
}

1;
