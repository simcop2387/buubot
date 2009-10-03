use Math::Pari;
use Scalar::Util qw/reftype/;
use Data::Dumper;
use lib 'deps/';
use strict;

use Storable qw/retrieve/;

#my $units = $VAR1;
my $units = retrieve "var/full_units.storable";
die unless $units and ref $units;

sub convert_pari {
	my( $ref ) = @_;

	my $pari_str = $ref->{pari_str};
	$ref->{pari} = PARI( $pari_str );
}

sub converter {
	my( $ref ) = @_;

	if( ref $ref eq 'Math::Farnsworth::Value::Pari' ) {
		convert_pari( $ref );
	}

	if( reftype $ref eq 'HASH' ) {
		converter( $_ ) for values %$ref;
	}
	elsif( reftype $ref eq 'ARRAY' ) {
		converter($_) for @$ref;
	}

}


converter( $units );

# Delete the farns modules to try to get them to be reloaded.
BEGIN { 
	for( keys %INC ) {
		if( /Math.Farnsworth/ ) {
			warn "RELOADING, deleting $_\n";
			delete $INC{$_};
		}
	}
}
use Math::Farnsworth;

my $m = Math::Farnsworth->new( qw/Functions::Standard Functions::StdMath Functions::GoogleTranslate/ );
$m->{eval}->{units} = $units;

#print $m->runString("32 Dong -> dollars"), "\n";


sub {
	my( $said ) = @_;

	print $m->runString( $said->{body} );
}

