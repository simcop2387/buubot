package Bot::BB3::Plugin::Factoids;
use DBI;
use DBD::SQLite;
use POE::Component::IRC::Common qw/l_irc/;
use Text::Soundex qw/soundex/;
use strict;

my $COPULA = join '|', qw/is are was isn't were being am/, "to be", "will be", "has been", "have been", "shall be", "can has", "wus liek", "iz liek", "used to be";
my $COPULA_RE = qr/\b(?:$COPULA)\b/i;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'factoids'; # Shouldn't matter since we aren't a command
	$self->{opts} = {
		command => 1,
		#handler => 1,
	};
	$self->{aliases} = [ qw/fact call/ ];

	return $self;
}

sub dbh { 
	my( $self ) = @_;
	
	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = $self->{dbh} = DBI->connect(
		"dbi:SQLite:dbname=var/factoids.db",
		"",
		"",
		{ RaiseError => 1, PrintError => 0 }
	);

	return $dbh;
}

sub postload {
	my( $self, $pm ) = @_;


	my $sql = "CREATE TABLE factoid (
		factoid_id INTEGER PRIMARY KEY AUTOINCREMENT,
		original_subject VARCHAR(100),
		subject VARCHAR(100),
		copula VARCHAR(25),
		predicate TEXT,
		author VARCHAR(100),
		modified_time INTEGER,
		soundex VARCHAR(4),
		compose_macro CHAR(1) DEFAULT '0'
	)"; # Stupid lack of timestamp fields

	$pm->create_table( $self->dbh, "factoid", $sql );

	delete $self->{dbh}; # UGLY HAX GO.
	                     # Basically we delete the dbh we cached so we don't fork
											 # with one active
}


# This whole code is a mess.
# Essentially we need to check if the user's text either matches a 
# 'store command' such as "subject is predicate" or we need to check
# if it's a retrieve command such as "foo" or if it's a retrieve sub-
# command such as "forget foo"
# Need to add "what is foo?" support...
sub command {
	my( $self, $said, $pm ) = @_;

	return unless $said->{body} =~ /\S/; #Try to prevent "false positives"
	
	my $call_only = $said->{command_match} eq "call";

	my $subject = $said->{body};
	
	if( !$call_only and $subject =~ /\s+$COPULA_RE\s+/ ) { 
		my @ret = $self->store_factoid( $said->{name}, $said->{body} ); 

		return( 'handled', "Failed to store $said->{body}" )
			unless @ret;

		return( 'handled', "Stored @ret" );
	}
	else {
		my $commands_re = join '|', qw/search relearn learn forget revisions literal revert/;
			$commands_re = qr/$commands_re/;

		my $fact_string;

		if( !$call_only && $subject =~ s/^\s*($commands_re)\s+// ) {
			my( $cmd_name ) = "get_fact_$1";
			$fact_string = $self->$cmd_name($subject, $said->{name});
		}
		else {
			$fact_string = $self->get_fact( $pm, $said, $subject, $said->{name}, $call_only );
		}
		if( $fact_string ) {
			return( 'handled', $fact_string );
		}
		else {
			return;
		}
	}
}

sub _clean_subject {
	my( $subject ) = @_;

	$subject =~ s/^\s+//;
	$subject =~ s/\s+$//;
	$subject =~ s/\s+/ /g;
	$subject =~ s/[^\w\s]//g;
	$subject = lc $subject;

	return $subject;
}

sub _clean_subject_func { # for parametrized macros
	my($subject, $variant) = @_;
	my( $key, $arg );

	if ($variant) {
		$subject =~ /\A\s*(\S+(?:\s+\S+)?)(?:\s+(.*))?\z/s or return;
		
		( $key, $arg ) = ( $1, $2 );

	} else {
		$subject =~ /\A\s*(\S+)(?:\s+(.*))?\z/s or return;

		( $key, $arg ) = ( $1, $2 );
	}
	$key =~ s/[^\w\s]//g;

	return $key, $arg;
}

