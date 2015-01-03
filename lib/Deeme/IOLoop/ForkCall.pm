package Deeme::IOLoop::ForkCall;

use Deeme -base;

our $VERSION = '0.15';
$VERSION = eval $VERSION;

use Deeme::IOLoop;
use IO::Pipely 'pipely';
use POSIX ();
use Scalar::Util ();

use Perl::OSType 'is_os_type';
use constant IS_WINDOWS => is_os_type('Windows');
use constant IS_CYGWIN  => $^O eq 'cygwin';

use Exporter 'import';
our @EXPORT_OK = qw/fork_call/;

has 'ioloop'       => sub { Deeme::IOLoop->singleton };
has 'serializer'   => sub { require Storable; \&Storable::freeze };
has 'deserializer' => sub { require Storable; \&Storable::thaw   };
has 'weaken'       => 0;

sub run {
  my ($self, @args) = @_;
  my $delay = $self->ioloop->delay(sub{ $self->_run(@args) });
  $delay->catch(sub{ $self->emit( error => $_[1] ) });
  return $self;
}

sub _run {
  my ($self, $job) = (shift, shift);
  my ($args, $cb);
  $args = shift if @_ and ref $_[0] eq 'ARRAY';
  $cb   = shift if @_;

  my ($r, $w) = pipely;

  my $child = fork;
  die "Failed to fork: $!" unless defined $child;

  if ($child == 0) {
    # child

    # cleanup running loops
    $self->ioloop->reset;
    delete $self->{ioloop}; # not sure this is needed
    Deeme::IOLoop->reset;
    close $r;

    my $serializer = $self->serializer;

    local $@;
    my $res = eval {
      local $SIG{__DIE__};
      $serializer->([undef, $job->(@$args)]);
    };
    $res = $serializer->([$@]) if $@;

    _send($w, $res);

    # attempt to generalize exiting from child cleanly on all platforms
    # adapted from POE::Wheel::Run mostly
    eval { POSIX::_exit(0) } unless IS_WINDOWS;
    eval { CORE::kill KILL => $$ };
    exit 0;

  } else {
    # parent
    close $w;
    my $parent = $$;
    $self->emit( spawn => $child );

    my $stream = Deeme::IOLoop::Stream->new($r)->timeout(0);
    $self->ioloop->stream($stream);

    my $buffer = '';
    $stream->on( read  => sub { $buffer .= $_[1] } );

    Scalar::Util::weaken($self) if $self->weaken;

    $stream->on( error => sub { $self->emit( error => $_[1] ) if $self } );

    my $deserializer = $self->deserializer;
    $stream->on( close => sub {
      return unless $$ == $parent; # not my stream!
      local $@;

      # attempt to deserialize, emit error and return early
      my $res = eval { $deserializer->($buffer) };
      if ($@) {
        $self->emit( error => $@ ) if $self;
        waitpid $child, 0;
        return;
      }

      # call the callback, emit error if it fails
      eval { $self->$cb(@$res) if $cb };
      $self->emit( error => $@ ) if $@ and $self;

      # emit the finish event, emit error if IT fails
      eval { $self->emit( finish => @$res ) if $self };
      $self->emit( error => $@ ) if $@ and $self;

      waitpid $child, 0;
    });
  }
}

## functions

sub fork_call (&@) {
  my $job = shift;
  my $cb  = pop;
  return __PACKAGE__->new->run($job, \@_, sub {
    # local $_ = shift; #TODO think about this
    shift;
    local $@ = shift;
    $cb->(@_);
  });
}

sub _send {
  my ($h, $data) = @_;
  if (IS_WINDOWS || IS_CYGWIN) {
    my $len = length $data;
    my $written = 0;
    while ($written < $len) {
      my $count = syswrite $h, $data, 65536, $written;
      unless (defined $count) { warn $!; last }
      $written += $count;
    }
  } else {
    warn $! unless defined syswrite $h, $data;
  }
}

1;

=encoding utf8

=head1 NAME

L<Mojo::IOLoop::ForkCall> fork

=cut