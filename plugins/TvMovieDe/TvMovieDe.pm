package TvMovieDe;
use constant PLUGIN_NAME => TvMovieDe;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
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

Date: march, april 2006

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigTvMovieDe->new('config.xml');
	
	$self->{'url'} = 'http://www.tvmovie.de/suche/profisuche.html';
	
	bless( $self, $class );
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $events = ();
	my $url = $self->{'url'};

	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
		
		my $events = $channels->{$name};
		
		my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
		
		$browser->get($url);
		
		my $content = $browser->content();
		$content =~ s/(.*)<b><br>Sender<\/b>(.*)/$2/sm;
	
		#check if channel exists
		if($content !~ s/(.*)<input type="checkbox" name="sender" value="(.*?)">(&nbsp;)$name<\/font><\/td>(.*)//sm) {
			Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' not found!");
			next;
		}
	
		#channel checkbox
		my $channelId = $2;
		$browser->form_name("profisucheFinderForm");
		$browser->tick("sender", $channelId);
		
		#hour checkboxes
		for(my $i=0; $i<24; $i++) {
			my $value = $i;
			$value = "0".$value if $value =~ /^[0-9]$/;
			$browser->tick("zeiten", $value);
		}
		
		#get schedule for each day, couldn't get all at one time because website has restrictions to 100 rows
		my @germanDays = ( 'sa', 'so', 'mo', 'di', 'mi', 'do', 'fr' );
		my ($second, $minute, $hour, $day, $month, $year, $weekDay, $dayOfYear, $isDST) = localtime(time()+(60*60*24));
		my $days = $self->{'plugin_config'}->get('DAYS');
		my $d = $weekDay;
		my $base_uri = "";
		
		for(my $i=0; $i < $days; $i++) {
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i)));
			$d = $d+$i;
			$d = 0 if !exists($germanDays[$d]);
			
			#first day is form submittet, the rest is get from uri
			if($i==0) {
				$browser->tick("tage", $germanDays[$d]);
				$browser->submit();
				$base_uri = $browser->uri();
			} else {
				my $current_uri = $base_uri;
				$current_uri =~ s/(.*?)(tage=)([smdf][aoir])(.*)/$1$2$germanDays[$d]$4/;
				$browser->get($current_uri);
			}
		
			$content = $browser->content();
			$content =~ s/(.*?)<a name="suchergebnisse" \/>(\s)+<table(.*?)>(.*?)<table(.*?)>(.*?)<\/table>(.*)/$6/sm;
		
			#parse schedule
			while($content =~ s/(.*?)<tr>(.*?)<\/tr>(.*)/$3/sm) {
				my $row = $2;
			
				my $colReg = "(.*?)<td(.*?)>(.*?)<\/td>";
			
				next if $row !~ s/$colReg$colReg$colReg$colReg$colReg$colReg/$3/sm;
			
				my $hour = $6;
				my $title = $15;
				my $description = "";
				my $category = $18;
			
				$title =~ s/(.*?)<b>(.*?)<\/b>(.*)/$2/sm;
				$description = $3;

				#remove trash
				$hour =~ s/<(.*?)>//smg;
				$title =~ s/<(.*?)>//smg;
				$description =~ s/<(.*?)>//smg;
				$category =~ s/<(.*?)>//smg;

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
