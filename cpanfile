requires 'App::CLI';
requires 'App::CLI::Command';
requires 'App::CLI::Command::Help';
requires 'App::Nopaste';
requires 'Carp::Always';
requires 'Child';
requires 'Config::Simple';
requires 'DateTime';
requires 'Deeme::Obj';
requires 'Digest::MD5';
requires 'Encode';
requires 'File::Path';
requires 'Git::Sub';
requires 'Github::Hooks::Receiver::Declare';
requires 'HTTP::Request::Common';
requires 'IPC::Run3';
requires 'Import::Into';
requires 'LWP::UserAgent';
requires 'Locale::TextDomain';
requires 'Module::Build';
requires 'Regexp::Common';
requires 'Term::ANSIColor';
requires 'Term::ReadKey';
requires 'forks';
requires 'parent';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.037';
};

on test => sub {
    requires 'Test::More';
};
