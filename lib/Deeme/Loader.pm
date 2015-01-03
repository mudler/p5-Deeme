package Deeme::Loader;
use Deeme::Obj -base;

use File::Basename 'fileparse';
use File::Spec::Functions qw(catdir catfile splitdir);
use Deeme::Exception;
use Deeme::Utils qw(b64_decode class_to_path);

my (%BIN, %CACHE);

sub data { $_[1] ? $_[2] ? _all($_[1])->{$_[2]} : _all($_[1]) : undef }

sub is_binary { keys %{_all($_[1])} ? !!$BIN{$_[1]}{$_[2]} : undef }

sub load {
  my ($self, $module) = @_;

  # Check module name
  return 1 if !$module || $module !~ /^\w(?:[\w:']*\w)?$/;

  # Load
  return undef if $module->can('new') || eval "require $module; 1";

  # Exists
  return 1 if $@ =~ /^Can't locate \Q@{[class_to_path $module]}\E in \@INC/;

  # Real error
  return Deeme::Exception->new($@);
}

sub search {
  my ($self, $ns) = @_;

  my %modules;
  for my $directory (@INC) {
    next unless -d (my $path = catdir $directory, split(/::|'/, $ns));

    # List "*.pm" files in directory
    opendir(my $dir, $path);
    for my $file (grep /\.pm$/, readdir $dir) {
      next if -d catfile splitdir($path), $file;
      $modules{"${ns}::" . fileparse $file, qr/\.pm/}++;
    }
  }

  return [keys %modules];
}

sub _all {
  my $class = shift;

  return $CACHE{$class} if $CACHE{$class};
  my $handle = do { no strict 'refs'; \*{"${class}::DATA"} };
  return {} unless fileno $handle;
  seek $handle, 0, 0;
  my $data = join '', <$handle>;

  # Ignore everything before __DATA__ (some versions seek to start of file)
  $data =~ s/^.*\n__DATA__\r?\n/\n/s;

  # Ignore everything after __END__
  $data =~ s/\n__END__\r?\n.*$/\n/s;

  # Split files
  (undef, my @files) = split /^@@\s*(.+?)\s*\r?\n/m, $data;

  # Find data
  my $all = $CACHE{$class} = {};
  while (@files) {
    my ($name, $data) = splice @files, 0, 2;
    $all->{$name} = $name =~ s/\s*\(\s*base64\s*\)$//
      && ++$BIN{$class}{$name} ? b64_decode($data) : $data;
  }

  return $all;
}

1;
=encoding utf8

=head1 NAME

L<Mojo::Loader> fork

=cut
