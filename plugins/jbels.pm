# jbels (jdporter's fortune feed list) plugin for buubot3

use warnings; use strict;
use LWP::Simple;

my $main = sub {
	my $arg = ${$_[0]}{"body"};
	
	my $uri = "http://jdporter.perlmonk.org/fortune.cgi?list;plain";
	my $content = get($uri);
	if (!defined($content)) {
		print "error loading fortune file list";
	}
	
	my @entr = map {
		!/\*\*\*/ and /^\s*(\S+)\s*$/ and $1
	} split /^/, $content;
	
	my %entr; $entr{$_}++ for @entr; # note: list has dupe entries
	my @ent = sort(keys %entr);
	
	my @page = "";
	for my $ent (@ent) {
		if (length($page[-1]) + 1 + length($ent) <= 320) {
			$page[-1] .= " " . $ent;
		} else {
			push @page, $ent;
		}
	}

	require Scalar::Util;
	if (Scalar::Util::looks_like_number($arg)) {
		my $num = int($arg);
		print "(p" . $num . "/" . (0+@page) . ") " . 
			$page[$num] . "\n";
	} elsif ($arg =~ /\A\s*all/) {
		print join " ", @ent;
	} else {
		print "Found " . (0 + @ent) . " jbe fortune files on jdporter's server, divided to " .
			(0+@page) . " pages, use `jbels 0', `jbels 1', etc to list them.\n";
	}
	
};

!%Bot:: && @ARGV and # standalone run hack
	&$main({"body", join(" ", @ARGV)});

$main; # buubot plugin

__DATA__
List files in jdporter's fortune feed (http://jdporter.perlmonk.org/fortune.cgi); usage: jbels [pageno]; see also jbe
