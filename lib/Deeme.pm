package Deeme;
use strict;
use 5.008_005;
our $VERSION = '0.01';
use Mojo::Base -base;
use Carp 'croak';
use Deeme::Utils qw( _deserialize _serialize);

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
        my @onces = $self->backend->events_onces($name);
        my $i     = 0;
        for my $cb (@$s) {
            $self->$cb(@_);
            ( $onces[$i] == 1 )
                ? ( $self->_unsubscribe_index( $name => $i ) )
                : $i++;
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
        my @onces = $self->backend->events_onces($name);
        my $i     = 0;
        for my $cb (@$s) {
            $self->emit( error => qq{Event "$name" failed: $@} )
                unless eval {
                $self->$cb(@_);
                ( $onces[$i] == 1 )
                    ? ( $self->_unsubscribe_index( $name => $i ) )
                    : $i++;
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
    return $self->backend->event_add( $name, $cb ||= [], 0 );
}

sub once {
    my ( $self, $name, $cb ) = @_;
    return $self->backend->event_add( $name, $cb ||= [], 1 );
}

sub subscribers { shift->backend->events_get( shift() ) || [] }

sub unsubscribe {
    my ( $self, $name, $cb ) = @_;

    # One
    if ($cb) {
        my @events = @{ $self->backend->events_get( $name, 0 ) };
        my @onces = $self->backend->events_onces($name);

        my ($index) = grep { $cb eq $events[$_] } 0 .. $#events;
        if ($index) {
            splice @events, $index, 1;
            splice @onces,  $index, 1;
            my $ev = [@events];
            $self->backend->event_delete($name) and return $self
                unless @{$ev};
            $self->backend->event_update( $name, $ev, 0 );
            $self->backend->once_update( $name, \@onces );
        }
    }

    # All
    else { $self->backend->event_delete($name); }

    return $self;
}

sub _unsubscribe_index {
    my ( $self, $name, $index ) = @_;

    my @events = @{ $self->backend->events_get( $name, 0 ) };
    my @onces = $self->backend->events_onces($name);

    splice @events, $index, 1;
    splice @onces,  $index, 1;
    my $ev = [@events];
    $self->backend->event_delete($name) and return $self
        unless @{$ev};
    say "Unsubscribing $index";
    $self->backend->event_update( $name, $ev, 0 );
    $self->backend->once_update( $name, \@onces );

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
