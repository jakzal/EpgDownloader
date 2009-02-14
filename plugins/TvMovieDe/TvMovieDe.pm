package TvMovieDe;
use constant PLUGIN_NAME => TvMovieDe;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use constant FORM_NUMBER => 1;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::TvMovieDe::include::ConfigTvMovieDe;
use strict;

=pod

=head1 NAME

TvMovieDe - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://www.tvmovie.de website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march, april, may 2006

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigTvMovieDe->new('config.xml');
	
	$self->{'url'} = 'http://tvmovie.de/TV_nach_Sendern.22.0.html';
	
	bless( $self, $class );
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $events = ();
	my $url = $self->{'url'};

	my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
		
	$browser->get($url);
	
  #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
  #my $channelsList = $browser->content();
  my $channelsList = $browser->response()->decoded_content();
	
	if($channelsList !~ s/(.*)<select name="senderid\[\]"(.*?)>(.*?)<\/select>(.*)/$3/sm) {
		Misc::pluginMessage(PLUGIN_NAME, "ERROR: Couldn't parse website!");
		return $channels;
	}
	
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
		
		my $events = $channels->{$name};
		
		my $channelId = $channelsList;
		
		if($channelId !~ s/(.*)<option value="(.*?)">$name<\/option>(.*)/$2/sm) {
			Misc::pluginMessage(PLUGIN_NAME, "ERROR: Schedule for channel '$name' not found!");
			next;
		}
		
		my $base_uri = $url."?senderid[]=".$channelId;
		
		for(my $i=0; $i < $self->{'plugin_config'}->{'DAYS'}; $i++) {
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i)));
			
			$browser->get($base_uri."&date=".$dateString);
		
			#@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
			#my $content = $browser->content();
			my $content = $browser->response()->decoded_content();
 			$content =~ s/(.*?)Haupttabelle Anfang(.*?)Haupttabelle Ende(.*)/$2/sm;
			
			#parse schedule
			while($content =~ s/(.*?)<tr id="l(.*?)">(.*?)<\/tr>(.*)/$4/sm) {
				my $row = $3;
			
				next if $row !~ s/(.*?)<td(.*?)><\/td>(.*?)<td(.*?)>(.*?)<\/td>(.*)/$5/sm;
				
				while($row =~ s/(.*?)<span(.*?)>(.*?)<\/span>(.*?)<a(.*?)>(.*?)<\/a>(.*?)<br \/>(.*)/$8/sm) {
					my $hour = $3;
					my $title = $6;
					my $description = $7;
					my $category = $7;
					
					$description = "" if($description !~ s/(.*?)\((.*?)\)(.*)/$2/);
					$category = "" if($category !~ s/(.*?\))(.*?)([-0-9]{1,})(.*)/$2/);
					
					$description =~ s/^\s//; $description =~ s/\s$//;
					$category =~ s/^\s//; $category =~ s/\s$//;
					
					#'&' are already in proper format
					$title =~ s/&amp;/&/g;
					$description =~ s/&amp;/&/g;
					$category =~ s/&amp;/&/g;
					
					#convert hour to unix timestamp, if it's after midnight, change base date string
					$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
					$hour = str2time($dateString." ".$hour);

					#create event
					my $event = Event->new();
					$event->set('start',$hour);
					$event->set('stop',$hour+1);
					$event->set('title',$title);
					$event->set('description',$description);
					$event->set('category',$category);
	
					#set the previous event stop timestamp
					my $previous = $#{$events};
					$events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;
					
					#put event to the events array
					push @{$events}, $event;
				}
				
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
