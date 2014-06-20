package Deeme::Backend::Meerkat;
use Mojo::Base 'Deeme::Backend';
use Meerkat;
use Deeme::Utils qw(_serialize _deserialize);
use Carp 'croak';

has [qw(database host username password meerkat)];

sub new {
    my $self = shift;
    $self = $self->SUPER::new(@_);
    my $opts = {};
    croak "No database defined" if ( !$self->database );
    $opts->{host} = $self->host || croak "No host defined";
    $opts->{username} = $self->username if ( $self->username );
    $opts->{password} = $self->password if ( $self->password );
    $self->meerkat(
        Meerkat->new(
            model_namespace => "Deeme::Backend::Meerkat::Model",
            database_name   => $self->database,
            client_options  => $opts,
        )
    );
    return $self;
}

sub events_get {
    my $self        = shift;
    my $name        = shift;
    my $deserialize = shift // 1;
    my $event
        = $self->meerkat->collection("Event")->find_one( { name => $name } );

    #deserializing subs and returning a reference
    return undef if ( !$event );
    return [ map { _deserialize($_) } @{ $event->functions() } ]
        if ( $deserialize == 1 );
    return $event->functions();
}    #get events

sub events_onces {
    my $self = shift;
    my $name = shift;
    my $event
        = $self->meerkat->collection("Event")->find_one( { name => $name } );

    #deserializing subs and returning a reference
    return @{ $event->onces() };
}    #get events

sub once_update {
    my $self  = shift;
    my $name  = shift;
    my $onces = shift;
    $self->meerkat->collection("Event")->find_one( { name => $name } )
        ->update_set( onces => $onces );
}    #get events

sub event_add {
    my $self = shift;
    my $name = shift;
    my $cb   = shift;
    my $once = shift // 0;
    $cb = _serialize($cb);
    return $cb
        if ( $self->meerkat->collection("Event")
        ->find_one( { name => $name, functions => $cb } ) )
        ;    #return if already existing
             #  serializing sub and adding to db
    if ( my $event
        = $self->meerkat->collection("Event")->find_one( { name => $name } ) )
    {
        $event->update_push( functions => $cb );
        $event->update_push( onces     => $once );
    }
    else {
        my $event = $self->meerkat->collection("Event")->create(
            name      => $name,
            functions => [$cb],
            onces     => [$once]
        );
    }
    return $cb;
}

sub event_delete {
    my $self = shift;
    my $name = shift;
    $self->meerkat->collection("Event")->find_one( { name => $name } )
        ->remove();
}    #delete event

sub event_update {
    my $self      = shift;
    my $name      = shift;
    my $functions = shift;
    my $serialize = shift // 1;
    return $self->event_delete($name) if ( scalar( @{$functions} ) == 0 );
    return $self->meerkat->collection("Event")->find_one( { name => $name } )
        ->update_set( functions => [ map { _serialize($_) } @{$functions} ] )
        if ( $serialize == 1 );
    $self->meerkat->collection("Event")->find_one( { name => $name } )
        ->update_set( functions => $functions );
}    #update event

package Deeme::Backend::Meerkat::Model::Event;
use Moose;
with 'Meerkat::Role::Document';

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has functions => (
    is  => 'ro',
    isa => 'ArrayRef',
);

has onces => (
    is  => 'ro',
    isa => 'ArrayRef'
);

1;
