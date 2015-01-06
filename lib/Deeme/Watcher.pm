package Deeme::Watcher;

=head1 NAME

Deeme::Watcher - Watcher base class for L<Deeme>

=head1 DESCRIPTION

L<Deeme::Watcher> is a base class for implementing watchers in L<Deeme>.
The Watcher holds the loop, and here you can set where to listen

=cut

#use Deeme -base;
use Deeme::Obj "Deeme::IOLoop";
use Carp;
use Storable 'dclone';


my $singleton;
sub new { $singleton ||= shift->SUPER::new(@_); }

=head1 METHODS

Methods of the watcher class

=cut

=head2 go

starts the simulation

=cut

sub go {
    $_[0]->_load_plugins;
    $_[0]->prepare() if $_[0]->can("prepare");
    $_[0]->recurring( 0 => sub { shift->emit("tick") } )
        ;       #adding our "tick" to the Event loop
 $_[0]->start;

}

sub _load_plugins {
    my $self   = shift;
    my $Loader = Deeme::Loader->new;
    for ( $Loader->search("Deeme::Watcher::Plugin") ) {
        next if $Loader->load($_);
        $_->new->register($self) if $_->can("register");
    }
}

=head2 step
Add the callback to the main event

    Deeme::Watcher->new->step( sub { sleep 1; })->go; # Now the simulation sleeps between each "tick"

=cut

sub step {
    $_[0]->on( tick => $_[1] );
    shift;
}

=head1 LICENSE

Copyright (C) mudler.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=cut

1;
