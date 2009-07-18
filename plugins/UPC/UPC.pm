package UPC;
use constant PLUGIN_NAME => UPC;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::UPC::include::ConfigUPC;
use strict;

=pod

=head1 NAME

UPC - EpgDownloader plugin

Version 0.5

=head1 DESCRIPTION

This plugin can import tv schedule from http://przewodnik-tv.upclive.pl

=head1 COPYRIGHT

Copyright (C) 2008-2009 Marcin Jagoda <marcin@jagoda.be>

This software is released under the GNU GPL version 2.

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigUPC->new('config.xml');
	
	$self->{'url'} = 'http://przewodnik-tv.upclive.pl/';
	
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
	
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
		
		my $events = $channels->{$name};
	
		my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
		$browser->cookie_jar(undef);

		$name =~ s/\+/-plus/g;
		$name =~ s/ /\+/g;
		$name =~ s/!/%21/g;
		$name =~ s/&/%26/g;

		$browser->get($url.'TV/Guide/Channel/'.$name.'/');

		$name =~ s/%26/&/g;
		$name =~ s/%21/!/g;
		$name =~ s/\+/ /g;
		$name =~ s/-plus/\+/g;


		my $base_uri = $browser->uri();

		my @weekdays = qw(Monday Tuesday Wednesday Thursday Friday Saturday Sunday);
		my $wday = (localtime(time))[6];

		my @days_upc = @weekdays;

		for(my $i=0; $i <= 6; $i++) {
			$days_upc[$i] = $weekdays[$wday-1]; 
			$wday = $wday + 1; if ($wday > 7) { $wday = 1; }

		}
		$days_upc[0] = "Today";

		for(my $i=1; $i <= $days; $i++) {
			
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i-1)));
			my $dateUnix = str2time($dateString);
			my $date_url = "";

			my $dayOfWeek = $days_upc[$i-1];
			$browser->get($base_uri.$dayOfWeek); # if $i>1;
			
			my $content = $browser->content();

			if($content !~ s/(.*?)<table>(.*)<\/table>(.*)/$2/sm) {
				Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
				last;
			}
			while($content =~ s/(.*?)<th class="event-starttime">(.*?)<\/tr>(.*)/$3/sm) {
				my $row = $2;
	
				my $hour = $row;
				last if $hour !~ s/(.*?)<span>([0-9]{1,2}:[0-9]{2})<\/span>(.*)/$2/sm;
				
				#<td class="event-name" id="eid30127413_1_0811280900">
				my $event_name = $3;

				$event_name =~ s/(.*?)td class="event-name" id="eid(.*?)">(.*)/$2/sm;
				####http://przewodnik-tv.upclive.pl/TV/Guide/Event/29818734_1_0811140915/

				my $title = $3;

				$title =~ s/(.*?)<a href="#">(.*?)<\/a>(.*)/$2/sm;
		
				my $category = $3;
				$category =~ s/(.*?)td class="event-genre">\n\t(.*?)\n<\/td>(.*)/$2/sm;

				my $description = "";
				my $description2 = "";

				my $director = "";
				my $cast = "";
						
				#get full description if needed (follows another link so it costs time)
				if($fullDescription == 1) {
					$browser->get($url.'TV/Guide/Event/'.$event_name.'/');
					$description = $browser->content();
					$description =~  s/(.*?)<p>\n(.*?)<\/p>(.*)/$2/sm;

					$director = $browser->content();
					if ($director =~  s/(.*?)<dt>Reżyseria:<\/dt><dd>(.*?)<\/dd>(.*)/$2/sm) { 
					    $description = $description . " Reżyseria: " . $director;
					} 
					$cast = $browser->content();
					if ($cast =~  s/(.*?)<dt>Występują:<\/dt><dd>(.*?)<\/dd>(.*)/$2/sm) {
					    $description = $description . " Występują: " . $cast;
					} 

				} # EXTREMELY slow
				elsif ($fullDescription == 2) { 
					$browser->get($url.'TV/Guide/Event/'.$event_name.'/');
					$browser->follow_link( text => "Więcej");					
					$description = $browser->content();
					$description =~  s/(.*?)<div id="program-desc-text">\n\t(.*?)<\/div>(.*)/$2/sm;

					$director = $browser->content();
					if ($director =~  s/(.*?)<dt>Reżyseria:<\/dt><dd>(.*?)<\/dd>(.*)/$2/sm) { 
					    $description = $description . " Reżyseria: " . $director;
					} 
					$cast = $browser->content();
					if ($cast =~  s/(.*?)<dt>Występują:<\/dt><dd>(.*?)<\/dd>(.*)/$2/sm) {
					    $description = $description . " Występują: " . $cast;
					} 
				}
				
				#remove html tags from title
				$title =~ s/<(\/?)(.*?)>//smg;
		
				#removing trash from description
				$description  =~ s/<br(.*?)>/\n/smgi;
				$description  =~ s/<(\/?)(.*?)>//smg;
        $description  =~ s/\s+/ /g;
				$description2 =~ s/<br(.*?)>/\n/smgi;
				$description2 =~ s/<(\/?)(.*?)>//smg;
        $description2 =~ s/\s+/ /g;
		
				#convert hour to unix timestamp, if it's after midnight, change base date string
				$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
				$hour = str2time($dateString." ".$hour);
	
				#create event
				my $event = Event->new();
				$event->set('start',$hour);
				$event->set('stop',$hour+1);
				$event->set('title',$title);
				$event->set('category', $category);
				$event->set('description',$description);
				$event->set('description2',$description2);
	
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
