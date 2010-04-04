package WP;
use constant PLUGIN_NAME => WP;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use Encode;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::WP::include::ConfigWP;
use strict;

=pod

=head1 NAME

WP - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://tv.wp.pl website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march, april 2006, october 2008, april 2010

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigWP->new('config.xml');
	
	$self->{'url'} = 'http://tv.wp.pl';
	
	bless( $self, $class );
	return $self;
}

#gets channel names list and returns events list
sub get {
  my $self = shift;
  my $channels = shift;

  foreach my $name (keys(%{$channels})) {
    $self->log(PLUGIN_NAME, "Downloading schedule for " . $name, " ");
    $channels->{$name} = $self->getChannelEvents($name);
    $self->log("", "");
  }

  return $channels;
}

#gets channels list with each one's events and exports it
sub save {
  my $self = shift;
  my $events = shift;

  $self->log(PLUGIN_NAME, "This plugin doesn't support export.");
}

sub getChannelEvents {
	my $self = shift;
	my $name = shift;

	my $events = (); 

  my $days = $self->{'plugin_config'}->get('DAYS');
  my $browser = WWW::Mechanize->new( 'agent' => BROWSER );

  for(my $i=1; $i <= $days; $i++) {
    my $dateString  = time2str("%Y-%m-%d", time+(60*60*24*($i-1)));
    my $channel_uri = $self->findChannelUriByNameAndDate($name, $dateString);

    if (!$channel_uri) {
      $self->log(PLUGIN_NAME, "Could not find schedule for " . $name);
      next;
    }

    $browser->get($channel_uri);

    my $content = $browser->content();
    $content = encode('utf8', $content);
    if($content !~ /(.*)<div class="program">(.*)/sm) {
      $self->log("", "");
      $self->log(PLUGIN_NAME, "ERROR: Schedule for channel '$name' on '$dateString' not found!", " ");
      last;
    }

    while($content =~ s/.*?<div class="program">.*?<div class="programL">.*?<strong>(.*?)<\/strong>.*?<span>\((.*?)\)<\/span>.*?<div class="programR">.*?<h4><a title="(.*?)" href="(.*?)" onclick="return opis\('(.*?)', .*?\);">(.*?)<\/a>.*?<\/h4>.*?<p class="opis">(.*?)<\/p>.*?<p class="ekipa">(.*?)<\/p>(.*)/$9/sm) {
      my $hour    = $1;
      my $length  = $2;
      my $title   = $3;
      my $longUrl = $5;
      my $description  = $length.", ".$7;
      my $description2 = $8;

      last if $hour !~ /([0-9]{1,2}:[0-9]{2})/;

      #get full description if available and needed (follows another link so it costs time)
      if($self->{'plugin_config'}->get('FULL_DESCRIPTION') == 1 && $longUrl !~ //) {
        $browser->get($longUrl);
        my $tmp = $browser->content();
        $description  = $1.", ".$2 if $tmp =~ /.*?<div class="opis">(.*?)<\/div>.*?<p>(.*?)<\/p>/sm;
        $description2 = $1 if $tmp =~ /.*?<p class="ekipa">(.*?)<\/p>.*/sm;
      }

      #convert hour to unix timestamp, if it's after midnight, change base date string
      $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
      $hour = str2time($dateString." ".$hour);

      #create event
      my $event = Event->new();
      $event->set('start', $hour);
      $event->set('stop', $hour+1);
      $event->set('title', $title);
      $event->set('description', $self->clean($description));
      $event->set('description2', $self->clean($description2));

      #set the previous event stop timestamp
      my $previous = $#{$events};
      $events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;

      #put event to the events array
      push @{$events}, $event;
    }

    $self->log("", "#", " ");
  }

	return $events;
}

sub clean {
  my $self = shift;
  my $text = shift;

  $text =~ s/&nbsp;/ /smg;
  $text =~ s/<br(.*?)>/\n/smgi;
  $text =~ s/<(\/?)(.*?)>//smg;
  $text =~ s/\s+/ /g;

  return $text;
}

sub getChannels {
  my $self = shift;

  if (!$self->{'channels'}) {
    $self->{'channels'} = $self->parseChannelsFromWebsite();
  }

  return $self->{'channels'};
}

sub parseChannelsFromWebsite {
  my $self = shift;

	my $channels = {}; 
  my $browser  = WWW::Mechanize->new( 'agent' => BROWSER );

  $browser->get($self->{'url'});

  my $content = encode('utf8', $browser->content());

  while ($content =~ s/.*?<option (value|id)="([^"]+)" (value|id)="([^"]+)">(.*?)<\/option>(.*)/$6/sm) {
    my $id    = ("$1" eq 'id' ? $2 : $4);
    my $value = ("$3" eq 'value' ? $4 : $2);
    my $name  = $5;
    my $url   = $self->{'url'}.'/name,'.$id.',stid,'.$value.',time,0,program.html';

    $channels->{$name} = $url;
  }

  return $channels;
}

sub findChannelUriByName {
  my $self = shift;
  my $name = shift;

  my $channels = $self->getChannels();

  return $channels->{$name} || '';
}

sub findChannelUriByNameAndDate {
  my $self = shift;
  my $name = shift;
  my $date = shift;

  my $channel_uri = $self->findChannelUriByName($name);
  $channel_uri =~ s/name,/date,$date,name,/;

  return $channel_uri;
}

sub log {
  my $self = shift;
  my $sender = shift;
  my $message = shift;
  my $newLine = shift || "\n";

  Misc::pluginMessage($sender, $message, $newLine);
}

1;
