requires 'Deeme::Util';
requires 'EV', '4.0';
requires 'Hash::Util::FieldHash';
requires 'IO::Pipely';
requires 'List::Util';
requires 'MIME::Base64';
requires 'Perl::OSType';
requires 'Scalar::Util';
requires 'Socket';
requires 'Time::HiRes';
requires 'feature';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build';
};

on test => sub {
    requires 'Test::More';
};
