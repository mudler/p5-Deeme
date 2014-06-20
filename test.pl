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


$Deeme->once(roar => sub {
  my ($tiger, $times) = @_;
  say 'RAWR! , You should see me only once' for 1 .. $times;
});


$Deeme->emit(roar => 1);
$Deeme->emit(roar => 1);


# replace with the actual test
