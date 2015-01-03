package Deeme::Exception;
use Deeme::Obj -base;
use overload bool => sub {1}, '""' => sub { shift->to_string }, fallback => 1;

use Scalar::Util 'blessed';

has [qw(frames line lines_before lines_after)] => sub { [] };
has message => 'Exception!';
has 'verbose';

sub new {
  my $self = shift->SUPER::new;
  return @_ ? $self->_detect(@_) : $self;
}

sub throw { die shift->new->trace(2)->_detect(@_) }

sub to_string {
  my $self = shift;

  return $self->message unless $self->verbose;
  my $str = $self->message ? $self->message : '';

  # Before
  $str .= $_->[0] . ': ' . $_->[1] . "\n" for @{$self->lines_before};

  # Line
  $str .= ($self->line->[0] . ': ' . $self->line->[1] . "\n")
    if $self->line->[0];

  # After
  $str .= $_->[0] . ': ' . $_->[1] . "\n" for @{$self->lines_after};

  return $str;
}

sub trace {
  my ($self, $start) = @_;
  $start //= 1;
  my @frames;
  while (my @trace = caller($start++)) { push @frames, \@trace }
  return $self->frames(\@frames);
}

sub _append {
  my ($stack, $line) = @_;
  chomp $line;
  push @$stack, $line;
}

sub _context {
  my ($self, $num, $lines) = @_;

  # Line
  return unless defined $lines->[0][$num - 1];
  $self->line([$num]);
  _append($self->line, $_->[$num - 1]) for @$lines;

  # Before
  for my $i (2 .. 6) {
    last if ((my $previous = $num - $i) < 0);
    unshift @{$self->lines_before}, [$previous + 1];
    _append($self->lines_before->[0], $_->[$previous]) for @$lines;
  }

  # After
  for my $i (0 .. 4) {
    next if ((my $next = $num + $i) < 0);
    next unless defined $lines->[0][$next];
    push @{$self->lines_after}, [$next + 1];
    _append($self->lines_after->[-1], $_->[$next]) for @$lines;
  }
}

sub _detect {
  my ($self, $msg, $files) = @_;

  return $msg if blessed $msg && $msg->isa('Deeme::Exception');
  $self->message($msg);

  # Extract file and line from message
  my @trace;
  while ($msg =~ /at\s+(.+?)\s+line\s+(\d+)/g) { unshift @trace, [$1, $2] }

  # Extract file and line from stacktrace
  my $first = $self->frames->[0];
  push @trace, [$first->[1], $first->[2]] if $first;

  # Search for context in files
  for my $frame (@trace) {
    next unless -r $frame->[0] && open my $handle, '<:utf8', $frame->[0];
    $self->_context($frame->[1], [[<$handle>]]);
    return $self;
  }

  # More context
  $self->_context($trace[-1][1], [map { [split "\n"] } @$files]) if $files;

  return $self;
}

1;
=encoding utf8

=head1 NAME

L<Mojo::Exception> fork

=cut