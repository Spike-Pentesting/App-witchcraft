package App::witchcraft::Utils::Git;
use base qw(Exporter);
our @EXPORT    = ();
our @EXPORT_OK = qw(last_commit);
use App::witchcraft::Utils qw(info error);
use Locale::TextDomain 'App-witchcraft';

#  name: last_commit
#  input: git_path_repository, master
#  output: last_commit
# Given a path of a git repo and his master file, it returns the last commit id
sub last_commit {
    my $git_repository_path = $_[0];
    my $master = $_[1] // ".git/refs/heads/master";
    open my $FH,
          "<"
        . $git_repository_path . "/"
        . $master
        or (
        error(
            __x('Something is terribly wrong, cannot open {git_repository_path} {master}',
                git_repository_path => $git_repository_path,
                master              => $master
            )
        )
        and exit 1
        );
    my @FILE = <$FH>;
    chomp(@FILE);
    close $FH;
    return $FILE[0];
}

1;
