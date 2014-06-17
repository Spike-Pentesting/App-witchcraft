requires 'App::CLI';
requires 'App::CLI::Command';
requires 'App::CLI::Command::Help';
requires 'App::Nopaste';
requires 'Carp::Always';
requires 'Config::Simple';
requires 'Digest::MD5';
requires 'Encode';
requires 'Expect';
requires 'File::Path';
requires 'File::Xcopy';
requires 'Git::Sub';
requires 'HTTP::Request::Common';
requires 'LWP::UserAgent';
requires 'Regexp::Common';
requires 'Term::ANSIColor';
requires 'Term::ReadKey';
requires 'Test::More';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};
