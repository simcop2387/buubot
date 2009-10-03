sub {
	my( $said, $pm ) = @_;

	push @{ $said->{special_commands} }, [
		pci_topic => $said->{channel} => $said->{body}
	];

	print "Changing the topic to $said->{body} in $said->{channel}";
}

__DATA__
Attempts to change the topic in the current channel. Typically requires op/superuser permissions for the user as well as operator permissions for the bot.
