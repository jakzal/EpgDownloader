package Cyfra;
use constant PLUGIN_NAME => Cyfra;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Parse;
use Date::Format;
use DateTime;
use DateTime::Format::Strptime;
use plugins::Cyfra::include::ConfigCyfra;
use strict;

=pod

=head1 NAME

Cyfra - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://www.cyfraplus.pl website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: <wrotkarz@gmail.com>.

Date: january 2009

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigCyfra->new('config.xml');
	
	$self->{'url'} = 'http://www.cyfraplus.pl/program/?';
	
	bless( $self, $class );
	return $self;
}

sub checkContentDay ($$$$) {
  my $contentDay = \$_[0];
  my $name       = $_[1];
  my $dateString = $_[2];
  my $events     = $_[3];
  if (${$contentDay} !~ s/<tbody[^>]*?>(.+?)<\/tbody>/$1/si) {
		Misc::pluginMessage("","");
    Misc::pluginMessage(
      PLUGIN_NAME,
      "ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
    if (@{$events} > 0) { pop(@{$events}); }
    return;
	}
	return 1;
}

sub findChannel(\@$) {
  my @channels = @{(shift)};
  my $name = shift;
  
  foreach my $ref (@channels) {
    my @chan = @{$ref};
    if ($chan[1] eq $name) { return $chan[0]; }
  }
}

sub getBaseFields ($$$$$) {
  my $titleCell  = $_[0];
  my $title      = \$_[1];
  my $subtitle   = \$_[2];
  my $desc       = \$_[3];
  my $category   = \$_[4];
  
  
  $titleCell =~ s/<a[^>]*?>(.*?)<\/a>/$1/si;
  $titleCell =~ s/<i[^>]*?>(.*?)<\/i>/$1/si;
  
  $titleCell =~ /(.*?)<div[^>]*?class='desc'[^>]*?>(.*?)<\/div>/si;
  if (defined $2) {
    ${$title} = $1;
    ${$desc} = $2;
    ${$desc} =~ s/(<span[^>]*?>)(.*?)(<\/span>)(.*)/$2$4/si;
    ${$desc} =~ s/-&nbsp;/ /g;
    ${$desc} =~ s/&nbsp;/ /g;
    ${$desc} =~ s/<br \/>/\n/g;
    ${$desc} =~ s/\s+$//si;
  } else {
    ${$title} = $titleCell;
  }
  
  ${$title} =~ /<span[^>]*?>(.*?)\s*<\/span>/si;
  if (defined $1) {
    ${$subtitle} = $1;
    ${$title} =~ s/(.*?)<span[^>]*?>(.*?)<\/span>/$1/si;
    if (${$subtitle} =~ /-&nbsp;(.+)/si) {
      ${$category} = $1;
      ${$subtitle} =~ s/(.*?)\s*-&nbsp;.*/$1/si;
      if (${$category} =~ /odc.&nbsp;.+/si) {
        ${$category} =~ /odc.&nbsp;(.*)/si;
        ${$subtitle} .= " odc. $1";
        ${$category} =~ s/odc.&nbsp;.*//si;
      }
      ${$category} =~ s/\s+$//si;
    }
  }
  
  ${$title} =~ s/\s+$//si;

  return(-1);
}

sub parseDate ($$$) {
  my $dateStr  = $_[0];
  my $pattern  = $_[1];
  my $timeZone = $_[2];

  my $strpt = new DateTime::Format::Strptime(
  pattern => $pattern,
  locale => 'pl_PL',
  time_zone => $timeZone);
  my $dt = $strpt->parse_datetime($dateStr);
  return $dt;
}

sub parseDay($$$$$) {
  my $dayStr   = $_[0];
  my $pattern  = $_[1];
  my $dateMin  = $_[2];
  my $dateMax  = $_[3];
  my $timeZone = $_[4];

  my $dt = $dateMin->clone();
  while (DateTime->compare($dt, $dateMax) <= 0) {
    my $dtStr = $dt->strftime($pattern);
    $dtStr =~ s/^\s+//;
    return($dt) if ($dtStr eq $dayStr);
    $dt->add(days=>1);
  }
  return undef;
}

#gets channels from combo
#and dates range from combo
sub getChannelsAndDates (\$$$$$$) {
  my $browser  = $_[0];
  my $url      = $_[1];
  my $days     = $_[2];
  my $dateMin  = \$_[3];
  my $dateMax  = \$_[4];
  my $timeZone = $_[5];
  
  my $response = ${$browser}->get($url);
  my $content = $response->decoded_content() or die 'no response';
	
  #gets dates range form combo on page
  $content =~ /<select[^>]*?name\="?dmax"?[^>]*?>(.*?)<\/select.*>/si 
    or die 'date max. not found';
  my $dates = $1;
  my $dtMin;
  my $dtMax;
  while ($dates =~ s/<option[^>]*?value='(.*?)'[^>]*?>([^<]+)(.*)/$3/si) {
    if (parseDate($1,"%Y.%m.%d",$timeZone)) {
      $dtMin = $1 if (!defined $dtMin);
      $dtMax = $1;
    }
  }
  if (!defined $dtMin) { die 'date min. not found'; }
  if (!defined $dtMax) { die 'date max. not found'; }
  ${$dateMin} = parseDate($dtMin,"%Y.%m.%d",$timeZone);
  if (!defined ${$dateMin}) { die 'date min. not found'; }
  ${$dateMax} = parseDate($dtMax,"%Y.%m.%d",$timeZone);
  if (!defined ${$dateMax}) { die 'date max. not found'; }
  my $dt = DateTime->today();
  $dt->add( days => $days );
  ${$dateMax} = $dt if (DateTime->compare(${$dateMax},$dt) == 1);
  $content =~ /<select[^>]*?name\="?can\[\]"?[^>]*?>(.*?)<\/select.*>/si 
      or die 'channels not found';
  my $channels = $1;
  my @channelsCyfra;
  while ($channels =~ s/<option[^>]*?value='(\w+?)'[^>]*?>([^<]+)(.*)/$3/si) {
    my @channel = ($1, $2);
    push(@channelsCyfra, \@channel);
  }
  return @channelsCyfra;
}

sub getPageContent (\$$$$$$) {
  my $browser     = shift;
  my $days        = shift;
  my $dateMin     = shift;
  my $dateMax     = shift;
  my $channelCode = shift;
  my $url         = shift;

  my $dt = DateTime->today();
  for (my $i = 0; $i <= $days; $i++) {
    $dt->add(days => 1);
    last if (DateTime->compare($dt, $dateMax) == 0)
  }
  my $response;
  eval {
    ${$browser}->get($url);
    ${$browser}->form_name('find_program') or die 'no form';
    ${$browser}->select('dmin', $dateMin->strftime("%Y.%m.%d"));
    ${$browser}->select('dmax', $dt->strftime("%Y.%m.%d"));
    ${$browser}->select('can[]', $channelCode);
    ${$browser}->field('full', 'F');
    $response = ${$browser}->submit();
  };
  if ($@) {
    sleep(10);
    return '';
  }
  
  return $response->decoded_content();
}

#gets channel names list and returns events list
sub get {
  my $self = shift;
  my $channels = shift;
	
  my $days     = $self->{'plugin_config'}->get('DAYS');
  my $timeZone = $self->{'plugin_config'}->get('TIMEZONE');
  my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
  my $dateMax;
  my $dateMin;
  my @channelsCyfra = getChannelsAndDates(
                        $browser, $self->{'url'}, $days, 
                        $dateMin, $dateMax, $timeZone);
  
  foreach my $name (keys(%{$channels})) {
    Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");		
    my $events = $channels->{$name};
    my $channelCode = findChannel(@channelsCyfra, $name) or next;
    my $content = getPageContent($browser, $days, $dateMin, $dateMax, $channelCode, $self->{'url'}); # or die 'no response';
    if ($content eq ''){
     sleep(10);
     $content = getPageContent($browser, $days, $dateMin, $dateMax, $channelCode, $self->{'url'})
    }

    #open(FILE, ">./titles.txt") or die 'file problem';
    #binmode FILE, ":utf8";
    #print FILE "$content\n";
    #close(FILE);

    while ($content =~ s/<table class\=\'ptv-table no-margin tabela_v2\'>(.*?)<\/table>(.*)/$2/si) {
      my $contentDay = $1;
      ($contentDay =~ /<thead[^>]*?>\s*?<tr[^>]*?>\s*?<th[^>]*?>\s*?<span[^>]*?>(.*?)<\/span>\s*?<span[^>]*?>(.*?)<\/span>\s*?<\/th>\s*?<\/tr>\s.*?<\/thead>/si) || last;
      my $date = parseDay($2,"%e %B, %A", $dateMin, $dateMax, $timeZone);
      my $dateLast = $date->clone();
      last if (!defined $date);
      checkContentDay($contentDay, $name, $date, $events) or last;
      while ($contentDay =~ s/<tr[^>]*?>\s*?<td[^>]*?>(.*?)<\/td>\s*?<td[^>]*?>(.*?)<\/td>\s*?<td[^>]*?>(.*?)<\/td>\s*?<\/tr>(.*)/$4/si) {
        my $hour = $1;
        my $titleCell = $2;
        $hour =~ s/\s*<span[^<]*?>(.*?)<\/span>\s*/$1/si;
        $titleCell =~ s/\n/ /;;
        my $title = '';
        my $subtitle = '';
        my $desc = '';
        my $category = '';
        
        getBaseFields($titleCell, $title, $subtitle, $desc, $category) or next;
        my $evtDate = $date->clone();
	my $time = parseDate($hour, "%H:%M",$timeZone);
	$evtDate->add(hours => $time->hour(), minutes => $time->minute());
	$evtDate->add( days => 1 ) if (DateTime->compare($evtDate, $dateLast) < 0);
	$dateLast = $evtDate->clone();
										
	#create event
	my $event = Event->new();
	$event->set('start', $evtDate->epoch());
	$event->set('stop', $evtDate->clone->add(hours => 1)->epoch());
	$event->set('title',$title);
	$event->set('title2',$subtitle);
	$event->set('description',$desc);
	$event->set('category',$category);
	#set the previous event stop timestamp
	my $previous = $#{$events};
	$events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;

	#put event to the events array
	push @{$events}, $event;
	
      }
      undef $date;
      Misc::pluginMessage("","#"," ");
    }
      
      if (@{$events} > 0) { pop(@{$events}); }
		Misc::pluginMessage("","");
	}
	#categoriesPrint(\@categoriesArray);
	return $channels;
}

#gets channels list with each one's events and exports it
sub save {
	my $self = shift;
	my $events = shift;
	
	Misc::pluginMessage(PLUGIN_NAME,"This plugin doesn't support export.");
}

1;