sub store_factoid {
	my( $self, $author, $body ) = @_;


	return unless $body =~ /^(?:\S+[:,])?\s*(.+?)\s+($COPULA_RE)\s+(.+)$/s;
	my( $subject, $copula, $predicate ) = ($1,$2,$3);
	my $compose_macro = 0;

	if( $subject =~ s/^\s*\@?macro\b\s*// ) { $compose_macro = 1; }
	elsif( $subject =~ s/^\s*\@?func\b\s*// ) { $compose_macro = 2; }
	elsif( $predicate =~ s/^\s*also\s+// ) {
		my $fact = $self->_db_get_fact( _clean_subject( $subject ), $author );
		
		$predicate = $fact->{predicate} . " " .  $predicate;
	}
	
	return unless
		$self->_insert_factoid( $author, $subject, $copula, $predicate, $compose_macro );

	return( $subject, $copula, $predicate );
}

sub _insert_factoid {
	my( $self, $author, $subject, $copula, $predicate, $compose_macro ) = @_;
	my $dbh = $self->dbh;

	warn "Attempting to insert factoid: type $compose_macro";

	my $key;
	if ( $compose_macro == 2 ) {
		($key, my $arg) = _clean_subject_func($subject, 1);
		warn "*********************** GENERATED [$key] FROM [$subject] and [$arg]\n";

		$arg =~ /\S/ 
			and return;
	}
	else {
		$key = _clean_subject( $subject );
	}
	return unless $key =~ /\S/;

	$dbh->do( "INSERT INTO factoid 
		(original_subject,subject,copula,predicate,author,modified_time,soundex,compose_macro)
		VALUES (?,?,?,?,?,?,?,?)",
		undef,
		$key,
		$subject,
		$copula,
		$predicate,
		l_irc($author),
		time,
		soundex($key),
		$compose_macro || 0,
	);

	return 1;
}

sub get_fact_forget {
	my( $self, $subject, $name ) = @_;

	warn "===TRYING TO FORGET [$subject] [$name]\n";

	$self->_insert_factoid( $name, $subject, "is", " ", 0 );

	return "Forgot $subject";
}

sub _fact_literal_format {
	my($r) = @_;
	("","macro ","func ")[$r->{compose_macro}] . 
		"$r->{subject} $r->{copula} $r->{predicate}";
}

sub get_fact_revisions {
	my( $self, $subject, $name ) = @_;
	my $dbh = $self->dbh;

	my $revisions = $dbh->selectall_arrayref(
		"SELECT factoid_id, subject, copula, predicate, author, compose_macro 
			FROM factoid
			WHERE original_subject = ?
			ORDER BY modified_time DESC
		", # newest revision first
		{Slice=>{}},
		_clean_subject( $subject ),
	);

	my $ret_string = join " ", map {
		"[$_->{factoid_id} by $_->{author}: " . _fact_literal_format($_) . "]";
	} @$revisions;

	return $ret_string;
}

sub get_fact_literal {
	my( $self, $subject, $name ) = @_;

	my $fact = $self->_db_get_fact( _clean_subject( $subject ), $name );

	return _fact_literal_format($fact);
}

sub get_fact_revert {
	my( $self, $subject, $name ) = @_;
	my $dbh = $self->dbh;

	$subject =~ s/^\s*(\d+)\s*$//
		or return "Failed to match revision format";
	my $rev_id = $1;

	my $fact_rev = $dbh->selectrow_hashref( 
	"SELECT subject, copula, predicate, compose_macro
		FROM factoid
		WHERE factoid_id = ?",
		undef,
		$rev_id
	);

	return "Bad revision id" unless $fact_rev and $fact_rev->{subject}; # Make sure it's valid..

	#                        subject, copula, predicate
	$self->_insert_factoid( $name, @$fact_rev{qw"subject copula predicate compose_macro"});

	return "Reverted $fact_rev->{subject} to revision $rev_id";
}

sub get_fact_learn {
	my( $self, $body, $name ) = @_;


		$body =~ s/^\s*learn\s+//;
		my( $subject, $predicate ) = split /\s+as\s+/, $body, 2;

		#my @ret = $self->store_factoid( $name, $said->{body} ); 
		$self->_insert_factoid( $name, $subject, 'is', $predicate, 0 );

		return "Stored $subject as $predicate";
}
*get_fact_relearn = \&get_fact_learn; #Alias..

sub get_fact_search {
	my( $self, $body, $name ) = @_;

	my $results = $self->dbh->selectall_arrayref(
		"SELECT subject,copula,predicate 
		FROM factoid
		WHERE subject like ?
		GROUP BY subject", # Group by magically returns the right row first. I dunno.
		{Slice => {}},
		"%$body%",
	);

	if( $results and @$results ) {
		my $ret_string;
		for( @$results ) {
			$ret_string .= "[" . _fact_literal_format($_) . "] ";
		}

		return $ret_string;
	}
	else {
		return "No matches."
	}
}

sub get_fact {
	my( $self, $pm, $said, $subject, $name, $call_only ) = @_;

	return $self->basic_get_fact( $pm, $said, $subject, $name, $call_only );
}	

sub _db_get_fact {
	my( $self, $subj, $name ) = @_;
	
	my $dbh = $self->dbh;
	my $fact = $dbh->selectrow_hashref( "
			SELECT factoid_id, subject, copula, predicate, author, modified_time, compose_macro
			FROM factoid 
			WHERE original_subject = ?
			ORDER BY factoid_id DESC
		", 
		undef,
		$subj, 
	);
	
	return $fact;
}


sub basic_get_fact {
	my( $self, $pm, $said, $subject, $name, $call_only ) = @_;

	my ($fact, $key, $arg);
	my $key = _clean_subject($subject, 1);
	my $fact;
	if( !$call_only ) {
		$fact = $self->_db_get_fact($key, $name);
	}
	# Attempt to determine if our subject matches a previously defined 
	# 'macro' or 'func' type factoid.
	# I suspect it won't match two word function names now.

	for my $variant (0, 1) {
		if (!$fact) {
			($key, $arg) = _clean_subject_func($subject, $variant);
			$fact = $self->_db_get_fact($key, $name, 1);
		}
	}

	if( $fact->{predicate} =~ /\S/ ) {
		if( $fact->{compose_macro} ) {
			my $plugin = $pm->get_plugin("compose");
			
			local $said->{macro_arg} = $arg;
			local $said->{body} = $fact->{predicate};
			local $said->{addressed} = 1; # Force addressed to circumvent restrictions? May not be needed!

			return $plugin->command($said,$pm);
		}
		else {
			return "$fact->{subject} $fact->{copula} $fact->{predicate}";
		}
	}
	else { 
		my $soundex = soundex( _clean_subject($subject, 1) );

		my $matches = $self->_soundex_matches( $soundex );
		
		if( $matches and @$matches ) {
			return "No factoid found. Did you mean one of these: " . join " ", map "[$_]", @$matches;
		}
		else {
			return;
		}
	}
}

sub _soundex_matches {
	my( $self, $soundex ) = @_;
	my $dbh = $self->dbh;

	my $rows = $dbh->selectall_arrayref(
		"SELECT factoid_id,subject,predicate FROM factoid WHERE soundex = ? GROUP BY subject LIMIT 10",
		undef,
		$soundex
	);

	return [ map $_->[1], grep $_->[2] =~ /\S/, @$rows ];
}


"Bot::BB3::Plugin::Factoids";
__DATA__
Learn or retrieve persistent factoids. "foo is bar" to store. "foo" to retrieve. try "forget foo" or "revisions foo" or "literal foo" or "revert $REV_ID" too. "macro foo is [echo bar]" or "func foo is [echo bar [arg]]" for compose macro factoids. The factoids/fact/call keyword is optional except in compose. Search <subject> to search for factoids that match.
