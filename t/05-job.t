use Deeme::Obj -strict;
use Test::More;
use Deeme;
#use_ok("Deeme::Job");
# Normal event
my $e = Deeme::Worker->new( );

my $called;
$e->add( test1 => sub { $called+=$_[1];} );

while($e->dequeue("test1")){
    $e->process(1);
}
is $called, 1, ' 1 job was processed';

while($e->dequeue("test1")){
    $e->process(1);
}
is $called, 1, ' no job was processed';

$e->add( test2 => sub { $called+=$_[1]; print "Hey!\n";} );
$e->add( test2 => sub { $called+=$_[1]+1;print "Hey+1!\n";} );
use Data::Dumper;
print Dumper($e);
while( my $Job=$e->dequeue("test2")){
    $Job->process(1);
    print Dumper($e);

}
is $called, 4, ' 2 job was processed';
