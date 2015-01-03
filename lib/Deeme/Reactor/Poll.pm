package Deeme::Reactor::Poll;
use Deeme::Obj 'Deeme::Reactor';

use IO::Poll qw(POLLERR POLLHUP POLLIN POLLOUT POLLPRI);
use List::Util 'min';
use Deeme::Utils qw(md5_sum steady_time);
use Time::HiRes 'usleep';

sub again {
  my $timer = shift->{timers}{shift()};
  $timer->{time} = steady_time + $timer->{after};
}

sub io {
  my ($self, $handle, $cb) = @_;
  $self->{io}{fileno $handle} = {cb => $cb};
  return $self->watch($handle, 1, 1);
}

sub is_running { !!shift->{running} }

sub one_tick {
  my $self = shift;

  # Remember state for later
  my $running = $self->{running};
  $self->{running} = 1;

  # Wait for one event
  my $i;
  my $poll = $self->_poll;
  until ($i) {

    # Stop automatically if there is nothing to watch
    return $self->stop unless keys %{$self->{timers}} || keys %{$self->{io}};

    # Calculate ideal timeout based on timers
    my $min = min map { $_->{time} } values %{$self->{timers}};
    my $timeout = defined $min ? ($min - steady_time) : 0.5;
    $timeout = 0 if $timeout < 0;

    # I/O
    if (keys %{$self->{io}}) {
      $poll->poll($timeout);
      for my $handle ($poll->handles(POLLIN | POLLPRI | POLLHUP | POLLERR)) {
        next unless my $io = $self->{io}{fileno $handle};
        ++$i and $self->_sandbox('Read', $io->{cb}, 0);
      }
      for my $handle ($poll->handles(POLLOUT)) {
        next unless my $io = $self->{io}{fileno $handle};
        ++$i and $self->_sandbox('Write', $io->{cb}, 1);
      }
    }

    # Wait for timeout if poll can't be used
    elsif ($timeout) { usleep $timeout * 1000000 }

    # Timers (time should not change in between timers)
    my $now = steady_time;
    for my $id (keys %{$self->{timers}}) {
      next unless my $t = $self->{timers}{$id};
      next unless $t->{time} <= $now;

      # Recurring timer
      if (exists $t->{recurring}) { $t->{time} = $now + $t->{recurring} }

      # Normal timer
      else { $self->remove($id) }

      ++$i and $self->_sandbox("Timer $id", $t->{cb}) if $t->{cb};
    }
  }

  # Restore state if necessary
  $self->{running} = $running if $self->{running};
}

sub recurring { shift->_timer(1, @_) }

sub remove {
  my ($self, $remove) = @_;
  return !!delete $self->{timers}{$remove} unless ref $remove;
  $self->_poll->remove($remove);
  return !!delete $self->{io}{fileno $remove};
}

sub reset { delete @{shift()}{qw(io poll timers)} }

sub start {
  my $self = shift;
  $self->{running}++;
  $self->one_tick while $self->{running};
}

sub stop { delete shift->{running} }

sub timer { shift->_timer(0, @_) }

sub watch {
  my ($self, $handle, $read, $write) = @_;

  my $mode = 0;
  $mode |= POLLIN | POLLPRI if $read;
  $mode |= POLLOUT if $write;

  my $poll = $self->_poll;
  $poll->remove($handle);
  $poll->mask($handle, $mode) if $mode != 0;

  return $self;
}

sub _poll { shift->{poll} ||= IO::Poll->new }

sub _sandbox {
  my ($self, $event, $cb) = (shift, shift, shift);
  eval { $self->$cb(@_); 1 } or $self->emit(error => "$event failed: $@");
}

sub _timer {
  my ($self, $recurring, $after, $cb) = @_;

  my $timers = $self->{timers} //= {};
  my $id;
  do { $id = md5_sum('t' . steady_time . rand 999) } while $timers->{$id};
  my $timer = $timers->{$id}
    = {cb => $cb, after => $after, time => steady_time + $after};
  $timer->{recurring} = $after if $recurring;

  return $id;
}

1;
=encoding utf8

=head1 NAME

L<Mojo::Reactor::Poll> fork

=cut