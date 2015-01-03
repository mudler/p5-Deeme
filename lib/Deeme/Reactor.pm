package Deeme::Reactor;
use Deeme -base;

use Carp 'croak';
use IO::Poll qw(POLLIN POLLPRI);
use Deeme::Loader;

sub again { croak 'Method "again" not implemented by subclass' }

sub detect {
  my $try = $ENV{DEEME_REACTOR} || 'Deeme::Reactor::EV';
  return Deeme::Loader->new->load($try) ? 'Deeme::Reactor::Poll' : $try;
}

sub io { croak 'Method "io" not implemented by subclass' }

# This may break at some point in the future, but is worth it for performance
sub is_readable {
  !(IO::Poll::_poll(0, fileno(pop), my $dummy = POLLIN | POLLPRI) == 0);
}

sub is_running { croak 'Method "is_running" not implemented by subclass' }

sub next_tick { shift->timer(0 => @_) and return undef }

sub one_tick  { croak 'Method "one_tick" not implemented by subclass' }
sub recurring { croak 'Method "recurring" not implemented by subclass' }
sub remove    { croak 'Method "remove" not implemented by subclass' }
sub reset     { croak 'Method "reset" not implemented by subclass' }
sub start     { croak 'Method "start" not implemented by subclass' }
sub stop      { croak 'Method "stop" not implemented by subclass' }
sub timer     { croak 'Method "timer" not implemented by subclass' }
sub watch     { croak 'Method "watch" not implemented by subclass' }

1;
=encoding utf8

=head1 NAME

L<Mojo::Reactor> fork

=cut
