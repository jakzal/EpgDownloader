package Interia;
use constant PLUGIN_NAME => Interia;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use threads;
use Encode;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::Interia::include::ConfigInteria;
use strict;

=pod

=head1 NAME

Interia - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://program.interia.pl website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006, april 2010

=cut

sub new {
  my $class = shift;
  my $config = shift;

  my $self = {};
  $self->{'config'}        = $config;
  $self->{'plugin_config'} = ConfigInteria->new('config.xml');
  $self->{'url'}           = 'http://programtv.interia.pl';
  $self->{'channels'}      = {};
  $self->{'threads'}       = {};

  bless( $self, $class );
  return $self;
}

#gets channel names list and returns events list
sub get {
  my $self = shift;
  my $channels = shift;

  # fetch the channel list before threads are started
  $self->getChannels();

  foreach my $name (keys(%{$channels})) {
    $self->log(PLUGIN_NAME, "Downloading schedule for " . $name, " ");
    $self->{'threads'}->{$name} = threads->create('getChannelEvents', $self, $name);
    $self->log("", "");

    if (keys(%{$self->{'threads'}}) >= $self->{'plugin_config'}->{'THREADS'}) {
      while (my ($channelName, $thread) = each(%{$self->{'threads'}})) {
        $channels->{$channelName} = $thread->join();
        delete $self->{'threads'}->{$channelName};
      }
      $self->log("", "");
    }
  }

  while ((my $channelName, my $thread) = each(%{$self->{'threads'}})) {
    $channels->{$channelName} = $thread->join();
    delete $self->{'threads'}->{$channelName};
  }
  $self->log("", "");

  return $channels;
}

sub getChannelEvents {
  my $self = shift;
  my $name = shift;

  my $events = (); 
  my $days   = $self->{'plugin_config'}->get('DAYS');

  for(my $i=1; $i <= $days; $i++) {
    my $dayEvents = $self->getChannelEventsForDay($name, $i);
    if ($dayEvents) {
      push @{$events}, @{$dayEvents};
    } else {
      last;
    }
  }

  return $events;
}

sub getChannels {
  my $self = shift;

  if (keys %{$self->{'channels'}} < 1) {
    $self->{'channels'} = $self->parseChannelsFromWebsite();
  }

  return $self->{'channels'};
}

sub parseChannelsFromWebsite {
  my $self = shift;

  my $channels = {}; 
  my $browser  = WWW::Mechanize->new( 'agent' => BROWSER );

  $browser->get($self->{'url'} . '/kanaly/wszystkie,10');

  my $content = encode('utf8', $browser->content());
  $content =~ s/.*?<ul id="channelList">(.*?)<\/ul>.*/$1/sm;

  while ($content =~ s/.*?<a href="([^"]+)">(.*?)<\/a>(.*)/$3/sm) {
    my $href = $1;
    my $name = $2;
    my $url  = $self->{'url'} . '/kanaly/' . $href;

    $channels->{$name} = $url;
  }

  return $channels;
}

sub findChannelUriByName {
  my $self = shift;
  my $name = shift;

  $name = encode('utf8', $name);

  my $channels = $self->getChannels();

  return $channels->{$name} || '';
}

sub findChannelUriByNameAndDate {
  my $self = shift;
  my $name = shift;
  my $date = shift;

  my $channel_uri = $self->findChannelUriByName($name);
  $channel_uri =~ s/(sDate=[0-9]{4}-[0-9]{2}-[0-9]{2})/sDate=$date/;
  $channel_uri =~ s/(sTimeF=(-|)[0-9]{1,2})/sTimeF=5/;
  $channel_uri =~ s/(sTimeT=(-|)[0-9]{1,2})/sTimeT=4/;

  return $channel_uri;
}

sub getChannelEventsForDay {
  my $self = shift;
  my $name = shift;
  my $day  = shift;

  my $events = (); 
  my $browser = WWW::Mechanize->new( 'agent' => BROWSER );

  my $dateString  = time2str("%Y-%m-%d", time+(60*60*24*($day-1)));
  my $channel_uri = $self->findChannelUriByNameAndDate($name, $dateString);

  $browser->get($channel_uri);

  my $content = encode('utf8', $browser->content());
  if($content !~ s/.*?<table.*?class="channelCont".*?>(.*?)<\/table>/$1/sm) {
    $self->log("","");
    $self->log(
      PLUGIN_NAME,
      "ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
    return $events;
  }

  while($content =~ s/.*?<tr class="t[0-9]+">.*?<td class="hour".*?>(.*?)<\/td>.*?<td>(.*?)<\/td>.*?<\/tr>(.*)/$3/sm) {
    my $hour = $1;
    my $row = $2;

    return $events if $hour !~ s/(.*?)([0-9]{1,2}:[0-9]{2})(.*)/$2/sm;

    $row =~ s/.*?<a href="(.*?)">.*?<strong>(.*?)<\/strong>.*?<\/a>.*?<span class="type">[^a-zA-Z0-9]+([a-zA-Z0-9]+).*?<\/span>(.*)/$4/sm;

    my $fullDescriptionUrl = $1;
    my $title = $2;
    my $category = $3;

    $row =~ s/.*?<div class="desc">(.*?)<\/div>.*/$1/sm;
    my $description = $row;
    my $description2 = "";

    #get full description if available and needed (follows another link so it costs time)
    if($self->{'plugin_config'}->{'FULL_DESCRIPTION'}== 1 && $fullDescriptionUrl !~ /^$/) {
      $browser->get($fullDescriptionUrl);
      my $tmp = encode('utf8', $browser->content());
      if($tmp =~ /.*?<p class="articleLead">(.*?)<\/p>.*/sm) {
        $description.= $1;
      }
      if($tmp =~ /.*?<p class="desc">(.*?)<\/p>.*/sm) {
        $description2 = $1;
      }
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
    $dateString = time2str("%Y-%m-%d",time+(60*60*24*($day))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
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

  $self->log("","#"," ");

  return $events;
}

#gets channels list with each one's events and exports it
sub save {
  my $self = shift;
  my $events = shift;

  $self->log(PLUGIN_NAME,"This plugin doesn't support export.");
}

sub log {
  my $self = shift;
  my $sender = shift;
  my $message = shift;
  my $newLine = shift || "\n";

  Misc::pluginMessage($sender, $message, $newLine);
}

1;
