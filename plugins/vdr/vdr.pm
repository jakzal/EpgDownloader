package vdr;
use constant PLUGIN_NAME => vdr;
use plugins::vdr::include::ConfigVdr;
use strict;

=pod

=head1 NAME

vdr - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can save and import tv schedule in epg.data format of Video Disk Recorder. 

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
	$self->{'plugin_config'} = ConfigVdr->new('config.xml');
	
	bless($self, $class);
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $fileName = $self->{'plugin_config'}->get('INPUT_FILE');
	
	open(FILE, "<$fileName")
			or Misc::pluginMessage(
				PLUGIN_NAME,
				"Cant't open '$fileName' file: $!")
			&& return $channels;
  binmode(FILE, ":utf8");
	
	my $read = 0;
	my $name = "";
	my $channelInfo = "";
	my $events;
	my $event;
	while(<FILE>) {
		my $line = $_;
		
		if($line =~ /^C (.*?) (.*?)(\;.*|\s)$/) {
			if(exists($channels->{$2})) {
				my $chInfo = $1;
				$name = $2;
				
				$channelInfo = $self->getChannelString($name)."\n";
				$channelInfo =~ s/^(.*?)\s(.*)\n$/$1/;
				next if $channelInfo ne $chInfo;
				
				Misc::pluginMessage(PLUGIN_NAME,"Getting schedule for ".$name," ");
				
				$events = $channels->{$name};
				
				$event = Event->new();
				
				$read = 1;
				
				next;
			} else {
				$read = 0;
			}
		} elsif($read == 1) {
			if($line =~ /^E (.*?) (.*?) (.*?) (.*)/) {
				$event->set('start', $2);
				$event->set('stop', $2+$3);
			} elsif($line =~ /^T (.*)\n$/) {
				$event->set('title', $1);
			} elsif($line =~ /^D (.*)\n$/) {
				$event->set('description', $1);
			} elsif($line =~ /^S (.*)\n$/) {
				$event->set('description2', $1);
			} elsif($line =~ /^e/) {
				push @{$events}, $event;
			} elsif($line =~ /^c/) {
				$read = 0;
				Misc::pluginMessage("","");
			}
		}
	}
	
	close(FILE);
	
	return $channels;
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
  binmode(FILE, ":utf8");
	
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
			my $description2 = $event->get('description2');
			my $start = $event->get('start');
			my $stop = $event->get('stop');
			
			$title =~ s/\n/ /g;
			$description =~ s/\n/ /g;
			$description2 =~ s/\n/ /g;
			
			print FILE "E ".$episodeId++." ".$start." ".($stop-$start)." 0\n";
			print FILE "T ".$title."\n";
			print FILE "D ".$description."\n" if $description !~ /^$/;;
			print FILE "S ".$description2."\n" if $description2 !~ /^$/;
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
  binmode(CHANNELS_FILE, ":utf8");
	my $prevLimiter = $/;
	$/ = undef;
	my $content = <CHANNELS_FILE>;
	$/ = $prevLimiter;
	close(CHANNELS_FILE);

	my $channelString = "";

	#special treatment for '+', '(', ')'
	$channel =~ s/\+/\\\+/g;
	$channel =~ s/\(/\\\(/g;
	$channel =~ s/\)/\\\)/g;
	
	if($content =~ s/(.*?)^($channel)(.*?)\n(.*)/$2$3/smi) {
		my @row = split( /:/, $content );
		$channelString = $row[3]."-".$row[10]."-".$row[11]."-".$row[9]." ".$row[0];
	}

	return $channelString;
}

1;
