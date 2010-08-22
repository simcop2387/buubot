package Bot::BB3::Plugin::LinkMatcher;

use DBI;
use warnings;
use strict;

my %seen;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'linkmatcher';
	$self->{opts}->{handler} = 1;

	return $self;
}


sub handle
{
	my( $self, $said, $pm ) = @_;
	
	unless( $said->{body} =~ m{(http://\S+)[.;]?} or $said->{body} =~ m{(www\.\S+)[.;]?} ) {
		return;
	}
	my $link = $1;

	my $dbh = DBI->connect( "dbi:SQLite:dbname=var/irclinks.db","","" )
		or return;
	
	$dbh->do( "INSERT INTO irclinks (time_inserted,nick,channel,uri) VALUES (?,?,?,?)",
		undef,
		time,
		$said->{name},
		$said->{channel},
		$link,
	);

	return;
}

"Bot::BB3::Plugin::LinkMatcher";
