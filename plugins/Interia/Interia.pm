package Interia;
use constant PLUGIN_NAME => Interia;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::Interia::include::ConfigInteria;
use strict;

=pod

=head1 NAME

Interia - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://tv.interia.pl website.

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
	$self->{'plugin_config'} = ConfigInteria->new('config.xml');
	
	$self->{'url'} = 'http://program.interia.pl/program?p=10&akt_time=5';
	
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
			my $dateUnix = str2time($dateString);
			my $date_url = "";

			$browser->get($base_uri."&akt_date=".$dateString."&akt_time=5") if $i>1;

			my $content = $browser->content();

			if($content !~ s/(.*?)(<tr>(.*?)<(.*?)class=prc(.*?)>(.*))/$2/sm) {
				Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
				last;
			}

			while($content =~ s/(.*?)<tr>(.*?)<(.*?)\s(.*?)class=prc(.*?)>(.*?)<\/\3>(.*?)<\/tr>(.*)/$8/sm) {
				my $hour = $6;
				my $row = $7;

				last if $hour !~ s/(.*?)([0-9]{1,2}:[0-9]{2})(.*)/$2/sm;
				
				my $title = $row;
				$title =~ s/(.*?)<(.*?)\s(.*?)class=prtyt(.*?)>(.*?)<\/(.*?)>(.*)/$5/sm;
				
				my $category = $7;
				my $description = $7;
				my $description2 = "";
				
				$category = "" unless $category =~ s/(.*?)<(.*?)class=\"prkat\"(.*?)>(.*?)<\/(.*?)>(.*)/$4/sm;
				$description = "" unless $description =~ s/(.*?)<br>(.*?)<\/(.*?)>(.*)/$2/sm;
				
				my $fullDescriptionUrl = $row;
				$fullDescriptionUrl = "" unless $fullDescriptionUrl =~ s/(.*?)href=\"javascript:okienko\('pr','(.*?)'(.*?)\"(.*)/$2/sm;

				#get full description if available and needed (follows another link so it costs time)
				if($fullDescription == 1 && $fullDescriptionUrl !~ /^$/) {
					$browser->get($fullDescriptionUrl);
					my $tmp = $browser->content();
					$description = $tmp;
					$description2 = $tmp;
					$description =~ s/(.*?)<span class=\"oopis\">(.*?)<\/span>(.*)/$2/sm;
					$description2 =~ s/(.*?)<span class=\"oinf\">(.*?)<\/span>(.*)/$2/sm;
					$description2.= "\n".$tmp if $tmp =~ s/(.*)<span class=\"odat\">(.*?)<\/span>(.*)/$2/sm;
				} 

				#remove html tags from title
				$title =~ s/<(\/?)(.*?)>//smg;
		
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
				$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
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
