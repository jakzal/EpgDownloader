package EuroTV;
use constant PLUGIN_NAME => EuroTV;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::EuroTV::include::ConfigEuroTV;
use strict;

=pod

=head1 NAME

EuroTV - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://www.eurotv.com website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigEuroTV->new('config.xml');
	
	$self->{'url'} = 'http://www.eurotv.com/scripts/alpha.cfm';
	
	bless( $self, $class );
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $url = $self->{'url'};
	
	my $days 		= $self->{'plugin_config'}->get('DAYS');
	
	my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
	
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
		
		my $events = $channels->{$name};
		
		$browser->get($url);

		#special treatment for '+', '(', ')'
		$name =~ s/\+/\\\+/g;
		$name =~ s/\(/\\\(/g;
		$name =~ s/\)/\\\)/g;
	
		$browser->follow_link(text_regex => qr/$name$/);
	
		#special treatment for '+', '(', ')'
		$name =~ s/\\\+/+/g;
		$name =~ s/\\\(/\(/g;
		$name =~ s/\\\)/\)/g;
		
		my $base_uri = $browser->uri();
		$base_uri =~ s/(.*)\/(.*)$/$1\//;
		
		for(my $i=1; $i <= $days; $i++) {
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i-1)));

			my $uri = $i."a";
			$browser->follow_link(url_regex => qr/$uri/);
			
      #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
			#my $content = $browser->content();
      my $content = $browser->response()->decoded_content();
			
			if($content !~ s/(.*?)<TD(.*?)>(.*?)([0-9]{2}\:[0-5]{1}[0-9]{1})(.*?)<\/td>(.*)/$4$5/sm) {
				Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
				next;
			}
			
			while($content =~ s/(.*?)([0-9]{2}\:[0-5]{1}[0-9]{1})(.*?)<B>(.*?)<\/B>(.*?)(<BR>|<ul>.*?<\/ul>)(.*)/$7/sm) {
				my $hour = $2;
				my $title = $4;
				my $description = $6;
				
				last if $hour !~ s/(.*?)([0-9]{1,2}:[0-9]{2})(.*)/$2/sm;
				
				#remove html tags from title
				$title =~ s/<(\/?)(.*?)>//smg;
				$title =~ s/^[\s\n]{1,}//; 
				$title =~ s/[\s]{1,}$//;
					
				#removing trash from description and category
				$description =~ s/<br(.*?)>/\n/smgi;
				$description =~ s/<(\/?)(.*?)>//smg;
				$description =~ s/^[\s\n]{1,}//; 
				$description =~ s/[\s]{1,}$//;
				
				#convert hour to unix timestamp, if it's after midnight, change base date string
				$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-4]{1}:[0-9]{2}/;
				$hour = str2time($dateString." ".$hour);
	
				#create event
				my $event = Event->new();
				$event->set('start', 		$hour		);
				$event->set('stop', 		$hour+1		);
				$event->set('title', 		$title		);
				$event->set('description', 	$description	);
	
				#set the previous event stop timestamp
				my $previous = $#{$events};
				$events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;
			
				#put event to the events array
				push @{$events}, $event;
			}

			Misc::pluginMessage("","#"," ");
		}

		Misc::pluginMessage("","");
	}
	
	return $channels;
}

#gets channels list with each one's events and exports it
sub save {
	my $self = shift;
	my $events = shift;
	
	Misc::pluginMessage(PLUGIN_NAME,"This plugin doesn't support export.");
}

1;
