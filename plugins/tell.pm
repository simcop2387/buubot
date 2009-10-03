package Bot::BB3::Plugin::Tell;
use POE::Component::IRC::Common qw/l_irc/;
use DBI;
use DBD::SQLite;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = 'tell';
	$self->{opts} = {
		command => 1,
		handler => 1,
		
	};

	return $self;
}

sub dbh {
	my( $self ) = @_;

	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}


	my $dbh = $self->{dbh} = DBI->connect( 
		"dbi:SQLite:dbname=var/tell.db", 
		"",
		"",
		{ PrintError => 0, RaiseError => 1 } 
	);

	return $dbh;
}

sub postload {
	my( $self, $pm ) = @_;
	

	my $sql = "CREATE TABLE tell_record (
		tell_record_id INTEGER PRIMARY KEY AUTOINCREMENT,
		author VARCHAR(50),
		target VARCHAR(50),
		message VARCHAR(250)
	);";

	$pm->create_table( $self->dbh, "tell_record", $sql );

	delete $self->{dbh}; # UGLY HAX GO.
	                     # Basically we delete the dbh we cached so we don't fork
											 # with one active
}

sub command {
	my( $self, $said, $pm ) = @_;

	return $self->_command_mode( $said, $pm );
}

sub handle {
	my( $self, $said, $pm ) = @_;

	return $self->_check_messages( $said, $pm );
}

sub _command_mode {
	my( $self, $said, $pm ) = @_;
	my $msg = $said->{body};

	$msg =~ s/^\s*([-A-z0-9]+)\s*// or
		return('handled', "Tell to who? I don't understand.");
	my $target = $1;

	if( l_irc($target) eq l_irc($said->{name}) ) {
		return( 'handled', 'Can\'t save messages for yourself!' );
	}

	local $@;
	eval {
		$self->dbh->do( "INSERT INTO tell_record (author,target,message) VALUES (?,?,?)",
			undef,
			$said->{name},
			l_irc( $target ),
			$msg,
		);
	};

	if( $@ ) {
		warn "Whups, tell plugin failed: $@\n";
	}
	else {
		return( 'handled', "Saved message for $target." );
	}

	return( '', '' );
}

sub _check_messages {
	my( $self, $said, $pm ) = @_;

	local $@;
	my $tells;
	eval {
		$tells = $self->dbh->selectall_arrayref( "SELECT * FROM tell_record WHERE target = ?",
			{ Slice => {} },
			l_irc( $said->{name} ),
		);

		$self->dbh->do( "DELETE FROM tell_record WHERE target = ?", undef, l_irc( $said->{name} ) );
	};

	if( $@ ) {
		warn "Whups, tell plugin failed: $@\n";
	}

	if( @$tells ) {
		my %grouping;
		for( @$tells ) {
			push @{ $grouping{ $_->{author} } }, $_->{message};
		}
		
		my $msg;
		for( keys %grouping ) {
			$msg .= "$said->{name}: $_ wanted you to know: " . join " also ", @{ $grouping{$_} };
		}

		return $msg;
	}

	return '' ;
}

"Bot::BB3::Plugin::Tell";

__DATA__
Save a message for a specified user. Syntax, tell user Hey, I just missed you.
