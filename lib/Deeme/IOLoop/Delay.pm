package Deeme::IOLoop::Delay;
use Deeme -base;

use Deeme::IOLoop;
use Deeme::Util;
use Hash::Util::FieldHash 'fieldhash';

has ioloop => sub { Deeme::IOLoop->singleton };

fieldhash my %REMAINING;

sub begin {
  my ($self, $offset, $len) = @_;
  $self->{pending}++;
  my $id = $self->{counter}++;
  return sub { $self->_step($id, $offset // 1, $len, @_) };
}

sub data { Deeme::Util::_stash(data => @_) }

sub pass { $_[0]->begin->(@_) }

sub remaining {
  my $self = shift;
  return $REMAINING{$self} //= [] unless @_;
  $REMAINING{$self} = shift;
  return $self;
}

sub steps {
  my $self = shift->remaining([@_]);
  $self->ioloop->next_tick($self->begin);
  return $self;
}

sub wait {
  my $self = shift;
  return if $self->ioloop->is_running;
  $self->once(error => \&_die);
  $self->once(finish => sub { shift->ioloop->stop });
  $self->ioloop->start;
}

sub _die { $_[0]->has_subscribers('error') ? $_[0]->ioloop->stop : die $_[1] }

sub _step {
  my ($self, $id, $offset, $len) = (shift, shift, shift, shift);

  $self->{args}[$id]
    = [@_ ? defined $len ? splice @_, $offset, $len : splice @_, $offset : ()];
  return $self if $self->{fail} || --$self->{pending} || $self->{lock};
  local $self->{lock} = 1;
  my @args = map {@$_} @{delete $self->{args}};

  $self->{counter} = 0;
  if (my $cb = shift @{$self->remaining}) {
    eval { $self->$cb(@args); 1 }
      or (++$self->{fail} and return $self->remaining([])->emit(error => $@));
  }

  return $self->remaining([])->emit(finish => @args) unless $self->{counter};
  $self->ioloop->next_tick($self->begin) unless $self->{pending};
  return $self;
}

1;

=encoding utf8

=head1 NAME

L<Mojo::IOLoop::Delay> fork

=cut