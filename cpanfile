requires 'MIME::Base64';
requires 'Mojo::Base';
requires 'Scalar::Util';
requires 'feature';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.008005';
};

on test => sub {
    requires 'Test::More';
};
