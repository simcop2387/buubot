package Bot::BB3::Plugin::Pastebin;

use LWP::Simple qw/get/;
use IPC::Open2;
use warnings;
use strict;

my %seen;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'pastebin';
	$self->{opts}->{handler} = 1;

	return $self;
}


sub handle
{
	my( $self, $said, $pm ) = @_;

	local $SIG{CHLD} = 'IGNORE';

	return unless 
		my @matches
		=
		$said->{body} 
		=~ 
		m{((?:\w+.)?pastebin.(?:com|org))/(\w+)|((?:\w+.)?pastebin.ca)/(\d+)|(rafb.net)/p/results/(\w+).html|(phpfi).com/(\d+)};

	my( $site, $id );
	for(0..$#matches){ if(defined $matches[$_]){ $site=$matches[$_]; $id = $matches[$_+1]; last } }
	return unless defined $site and defined $id;
	
warn "Triggered on $site/$id";
	my $key = "$site\_$id";

	if( $seen{ $key } )
	{
	warn "Previously seen..";
		return( "The paste $id has been copied to: $seen{ $key }" );
	}
	
	my $paste;
	if( $site =~ /pastebin\.(?:com|org)/ )
	{
		$paste = get("http://$site/pastebin.php?dl=$id");
	}
	
	elsif( $site =~ /pastebin\.ca/ )
	{
		$paste = get("http://$site/raw/$id");
		warn "Paste: http://$site.ca/raw/$id\n";
	}
	
	elsif( $site eq 'rafb.net' )
	{
		$paste = get("http://www.rafb.net/paste/results/$id.txt");
	}

	elsif( $site eq 'phpfi' )
	{
		$paste = get("http://phpfi.com/$id?download");
	}
	
	return unless $paste ne "";

warn "Length of fetched: ", length $paste;
	my $pid = open2 my $paster_read, my $paster_write, $^X, "/usr/local/bin/pbotutil.pl", 
		"-c", "", 
		"-u", "Auto pastebin mover", 
		"-s", "erxz", 
		"-m", "This paste was automatically retrieved from pastebin.com/$id"
	or warn "Failed to open: $!";

	print $paster_write $paste;
	close $paster_write;
	waitpid( $pid, 0 );

	my $url = <$paster_read>;

	if( kill 0, $pid ) { kill 9, $pid }

	# This skips the first line in the count.
	my $num_lines = ( $paste =~ tr/\n// ) + 1; 
	return( "The $num_lines line paste $id has been copied to $url ." );
}

"Bot::BB3::Plugin::Pastebin";
__DATA__
Just type the url of any pastebin.c{a,om} paste, the bot copies its contents to a pastebin with less ads and announces the new url.
