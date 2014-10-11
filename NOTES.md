# generate metadata in the tree for all the packages that already haven't metagen:
    find ./ -type d | grep -v 'files' | perl -MCwd -e 'my $cwd=cwd; while(<>){ chomp;chdir $_; if(grep{/\.ebuild/} <*>){print "Ebuild in $_\n"; if(grep{/metadata/} <*>){print "Metadata in $_\n";} else { print "Generating metadata in $_\n"; system("metagen -vm"); }  } chdir($cwd)};'


 find ./ | grep ebuild | perl -e 'while(<>){chomp; system("ebuild $_ digest");}' #digest every ebuild!


 find ./ -type d | perl -e 'use File::Path qw(make_path remove_tree);while(<>){chomp;next if (split(/\//,$_))==2 or $_=~/files/; @a=grep {/ebuild/} <$_/*>; print "$_ no ebuild file! probably moved away\n" if @a==0;}'

find ./ -type d | perl -e 'use File::Path qw(make_path remove_tree);while(<>){chomp;next if (split(/\//,$_))==2 or $_=~/files|^\.\/\./ or $_ eq "./"; @a=grep {/ebuild/} <$_/*>; print "$_\n" if @a==0;}'
