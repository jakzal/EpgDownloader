package MiGuiaTV;
use constant PLUGIN_NAME => MiGuiaTV;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::MiGuiaTV::include::ConfigMiGuiaTV;
use strict;

=pod

=head1 NAME

MiGuiaTV - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://www.miguiatv.com website.

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
	$self->{'plugin_config'} = ConfigMiGuiaTV->new('config.xml');
	
	$self->{'url'} = 'http://www.miguiatv.com/todos-los-canales.html';
	
	bless( $self, $class );
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $url = $self->{'url'};
	
	my $days 		= $self->{'plugin_config'}->get('DAYS');
	my $fullDescription 	= $self->{'plugin_config'}->get('FULL_DESCRIPTION');
	
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
		
		for(my $i=1; $i <= $days; $i++) {
		
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i-1)));
			my $dateStringUrl = time2str("%Y%m%d",time+(60*60*24*($i-1)));
			my $dateUnix = str2time($dateString);
			my $date_url = "";

			if($i>1) {
				my $uri = $base_uri;
				$uri =~ s/programacion/$dateStringUrl/;
				$browser->get($uri);
			}
			
			my $content = $browser->content();
			
			if($content =~ /<div id="listing">(.*?)<table>[\s]{0,}<\/table>/sm) {
				Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
				next;
			}
			
			while($content =~ s/(.*?)<tr class="show_(.*?)">(.*?)<td valign="top">(.*?)<\/td>(.*?)<table(.*?)>(.*?)<\/table>(.*?)<\/tr>(.*)/$9/sm) {
				my $hour = $4;
				my $row = $7;

				last if $hour !~ s/(.*?)([0-9]{1,2}:[0-9]{2})(.*)/$2/sm;
				
				my $title = $row;
				$title =~ s/(.*?)<strong>(.*?)<\/strong>(.*)/$2/sm;
				
				my $category = $3;
				my $description = $3;
				my $description2 = "";
				
				$category = "" unless $category =~ s/(.*?)<strong>(.*?)<\/strong>(.*)/$2/sm;
				$description = "" unless $description =~ s/(.*?)<tr>(.*?)<\/tr>(.*)/$2/sm;
				
 				my $fullDescriptionUrl = "";
				if($description =~ s/(.*?)<a href='(.*?)'>Ver m(.*?)<\/a>(.*)/$1$3/sm) {
					$fullDescriptionUrl = $2;
				}
				
				#get full description if available and needed (follows another link so it takes time)
				if($fullDescription == 1 && $fullDescriptionUrl !~ /^$/) {
					$browser->get($fullDescriptionUrl);
					my $tmp = $browser->content();
					$description = $tmp;
					$description2 = $tmp;
					$description =~ s/(.*?)<div id=\"show\">(.*?)<br \/><br \/>(.*?)<table(.*?)>(.*)/$3/sm;
					$description2 =~ s/(.*?)<div id=\"show\">(.*?)<br \/>(.*?)<br \/><br \/>(.*?)<table(.*?)>(.*)/$3/sm;
					$description2 =~ s/<br(.*?)>/, /smg;
				} 

				#remove html tags from title
				$title =~ s/<(\/?)(.*?)>//smg;
				$title =~ s/^[\s\n]{1,}//; 
				$title =~ s/[\s]{1,}$//;
					
				#removing trash from description and category
				$description =~ s/<br(.*?)>/\n/smgi;
				$description =~ s/<(\/?)(.*?)>//smg;
				$description =~ s/^[\s\n]{1,}//; 
				$description =~ s/[\s]{1,}$//;
				$description2 =~ s/<br(.*?)>/\n/smgi;
				$description2 =~ s/<(\/?)(.*?)>//smg;
				$description2 =~ s/^[\s]{1,}//; 
				$description2 =~ s/[\s]{1,}$//;
				$category =~ s/<(\/?)(.*?)>//smg;
				$category =~ s/^[\s]{1,}//; 
				$category =~ s/[\s]{1,}$//;
		
				#convert hour to unix timestamp, if it's after midnight, change base date string
				$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-6]{1}:[0-9]{2}/;
				$hour = str2time($dateString." ".$hour);
	
				#create event
				my $event = Event->new();
				$event->set('start', 		$hour		);
				$event->set('stop', 		$hour+1		);
				$event->set('title', 		$title		);
				$event->set('category', 	$category	);
				$event->set('description', 	$description	);
				$event->set('description2', 	$description2	);
	
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
