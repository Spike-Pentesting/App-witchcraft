requires 'App::CLI';
requires 'App::CLI::Command';
requires 'Git::Sub';
requires 'File::Xcopy';
requires 'Regexp::Common';
requires 'Term::ANSIColor';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.034';
    requires 'perl', '5.008005';
};

on test => sub {
    requires 'Test::More';
};
