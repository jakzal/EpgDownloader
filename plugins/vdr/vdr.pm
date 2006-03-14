package vdr;
use constant PLUGIN_NAME => vdr;
use plugins::vdr::include::ConfigVdr;
use Date::Format;
use strict;

=pod

=head1 NAME

vdr - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can save tv schedule in epg.data format of Video Disk Recorder. In future also import should be implemented.

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
	$self->{'plugin_config'} = ConfigVdr->new('config.xml');
	
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
	my $episodeId = $self->{'plugin_config'}->get('START_EPISODE_ID');
	
	Misc::pluginMessage(PLUGIN_NAME,"Saving schedule to $fileName");

	open(FILE, "> $fileName")
		or Misc::pluginMessage(
				PLUGIN_NAME, 
				"Could not open the file $fileName! \n $!") 
			&& return;
	
	foreach my $channel (keys(%{$events})) {
		my $channelEvents = $events->{$channel};
		next if $#{$channelEvents} == -1;
		
		my $channelString = $self->getChannelString($channel);
		
		if($channelString =~ /^$/) {
			Misc::pluginMessage(PLUGIN_NAME,"Channel '$channel' doesn't exists.");
			next;
		}
		
		print FILE "C ".$channelString."\n";
		
		for(my $i=0; $i <= $#{$channelEvents}; $i++) {
			my $event = $events->{$channel}->[$i];
			my $title = $event->get('title');
			my $description = $event->get('description');
			my $start = time2str("%Y%m%d%H%M00",$event->get('start'));
			my $stop = time2str("%Y%m%d%H%M00",$event->get('stop'));
			
			$title =~ s/\n/ /g;
			$description =~ s/\n/ /g;
			
			print FILE "E ".$episodeId++." ".$start." ".($stop-$start)." 0\n";
			print FILE "T ".$title."\n";
			print FILE "D ".$description."\n";
			print FILE "e\n";

		}
		
		print FILE "c\n";

	}
	
	close(FILE);
}

sub getChannelString {
	my $self = shift;
	my $channel = shift;
	
	my $channelsConf = $self->{'plugin_config'}->get('CHANNELS_CONF');
	
	open(CHANNELS_FILE, "<$channelsConf");
	my $prevLimiter = $/;
	$/ = undef;
	my $content = <CHANNELS_FILE>;
	$/ = $prevLimiter;
	close(CHANNELS_FILE);

	my $channelString = "";
	
	if($content =~ s/(.*?)($channel)(.*?)\n(.*)/$2$3/smi) {
		my @row = split( /:/, $content );
		$channelString = $row[3]."-".$row[10]."-".$row[11]."-".$row[9]." ".$row[0];
	}

	return $channelString;
}

1;
