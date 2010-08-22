use strict;
use HTML::TreeBuilder;
use LWP::Simple qw/get/;

sub {
	my( $said ) = @_;

	my $location = $said->{body};

	my $resp = get( "http://thefuckingweather.com/?zipcode=$location" );

	my $tree = HTML::TreeBuilder->new_from_content( $resp );

	my $body = $tree->look_down( _tag => 'body' );

	my @elements = $body->content_list;

	my $location = $elements[0];
	my $weather = ($elements[1]->content_list)[0];
	my $remark = $tree->look_down( id => 'remark' );

	print $location->as_text;
	print " ";
	print $weather->as_text;
	print " ";
	print '(', $remark->as_text, ')';
}
