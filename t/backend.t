use Test::More;
use Deeme;
use feature 'say';
use strict;
use_ok("Deeme::Backend::Meerkat");
use_ok("Deeme::Backend::Meerkat::Model::Event");
my $Deeme = Deeme->new(
    backend => Deeme::Backend::Meerkat->new(
        database => "deeme",
        host     => "mongodb://localhost:27017"
    )
);


$Deeme->on(roar => sub {
  my ($tiger, $times) = @_;
  say 'RAWR!' for 1 .. $times;
});
$Deeme->emit(roar => 3);

# replace with the actual test
ok($Deeme);

done_testing;
