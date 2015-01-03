package Deeme::Reactor::EV;
use Deeme::Obj 'Deeme::Reactor::Poll';

use EV 4.0;
use Scalar::Util 'weaken';

my $EV;

sub CLONE { die "EV does not work with ithreads.\n" }

sub DESTROY { undef $EV }

sub again { shift->{timers}{shift()}{watcher}->again }

sub is_running { !!EV::depth }

# We have to fall back to Deeme::Reactor::Poll, since EV is unique
sub new { $EV++ ? Deeme::Reactor::Poll->new : shift->SUPER::new }

sub one_tick { EV::run(EV::RUN_ONCE) }

sub recurring { shift->_timer(1, @_) }

sub start {EV::run}

sub stop { EV::break(EV::BREAK_ALL) }

sub timer { shift->_timer(0, @_) }

sub watch {
  my ($self, $handle, $read, $write) = @_;

  my $mode = 0;
  $mode |= EV::READ  if $read;
  $mode |= EV::WRITE if $write;

  my $fd = fileno $handle;
  my $io = $self->{io}{$fd};
  if ($mode == 0) { delete $io->{watcher} }
  elsif (my $w = $io->{watcher}) { $w->set($fd, $mode) }
  else {
    weaken $self;
    $io->{watcher} = EV::io($fd, $mode, sub { $self->_io($fd, @_) });
  }

  return $self;
}

sub _io {
  my ($self, $fd, $w, $revents) = @_;
  my $io = $self->{io}{$fd};
  $self->_sandbox('Read', $io->{cb}, 0) if EV::READ & $revents;
  $self->_sandbox('Write', $io->{cb}, 1)
    if EV::WRITE & $revents && $self->{io}{$fd};
}

sub _timer {
  my ($self, $recurring, $after, $cb) = @_;
  $after ||= 0.0001 if $recurring;

  my $id = $self->SUPER::_timer(0, 0, $cb);
  weaken $self;
  $self->{timers}{$id}{watcher} = EV::timer(
    $after => $after => sub {
      my $timer = $self->{timers}{$id};
      delete delete($self->{timers}{$id})->{watcher} unless $recurring;
      $self->_sandbox("Timer $id", $timer->{cb});
    }
  );

  return $id;
}

1;
=encoding utf8

=head1 NAME

L<Mojo::Reactor::EV> fork

=cut