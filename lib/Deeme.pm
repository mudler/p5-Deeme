package Deeme;
use strict;
use 5.008_005;
our $VERSION = '0.01';
use Mojo::Base -base;
use Carp 'croak';

has 'backend';

use Scalar::Util qw(blessed weaken);

use constant DEBUG => $ENV{DEEME_DEBUG} || 0;

sub new {
    my $self = shift;
    $self = $self->SUPER::new(@_);
    croak("No backend defined") if !$self->backend;
    $self->backend->deeme($self);
    return $self;
}

sub catch { $_[0]->on( error => $_[1] ) and return $_[0] }

sub emit {
    my ( $self, $name ) = ( shift, shift );

    if ( my $s = $self->backend->events_get($name) ) {
        warn "-- Emit $name in @{[blessed $self]} (@{[scalar @$s]})\n"
            if DEBUG;
        for my $cb (@$s) {
            $self->$cb(@_);
        }
    }
    else {
        warn "-- Emit $name in @{[blessed $self]} (0)\n" if DEBUG;
        die "@{[blessed $self]}: $_[0]" if $name eq 'error';
    }

    return $self;
}

sub emit_safe {
    my ( $self, $name ) = ( shift, shift );

    if ( my $s = $self->backend->events_get($name) ) {
        warn "-- Emit $name in @{[blessed $self]} safely (@{[scalar @$s]})\n"
            if DEBUG;
        for my $cb (@$s) {
            $self->emit( error => qq{Event "$name" failed: $@} )
                unless eval {
                $self->$cb(@_);
                1;
                };
        }
    }
    else {
        warn "-- Emit $name in @{[blessed $self]} safely (0)\n" if DEBUG;
        die "@{[blessed $self]}: $_[0]" if $name eq 'error';
    }

    return $self;
}

sub has_subscribers { !!@{ shift->subscribers(shift) } }

sub on {
    my ( $self, $name, $cb ) = @_;
    $self->backend->event_add( $name, $cb ||= [] );
    return $cb;
}

sub once {
    my ( $self, $name, $cb ) = @_;

    weaken $self;
    my $wrapper;
    $wrapper = sub {
        $self->unsubscribe( $name => $wrapper );
        $cb->(@_);
    };
    $self->on( $name => $wrapper );
    weaken $wrapper;

    return $wrapper;
}

sub subscribers { shift->backend->events_get( shift() ) || [] }

sub unsubscribe {
    my ( $self, $name, $cb ) = @_;

    # One
    if ($cb) {
        my $events
            = [ grep { q($cb) ne $_ } @{ $self->backend->events_get($name) } ];
        $self->backend->event_delete($name) and return $self
            unless @{$events};
        $self->backend->event_update( $name, $events );
    }

    # All
    else { $self->backend->event_delete($name); }

    return $self;
}

1;
__END__

=encoding utf-8

=head1 NAME

Deeme - a Database-agnostic driven Event Emitter

=head1 SYNOPSIS

  use Deeme;

=head1 DESCRIPTION

Deeme is a database-agnostic driven event emitter.
Deeme allows you to define binding subs on different points in multiple applications, and execute them inside your master worker.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
