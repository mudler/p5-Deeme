package Deeme::Utils;
use base qw(Exporter);
use constant DEBUG => $ENV{DEBUG} || 0;
use Term::ANSIColor;                                                                                                                                                                                                                           

use B::Deparse;
use MIME::Base64 qw( encode_base64  decode_base64);
use Digest::MD5 qw(md5 md5_hex);
use Time::HiRes ();
use constant MONOTONIC => eval
    '!!Time::HiRes::clock_gettime(Time::HiRes::CLOCK_MONOTONIC())';
our @EXPORT = qw(message DEBUG info warning error);
our @EXPORT_OK = qw (_serialize _deserialize b64_decode b64_encode class_to_path _stash md5_sum steady_time);
our $deparse   = B::Deparse->new;
sub b64_decode    { decode_base64( $_[0] ) }
sub b64_encode    { encode_base64( $_[0], $_[1] ) }
sub class_to_path { join '.', join( '/', split /::|'/, shift ), 'pm' }

sub _serialize   { encode_base64( $deparse->coderef2text(shift) ); }
sub _deserialize { eval( "sub " . decode_base64(shift) ); }


sub _stash {
    my ( $name, $object ) = ( shift, shift );

    # Hash
    my $dict = $object->{$name} ||= {};
    return $dict unless @_;

    # Get
    return $dict->{ $_[0] } unless @_ > 1 || ref $_[0];

    # Set
    my $values = ref $_[0] ? $_[0] : {@_};
    @$dict{ keys %$values } = values %$values;

    return $object;
}
sub steady_time () {
    MONOTONIC
        ? Time::HiRes::clock_gettime( Time::HiRes::CLOCK_MONOTONIC() )
        : Time::HiRes::time;
}
sub md5_sum { md5_hex(@_) }


sub info {
    my $caller = caller;
    print STDERR color 'bold magenta';
    print STDERR encode_utf8( '❰ ' . $caller . ' ❱ ' );
    print STDERR color 'bold green';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

sub warning {
    print STDERR color 'bold green';
    print STDERR encode_utf8('→ ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

sub error {
    print STDERR color 'bold yellow';
    print STDERR encode_utf8('⚑ ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}
sub message {
    my $caller = caller;
    my $id     = shift;
    print STDERR color 'bold yellow';
    print STDERR encode_utf8(
        '❰ ' . $caller . ' ❱ ♦ ' . $id . ' ♦ ' );
    print STDERR color 'bold blue';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}
1;
