package xmltv;
use constant PLUGIN_NAME => xmltv;
use constant GENERATOR_INFO_NAME => EpgDownloader;
use constant GENERATOR_INFO_URL => "http://epgdownloader.sourceforge.net";
use Date::Format;
use plugins::xmltv::include::ConfigXmltv;
use strict;

=pod

=head1 NAME

xmltv - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can save tv schedule in xmltv format. In future also import should be implemented.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

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

#gets single channel name and returns events list
sub get {
	my $self = shift;
	my $name = shift;
	
	my $events = [];
	return $events;
}

#gets channels list with each one's events and exports it
sub save {
	my $self = shift;
	my $events = shift;

	my $fileName = $self->{'plugin_config'}->get('OUTPUT_FILE');
	my $timezone = $self->{'plugin_config'}->get('TIMEZONE');
	my $time = time2str("%Y%m%d%H%M%S",time)." ".$timezone;
	
	Misc::pluginMessage(PLUGIN_NAME,"Saving schedule.");

	open(FILE, "> $fileName")
		or Misc::pluginMessage(
				PLUGIN_NAME, 
				"Could not open the file $fileName! \n $!") 
			&& return;
	
	#save header and main node
	print FILE "<?xml version=\"1.0\" encoding=\"".$self->{'plugin_config'}->get('HEADER_ENCODING')."\"?>\n";
	print FILE "<tv date=\"".$time."\" generator-info-name=\"".GENERATOR_INFO_NAME."\" generator-info-url=\"".GENERATOR_INFO_URL."\">\n";


	foreach my $channel (keys(%{$events})) {
		my $channelEvents = $events->{$channel};
		next if $#{$channelEvents} == -1;
		
		#save channel node
		print FILE "\t<channel id=\"".$channel."\">\n";
		print FILE "\t\t<display-name>".$channel."</display-name>\n";
		print FILE "\t</channel>\n";
		
		for(my $i=0; $i <= $#{$channelEvents}; $i++) {
			my $event = $events->{$channel}->[$i];
			my $title = $event->get('title');
			my $description = $event->get('description');
			my $start = time2str("%Y%m%d%H%M00",$event->get('start'))." ".$timezone;
			my $stop = time2str("%Y%m%d%H%M00",$event->get('stop'))." ".$timezone;
			
			$title =~ s/&/&amp;/;
			$description =~ s/&/&amp;/;
			
			#save channel's event node
			print FILE "\t<programme channel=\"".$channel."\" start=\"".$start."\" stop=\"".$stop."\">\n";
			print FILE "\t\t<title>".$title."</title>\n";
			print FILE "\t\t<desc>".$description."\n\t\t</desc>\n";
			print FILE "\t</programme>\n";
		}
	}
	
	#close main node
	print FILE "</tv>\n";

	close(FILE);
	
}

1;
