package Deeme::Backend::Mongoose;
use Mojo::Base 'Deeme::Backend';
use Mongoose;
has 'dsn';

sub new {
    my $self = shift;
    $self->SUPER::new();
    Mongoose->db(
        host    => $self->Config->DBConfiguration->{'db_dsn'},
        db_name => $self->Config->DBConfiguration->{'db_name'}
    );
    return $self;
}

sub events_get {
    croak 'Method "events_get" not implemented by subclass';
}    #get events

sub event_add {
    croak 'Method "event_add" not implemented by subclass';
}    #add events

sub event_delete {
    croak 'Method "event_delete" not implemented by subclass';
}    #delete event

sub event_update {
    croak 'Method "event_update" not implemented by subclass';
}    #update event

package Deeme::Backend::Mongoose::_Event;
use Moose;
has 'name' => ( is => "rw" );
has 'sub'  => ( is => "rw" );

1;
