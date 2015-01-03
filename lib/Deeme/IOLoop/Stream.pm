package Deeme::IOLoop::Stream;
use Deeme -base;

use Errno qw(EAGAIN ECONNRESET EINTR EPIPE EWOULDBLOCK);
use Deeme::IOLoop;
use Scalar::Util 'weaken';

has reactor => sub { Deeme::IOLoop->singleton->reactor };

sub DESTROY { shift->close }

sub close {
  my $self = shift;

  return unless my $reactor = $self->reactor;
  return unless my $handle  = delete $self->timeout(0)->{handle};
  $reactor->remove($handle);
  close $handle;
  $self->emit('close');
}

sub close_gracefully {
  my $self = shift;
  return $self->{graceful} = 1 if $self->is_writing;
  $self->close;
}

sub handle { shift->{handle} }

sub is_readable {
  my $self = shift;
  $self->_again;
  return $self->{handle} && $self->reactor->is_readable($self->{handle});
}

sub is_writing {
  my $self = shift;
  return undef unless $self->{handle};
  return !!length($self->{buffer}) || $self->has_subscribers('drain');
}

sub new { shift->SUPER::new(handle => shift, buffer => '', timeout => 15) }

sub start {
  my $self = shift;

  # Resume
  my $reactor = $self->reactor;
  return $reactor->watch($self->{handle}, 1, $self->is_writing)
    if delete $self->{paused};

  weaken $self;
  my $cb = sub { pop() ? $self->_write : $self->_read };
  $reactor->io($self->timeout($self->{timeout})->{handle} => $cb);
}

sub stop {
  my $self = shift;
  $self->reactor->watch($self->{handle}, 0, $self->is_writing)
    unless $self->{paused}++;
}

sub steal_handle {
  my $self = shift;
  $self->reactor->remove($self->{handle});
  return delete $self->{handle};
}

sub timeout {
  my $self = shift;

  return $self->{timeout} unless @_;

  my $reactor = $self->reactor;
  $reactor->remove(delete $self->{timer}) if $self->{timer};
  return $self unless my $timeout = $self->{timeout} = shift;
  weaken $self;
  $self->{timer}
    = $reactor->timer($timeout => sub { $self->emit('timeout')->close });

  return $self;
}

sub write {
  my ($self, $chunk, $cb) = @_;

  $self->{buffer} .= $chunk;
  if ($cb) { $self->once(drain => $cb) }
  elsif (!length $self->{buffer}) { return $self }
  $self->reactor->watch($self->{handle}, !$self->{paused}, 1)
    if $self->{handle};

  return $self;
}

sub _again { $_[0]->reactor->again($_[0]{timer}) if $_[0]{timer} }

sub _error {
  my $self = shift;

  # Retry
  return if $! == EAGAIN || $! == EINTR || $! == EWOULDBLOCK;

  # Closed
  return $self->close if $! == ECONNRESET || $! == EPIPE;

  # Error
  $self->emit(error => $!)->close;
}

sub _read {
  my $self = shift;
  my $read = $self->{handle}->sysread(my $buffer, 131072, 0);
  return $self->_error unless defined $read;
  return $self->close if $read == 0;
  $self->emit(read => $buffer)->_again;
}

sub _write {
  my $self = shift;

  my $handle = $self->{handle};
  if (length $self->{buffer}) {
    my $written = $handle->syswrite($self->{buffer});
    return $self->_error unless defined $written;
    $self->emit(write => substr($self->{buffer}, 0, $written, ''))->_again;
  }

  $self->emit('drain') if !length $self->{buffer};
  return               if $self->is_writing;
  return $self->close  if $self->{graceful};
  $self->reactor->watch($handle, !$self->{paused}, 0) if $self->{handle};
}

1;

=encoding utf8

=head1 NAME

L<Mojo::IOLoop::Stream> fork

=cut