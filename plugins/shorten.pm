package Bot::BB3::Plugin::Shorten;
use warnings;
use strict;
use WWW::Shorten 'Metamark';
use URI;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'shorten';
	$self->{opts}->{handler} = 1;
    $self->{opts}->{command} = 1;
    $self->{aliases} = [  'shorten', 'shorten it' ];

    # $self->{previous_url}{ server / nick or channel } = $url
    # $self->{short_of} { $rul } = shoftened
	return $self;
}


sub from_from { 
    my (undef, $said) = @_;
        my $said_in =  $said->{server}
        .'/'
        . (
                $said->{name}
                || '#' .$said->{channel}
        );
} 

sub handle {
	my( $self, $said, $pm ) = @_;

    my $text = $said->{body};
    
    my $said_in = $self->from_from( $said );

    # just so we don't make the last expicit shorten the next implicit shorten
    return if $text =~ /^shorten/i;

    if ($text =~ m{(http(?:s?)://[^ ]+)}){
        $self->{previous_url}{ $said_in } = $1;
        # return "Snagged '$1' for later shortening"
    }
    return ;
}

sub command {
	my( $self, $said, $pm ) = @_;
    
    my $said_in = $self->from_from( $said );

    my ($uri_text) = @{ $said->{recommended_args} };

    if ($uri_text =~ /^it/i){
        $uri_text =  $self->{previous_url}{ $said_in };

        return ('handled',"I have no idea what 'it' refers to... ")
            if  not defined $uri_text or $uri_text eq '';
    }

    return ('handled', 'the empty string is already pretty short...')
            if not defined $uri_text or $uri_text eq '' and $said->{addressed};

    my $short   = $self->{short_of}{ $uri_text }
              //=  makeashorterlink( $uri_text );
    
    my $uri = URI->new( $uri_text ); 
    
    return ('handled', "That's a silly url.") if $short eq '' and $said->{addressed}; 
    return ('handled', sprintf "%s (at %s)", $short, $uri->host);


}


'Bot::BB3::Plugin::Shorten'
__DATA__
shorten <url> returns the "short form" of a url. Defaults to using xrl.us.
shorten it returns ths short form of the previous url mentioned
