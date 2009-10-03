# jbels (jdporter's fortune feed list) plugin for buubot3

use warnings; use strict; #use 5.010;
use LWP::Simple;
use CGI;

my $main = sub {
	my $arg = ${$_[0]}{"body"};
	
	my $suffix;
	if (!($arg =~ /(\S+)/)) {
		print "No fortune filename given.  Try the `jbels' command to list fortune files.\n";
		return;
	}
	my $nam = $1;
	$suffix = ($nam =~ /:/ ? "source=" : "file=") . CGI::escape($nam);

	my $uri = "http://jdporter.perlmonk.org/fortune.cgi?plain;" . $suffix;
	my $content = get($uri);
	if (!defined($content)) {

		print "error loading fortune feed\n";
	}
	
	$content =~ s/[\r\n]+\s*/ /g;
	
	print $content, "\n";
	
};

!%Bot:: && @ARGV and # standalone run hack
	&$main({"body", join(" ", @ARGV)});

$main; # buubot plugin

__DATA__
Get a fortune cookie from jdporter's fortune feed (http://jdporter.perlmonk.org/fortune.cgi); usage: jbe name; see also jbels
