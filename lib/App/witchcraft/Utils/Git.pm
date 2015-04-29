package App::witchcraft::Utils::Git;
use base qw(Exporter);
our @EXPORT    = ();
our @EXPORT_OK = qw(last_commit detect_rebase get_commit_by_order invalid_commit);
use App::witchcraft::Utils qw(info error give_stderr_to_dogs give_stdout_to_dogs);
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

sub detect_rebase{
    my $commit=shift;
    return give_stderr_to_dogs(
                        sub{
        
                            my @cmd=`git fsck --unreachable --no-reflog | grep $_[1]`;
                            return 0 if @cmd==0;
                            return 1;
                            
                        }, $commit );
}

sub get_commit_by_order {
    my $number= shift;
    my @hashs=`git log --format="%H" -n $number`;
    chomp(@hashs);
    return $hashs[$number-1];
}

sub invalid_commit{
    my $commit=shift;
    return give_stdout_to_dogs(
        su{
            if (   system("git show $_[0]|cat") != 0)
            {
              return 1;
            }  else {
                return 0;
            }     
        },
        $commit
    );
            
}

1;
