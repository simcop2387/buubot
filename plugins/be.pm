# be plugin for bb3

use strict;

sub {
	my($said, $pm) = @_;
	my($person, $search_sep, $search_term) = 
		@{$said->{recommended_args}};
	
	my $quotedir = $pm->get_main_conf->{be}->{quotes_dir} || "/dev/null";
	-d $quotedir or 
		die "error: quote directory does not exist, check etc/bb3.conf";

	$person = lc $person;
	$person =~ s/\.\.//g;
	$person =~ /[^a-z0-9_'-]/ and do { print "Sorry, $person is an invalid name. \n"; return; };

	open my $fh, "<", "$quotedir/$person" or do { print "Sorry, couldn't find a quotefile for $person.  Try the `bels' command to list quotefiles.\n"; return; };

	if( $search_sep eq '=~' and length $search_term )
	{
		my @quotes;
		while(<$fh>)
		{
			if( /\Q$search_term/i )
			{
				push @quotes, $_;
			}
		}

		if( @quotes )
		{
			print $quotes[rand @quotes];
		}
		else
		{
			print "Sorry, no quotes matched the search term: $search_term";
		}
	}
	else
	{
		my $line;

		while(<$fh>)
		{
			if( rand($.) < 1 )
			{
				$line = $_;
			}
		}

		print $line;
	}
}
__DATA__
get a fortune cookie from a local quotes file; usage: be name; see also bels
