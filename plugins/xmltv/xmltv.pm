package xmltv;
use constant PLUGIN_NAME => xmltv;
use constant GENERATOR_INFO_NAME => EpgDownloader;
use constant GENERATOR_INFO_URL => "http://epgdownloader.sourceforge.net";
use Date::Format;
use Date::Parse;
use plugins::xmltv::include::ConfigXmltv;
use strict;

=pod

=head1 NAME

xmltv - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can save tv schedule in xmltv format. It is able to read it as well.

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
	$self->{'plugin_config'} = ConfigXmltv->new('config.xml');
	
	bless($self, $class);
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $fileName = $self->{'plugin_config'}->get('INPUT_FILE');
	
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Getting schedule for ".$name," ");

		my $events = $channels->{$name};
	
		open( FILE, "<$fileName" ) 
			or Misc::pluginMessage(
				PLUGIN_NAME,
				"Cant't open '$fileName' file: $!")
			&& return $channels;
	
		my $prevLimiter = $/;
		$/ = undef;
		my $content = <FILE>;
		$/ = $prevLimiter;
		close( FILE );
		
		#parse file content
		$content =~ s/(.*?)<tv(.*?)>(.*?)<\/tv>(.*)/$3/smi;
		$content =~ s/(\s){2,}/ /smg;
		$content =~ s/(\s<)/</smg;

		#remove comments
		$content =~ s/<!--(.*?)\-\-\>//smg;
	
		#special treatment for '+', '(', ')'
		$name =~ s/\+/\\\+/g;
		$name =~ s/\(/\\\(/g;
		$name =~ s/\)/\\\)/g;

		my $foundDays = {};
	
		while($content =~ s/<programme channel="$name" start="(.*?)" stop="(.*?)"(.*?)>(.*?)<\/programme>(.*)/$5/smi) {
			my $start = $1;
			my $stop = $2;
			my $data = $4;
		
			$start =~ s/([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})(\s)(.*)/$1-$2-$3 $4:$5/;
			my $startTimeZone = $6;
			my $day = $3;
			$stop =~ s/([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})(\s)(.*)/$1-$2-$3 $4:$5/;
			my $stopTimeZone = $6;
		
			my $title = "";
			$title = $2 if $data =~ /<title(.*?)>(.*?)<\/title>/smi;
			my $description = "";
			$description = $2 if $data =~ /<desc(.*?)>(.*?)<\/desc>/smi;
			my $category = "";
			$category = $2 if $data =~ /<category(.*?)>(.*?)<\/category>/smi;
		
			$title =~ s/&amp;/&/g;
			$description =~ s/&amp;/&/g;
		
			#create event
			my $event = Event->new();
			$event->set('start',str2time($start,$startTimeZone));
			$event->set('stop',str2time($stop,$stopTimeZone));
			$event->set('title',$title);
			$event->set('description',$description);
			$event->set('category',$category);
		
			#put event to the events array
			push @{$events}, $event;
		
			if(!exists($foundDays->{$day})) {
				$foundDays->{$day} = 1;
				Misc::pluginMessage("","#"," ");
			}
		}
	
		Misc::pluginMessage("","");
	}
	
	return $channels;
}

#gets channels list with each one's events and exports it
sub save {
	my $self = shift;
	my $events = shift;

	my $fileName = $self->{'plugin_config'}->get('OUTPUT_FILE');
	my $timezone = $self->{'plugin_config'}->get('TIMEZONE');
	my $time = time2str("%Y%m%d%H%M%S",time)." ".$timezone;
	
	Misc::pluginMessage(PLUGIN_NAME,"Saving schedule to $fileName");

	open(FILE, "> $fileName")
		or Misc::pluginMessage(
				PLUGIN_NAME, 
				"Could not open the file $fileName! \n $!") 
			&& return;
	
	#save header and main node
	print FILE "<?xml version=\"1.0\" encoding=\"".$self->{'plugin_config'}->get('HEADER_ENCODING')."\"?>\n";
	print FILE "<tv date=\"".$time."\" generator-info-name=\"".GENERATOR_INFO_NAME."\" generator-info-url=\"".GENERATOR_INFO_URL."\">\n";

	my $channelCount=0;
	foreach my $channel (keys(%{$events})) {
		my $channelEvents = $events->{$channel};
		next if $#{$channelEvents} == -1;
		
		$channelCount++;
		my $channelId = $channel;
		$channelId = $channelCount."_".$channelId if $self->{'plugin_config'}->get('UNIQUE_CHANNEL_PREFIX') eq "1";
		
		#save channel node
		print FILE "\t<channel id=\"".$channelId."\">\n";
		print FILE "\t\t<display-name>".$channel."</display-name>\n";
		print FILE "\t</channel>\n";
		
		for(my $i=0; $i <= $#{$channelEvents}; $i++) {
			my $event = $events->{$channel}->[$i];
			my $title = $event->get('title');
			my $description = $event->get('description');
			my $description2 = $event->get('description2');
			my $start = time2str("%Y%m%d%H%M00",$event->get('start'))." ".$timezone;
			my $stop = time2str("%Y%m%d%H%M00",$event->get('stop'))." ".$timezone;
			my $category = $event->get('category');
			
			$title =~ s/&/&amp;/g;
			$description =~ s/&/&amp;/g;
			$description2 =~ s/&/&amp;/g;
			$description = "\n".$description2 if $description2 !~ /^$/;
			
			#save channel's event node
			print FILE "\t<programme channel=\"".$channelId."\" start=\"".$start."\" stop=\"".$stop."\">\n";
			print FILE "\t\t<title>".$title."</title>\n";
			print FILE "\t\t<desc>".$description."\n\t\t</desc>\n";
			print FILE "\t\t<category>".$category."</category>\n" if $category !~ /^$/;
			print FILE "\t</programme>\n";
		}
	}
	
	#close main node
	print FILE "</tv>\n";

	close(FILE);
	
}

1;
