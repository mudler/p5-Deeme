use lib './lib';
 use diagnostics -verbose;
use Deeme;
use strict;
use Deeme::Backend::Meerkat;
use Deeme::Backend::Meerkat::Model::Event;
use feature 'say';

my $Deeme = Deeme->new(
    backend => Deeme::Backend::Meerkat->new(
        database => "deeme",
        host     => "mongodb://localhost:27017",
        password=>"",
        username=>""
    )
);


$Deeme->on(roar => sub {
  my ($tiger, $times) = @_;
  say 'RAWR!' for 1 .. $times;
});
say "EMITTING";
$Deeme->emit(roar => 3);

# replace with the actual test
