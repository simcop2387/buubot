use Bot::BB3::Roles::PasteBot;

sub {
	my( $said, $pm ) = @_;

	my $id = Bot::BB3::Roles::PasteBot->insert_paste( $said->{name}, "IRC Insert", $said->{body} );

	my $main_conf = $pm->get_main_conf;
	my $url = $main_conf->{roles}->{pastebot}->{alias_url};

	print "Added new paste as $id.";
	if( $url ) { 
		print " You can probably view it at $url/paste/$id";
	}
}

__DATA__
add_paste <content>. Inserts the text it receives as a new paste and displays the paste_id for that paste.
