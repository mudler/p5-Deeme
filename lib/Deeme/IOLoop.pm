package Deeme::IOLoop;
use Deeme -base;

# "Professor: Amy, technology isn't intrinsically good or evil. It's how it's
#             used. Like the death ray."
use Carp 'croak';
use Deeme::IOLoop::Client;
use Deeme::IOLoop::Delay;
use Deeme::IOLoop::Server;
use Deeme::IOLoop::Stream;
use Deeme::Reactor::Poll;
use Deeme::Util qw(md5_sum steady_time);
use Scalar::Util qw(blessed weaken);
use feature 'state';

use constant DEBUG => $ENV{Deeme_IOLOOP_DEBUG} || 0;

has accept_interval => 0.025;
has [qw(lock unlock)];
has max_accepts     => 0;
has max_connections => 1000;
has multi_accept    => 50;
has reactor         => sub {
  my $class = Deeme::Reactor::Poll->detect;
  warn "-- Reactor initialized ($class)\n" if DEBUG;
  return $class->new->catch(sub { warn "@{[blessed $_[0]]}: $_[1]" });
};

# Ignore PIPE signal
$SIG{PIPE} = 'IGNORE';

# Initialize singleton reactor early
__PACKAGE__->singleton->reactor;

sub acceptor {
  my ($self, $acceptor) = (_instance(shift), @_);

  # Find acceptor for id
  return $self->{acceptors}{$acceptor} unless ref $acceptor;

  # Connect acceptor with reactor
  my $id = $self->_id;
  $self->{acceptors}{$id} = $acceptor;
  weaken $acceptor->reactor($self->reactor)->{reactor};
  $self->{accepts} = $self->max_accepts if $self->max_accepts;

  # Allow new acceptor to get picked up
  $self->_not_accepting;

  return $id;
}

sub client {
  my ($self, $cb) = (_instance(shift), pop);

  # Make sure timers are running
  $self->_recurring;

  my $id = $self->_id;
  my $client = $self->{connections}{$id}{client} = Deeme::IOLoop::Client->new;
  weaken $client->reactor($self->reactor)->{reactor};

  weaken $self;
  $client->on(
    connect => sub {
      delete $self->{connections}{$id}{client};
      my $stream = Deeme::IOLoop::Stream->new(pop);
      $self->_stream($stream => $id);
      $self->$cb(undef, $stream);
    }
  );
  $client->on(
    error => sub {
      $self->_remove($id);
      $self->$cb(pop, undef);
    }
  );
  $client->connect(@_);

  return $id;
}

sub delay {
  my $delay = Deeme::IOLoop::Delay->new;
  weaken $delay->ioloop(_instance(shift))->{ioloop};
  return @_ ? $delay->steps(@_) : $delay;
}

sub is_running { _instance(shift)->reactor->is_running }
sub next_tick  { _instance(shift)->reactor->next_tick(@_) }
sub one_tick   { _instance(shift)->reactor->one_tick }

sub recurring { shift->_timer(recurring => @_) }

sub remove {
  my ($self, $id) = (_instance(shift), @_);
  my $c = $self->{connections}{$id};
  if ($c && (my $stream = $c->{stream})) { return $stream->close_gracefully }
  $self->_remove($id);
}

sub reset {
  my $self = _instance(shift);
  $self->_remove($_)
    for keys %{$self->{acceptors}}, keys %{$self->{connections}};
  $self->reactor->reset;
  $self->$_ for qw(_stop stop);
}

sub server {
  my ($self, $cb) = (_instance(shift), pop);

  my $server = Deeme::IOLoop::Server->new;
  weaken $self;
  $server->on(
    accept => sub {
      my $stream = Deeme::IOLoop::Stream->new(pop);
      $self->$cb($stream, $self->stream($stream));
    }
  );
  $server->listen(@_);

  return $self->acceptor($server);
}

sub singleton { state $loop = shift->SUPER::new }

sub start {
  my $self = shift;
  croak 'Deeme::IOLoop already running' if $self->is_running;
  _instance($self)->reactor->start;
}

sub stop { _instance(shift)->reactor->stop }

sub stream {
  my ($self, $stream) = (_instance(shift), @_);

  # Find stream for id
  return ($self->{connections}{$stream} || {})->{stream} unless ref $stream;

  # Release accept mutex
  $self->_not_accepting;

  # Enforce connection limit (randomize to improve load balancing)
  $self->max_connections(0)
    if defined $self->{accepts} && ($self->{accepts} -= int(rand 2) + 1) <= 0;

  return $self->_stream($stream, $self->_id);
}

sub timer { shift->_timer(timer => @_) }

sub _accepting {
  my $self = shift;

  # Check if we have acceptors
  my $acceptors = $self->{acceptors} ||= {};
  return $self->_remove(delete $self->{accept}) unless keys %$acceptors;

  # Check connection limit
  my $i   = keys %{$self->{connections}};
  my $max = $self->max_connections;
  return unless $i < $max;

  # Acquire accept mutex
  if (my $cb = $self->lock) { return unless $cb->(!$i) }
  $self->_remove(delete $self->{accept});

  # Check if multi-accept is desirable
  my $multi = $self->multi_accept;
  $_->multi_accept($max < $multi ? 1 : $multi)->start for values %$acceptors;
  $self->{accepting}++;
}

sub _id {
  my $self = shift;
  my $id;
  do { $id = md5_sum('c' . steady_time . rand 999) }
    while $self->{connections}{$id} || $self->{acceptors}{$id};
  return $id;
}

sub _instance { ref $_[0] ? $_[0] : $_[0]->singleton }

sub _not_accepting {
  my $self = shift;

  # Make sure timers are running
  $self->_recurring;

  # Release accept mutex
  return unless delete $self->{accepting};
  return unless my $cb = $self->unlock;
  $cb->();

  $_->stop for values %{$self->{acceptors} || {}};
}

sub _recurring {
  my $self = shift;
  $self->{accept} ||= $self->recurring($self->accept_interval => \&_accepting);
  $self->{stop} ||= $self->recurring(1 => \&_stop);
}

sub _remove {
  my ($self, $id) = @_;

  # Timer
  return unless my $reactor = $self->reactor;
  return if $reactor->remove($id);

  # Acceptor
  if (delete $self->{acceptors}{$id}) { $self->_not_accepting }

  # Connection
  else { delete $self->{connections}{$id} }
}

sub _stop {
  my $self = shift;
  return      if keys %{$self->{connections}};
  $self->stop if $self->max_connections == 0;
  return      if keys %{$self->{acceptors}};
  $self->{$_} && $self->_remove(delete $self->{$_}) for qw(accept stop);
}

sub _stream {
  my ($self, $stream, $id) = @_;

  # Make sure timers are running
  $self->_recurring;

  # Connect stream with reactor
  $self->{connections}{$id}{stream} = $stream;
  weaken $stream->reactor($self->reactor)->{reactor};
  weaken $self;
  $stream->on(close => sub { $self && $self->_remove($id) });
  $stream->start;

  return $id;
}

sub _timer {
  my ($self, $method, $after, $cb) = (_instance(shift), @_);
  weaken $self;
  return $self->reactor->$method($after => sub { $self->$cb });
}

1;

=encoding utf8

=head1 NAME

L<Mojo::IOLoop> fork

=cut
