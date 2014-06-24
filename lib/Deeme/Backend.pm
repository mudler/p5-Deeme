package Deeme::Backend;
use Deeme::Obj -base;
use B::Deparse;
use Carp 'croak';

has 'deeme';
has 'deparse' => sub { B::Deparse->new };

sub events_get {
    croak 'Method "events_get" not implemented by subclass';
}    #get events

sub events_reset {
    croak 'Method "events_reset" not implemented by subclass';
}    #get events

sub events_onces {
    croak 'Method "events_onces" not implemented by subclass';
}    #get events

sub once_update {
    croak 'Method "once_update" not implemented by subclass';
}

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
