package Bot::BB3::Roles::Web;

use Bot::BB3::Logger;
use POE;
use POE::Component::Server::SimpleHTTP;
use HTTP::Status;
use URI::Escape qw/uri_unescape/;
use HTML::Entities qw/encode_entities/;
use CGI; #Heh.
use strict;

	local $/;
	my $HTML_TEMPLATE = <DATA>;

sub new {
	my( $class, $conf, $plugin_manager ) = @_;

	my $self = bless { conf => $conf, pm => $plugin_manager }, $class;

	my $session = $self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/_start handle_request irc_links display_page plugin_output sig_DIE/ ]
		]
	);

	return $self;
}

sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];
	my $conf = $self->{conf};

	# Create it here so it acts as a child
	$self->{server} = POE::Component::Server::SimpleHTTP->new(
		PORT => $conf->{http_plugin_port},
		ADDRESS => $conf->{http_plugin_addr} || undef,
		ALIAS => 'web_httpd_alias',
		HANDLERS => [
			{
				DIR => '^/links',
				SESSION => 'web_interface',
				EVENT => "irc_links",
			},
			{
				DIR => '^/request',
				SESSION => "web_interface",
				EVENT => "handle_request",
			},
			{
				DIR => '^/',
				SESSION => "web_interface",
				EVENT => "display_page",
			}

		]
	);

	$kernel->alias_set( "web_interface" );
	$kernel->sig("DIE" => 'sig_DIE' );
}

my $DBH;
sub irc_links {
	my( $self, $req, $resp ) = @_[OBJECT,ARG0,ARG1];
	my $path = $req->uri->path;
	$path =~ s{.*?/links/}{};
	$path = uri_unescape( $path );
	if( $path !~ /^#/ ) { $path = "#$path"; }


	if( not $DBH or not $DBH->ping ) {
		$DBH = DBI->connect("dbi:SQLite:dbname=var/irclinks.db","","");
	}

	my $links = $DBH->selectall_arrayref( 
		"SELECT uri FROM irclinks WHERE channel=? ORDER BY time_inserted DESC",
		undef,
		$path
	);

	my $output;
	for( @$links ) {
		my $link = encode_entities( $_->[0] );
		$output .= "<a href='$link'>$link</a><br>\n";
	}


	$resp->code(RC_OK);
	$resp->content_type("text/html");
	$resp->content( "<http><head></head><body>Links $path:<br>\n$output</body></html>" );

	$_[KERNEL]->post(  web_httpd_alias => 'DONE' => $resp );
}

sub display_page {
	my( $self, $req, $resp, $name, $output ) = @_[OBJECT,ARG0,ARG1,ARG2,ARG3];
	my $html = $HTML_TEMPLATE;
	
	warn "Display Page Activating: $req - $resp - $output\n";

	
	if( $output ) {
		$html =~ s/\%\%OUTPUT\%\%/$output/;
	}

	$resp->code(RC_OK);
	$resp->content_type("text/html");
	$resp->content( $html );
	
	$_[KERNEL]->post(  web_httpd_alias => 'DONE' => $resp );
}


my %RESP_MAP;

sub handle_request {
	my( $self, $req, $resp, $name ) = @_[OBJECT,ARG0,ARG1,ARG2];

	warn "Request: ", $req->content;

	my $query = CGI->new( $req->content );
	my $input = $query->param("body");

	my @args = "2+2";
	warn "Attempting to handle request: $req $resp $input\n";

	# This is obviously silly but I'm unable to figure out
	# the correct way to solve this =[
	my $said = {
		body => $input,
		raw_body => $input,
		my_name => 'WI',
		addressed => 1,
		recommended_args => \@args,
		channel => '*web',
		name => 'CC',
		ircname => 'CC', 
		host => '*special', #TODO fix this to be an actual hostname!
		                    # Make sure it isn't messed up by the alias feature..
		server => '*special',
	};
	
	# Avoid passing around the full reference
	$RESP_MAP{ "$resp" } = $resp; 
	$said->{pci_id} = "$resp";

	$self->{pm}->yield( execute_said => $said );
}

sub plugin_output {
	my( $self, $kernel, $said, $output ) = @_[OBJECT,KERNEL,ARG0,ARG1];

	$output =~ s/^\s*CC://; # Clear the response name

	my $resp = delete $RESP_MAP{ $said->{pci_id} };


	$kernel->yield( display_page => undef, $resp, undef, $output ); 
}

sub sig_DIE {
	# Do nothing, we're ignoring fatal errors from our child, poco-server-simplehttp. I think we don't need to respawn them.
}

1;

__DATA__
<html>
	<head>
	</head>

	<body onload="document.getElementById('body_field').focus()">
		Welcome to the BB3 web interface. You can interact with the bot by typing bot commands in to the text box below. It acts exactly as if you have typed the command in a private message to the bot. Try the command 'help' or 'plugins' (no quotes).
		<form method="post" action="/request">
		Input: <input type="text" name="body" id="body_field" size="64"> <input type="submit" value="go"> <br>
		</form>
		Output: %%OUTPUT%%
	</body>
</html>
