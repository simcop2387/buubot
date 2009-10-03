use LWP::Simple qw/get/;

sub {
	my( $said ) = @_;
	my $id = $said->{body};
	$id =~ s/^\s+//; $id =~ s/\s+$//;

	$id =~ s/^ITS#//;

	if( $id =~ /\D/ ) { print "Sorry, $id doesn't appear to be valid"; return; }

	my $url = "http://www.openldap.org/its/?findid=$id" ;
	my $content = get( $url );

	$content =~ /Subject: (.+?)<br>/
		or do { print "Failed to find a subject from  $url"; return };
	my $subject = $1;

	my $state;
	if( $content =~ /option value="\d+" SELECTED>(\w+)/ ) {
		$state = $1;
	}
	else {
		$state = "Undefined";
	}

	print "($state) $subject -- $url";

}
