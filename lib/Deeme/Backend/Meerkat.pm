package Deeme::Backend::Meerkat;
use Mojo::Base 'Deeme::Backend';
use Meerkat;
has [ qw(database host username password meerkat)] ;

sub new {
    my $self = shift;
    $self=$self->SUPER::new(@_);
    $self->meerkat(
        Meerkat->new(
            model_namespace => "Deeme::Backend::Meerkat::Model",
            database_name   => $self->database,
            client_options  => {
                host     => $self->host,

            },
        )
    );
    return $self;
}

sub events_get {
    my $self=shift;
    my $name=shift;
    my $event=$self->meerkat->collection("Event")->find_one({name=> $name});
    #deserializing subs and returning a reference
    return [map{ $self->_deserialize($_) } @{$event->functions()}];
}    #get events

sub event_add{
    my $self=shift;
    my $name=shift;
    my $cb=shift;
    return if ($self->meerkat->collection("Event")->find_one({name=> $name, functions=>$self->_serialize($cb)}));
    if(my $event=$self->meerkat->collection("Event")->find_one({name=> $name})){
        $event->update_push(functions => [$self->_serialize($cb)]);
    } else {
        my $event=$self->meerkat->collection("Event")->create(name=> $name, functions=> [$self->_serialize($cb)]);
    }
}

sub event_delete {
    my $self=shift;
    my $name=shift;
    $self->meerkat->collection("Event")->find_one(name => $name)->remove();
}    #delete event

sub event_update {
    my $self=shift;
    my $name=shift;
    my $functions = shift;
    $self->meerkat->collection("Event")->find_one(name => $name)->update_set(functions => [map{$self->_serialize($_)} @{$functions}]);
}    #update event

package Deeme::Backend::Meerkat::Model::Event;
use Moose;
with 'Meerkat::Role::Document';

has name => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has functions => (
    is      => 'ro',
    isa     => 'ArrayRef',
);

1;
