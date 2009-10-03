use Bot::BB3::Roles::PasteBot;

sub {
	my( $said, $pm ) = @_;

	$said->{body} =~ /(\d+)\D*$/
		or do { print "Failed to find a paste id."; return };

	my $paste_id = $1;

	my $paste_record = Bot::BB3::Roles::PasteBot->get_paste( $paste_id );

	print $paste_record->{paste};
}


__DATA__
show_paste <paste_id>. Displays the contents of the paste_id. Try it in different contexts such as dcc or private message!
