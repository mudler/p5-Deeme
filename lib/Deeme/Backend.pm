package Deeme::Backend;
use Mojo::Base -base;
use B::Deparse;

use Carp 'croak';

has 'deeme';
has 'deparse' => sub{ B::Deparse->new };

sub _serialize {shift->deparse->coderef2text(shift);}

sub _deserialize {my $self=shift; my $cb=shift;eval("sub $cb")}

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

1;
