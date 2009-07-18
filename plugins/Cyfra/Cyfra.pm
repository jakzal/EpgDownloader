package Cyfra;
use constant PLUGIN_NAME => Cyfra;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Parse;
use Date::Format;
use DateTime;
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
	
	$self->{'url'} = 'http://www.cyfraplus.pl/program/abo/?';
	
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

sub fillDates($$) {
  my $days    = shift;
  my $dateMax = shift;
  my $dt = DateTime->now(locale => "pl_PL");
  my @dates;
  for (my $i = 0; $i < $days; $i++) {
    my @dateArr = ($dt->strftime("%e %B, %A"), $dt->epoch());
    $dateArr[0] =~ s/^\s*//;
    push(@dates, \@dateArr);
    if ($dt->strftime("%Y.%m.%d") eq $dateMax) { 
      return @dates 
    };
    $dt->add(days => 1);
  }
  return @dates;
}

sub getBaseFields (\@$$$) {
  my $titleArray = $_[0];
  my $title      = \$_[1];
  my $subtitle   = \$_[2];
  my $desc       = \$_[3];
  
  (${$title} = $titleArray->[0]) =~ s/(<a[^>]*?>)(.*?)(<\/a>)(.*)/$2$4/si;
  if (${$title} =~ s/\s*<i[^>]*?>(.*?)<\/i>(\s*-\s*|\s*)(.*)/$3/si) {
            ${$desc} = "$1\n";
  }
  if (${$title} =~ s/\s*?(.*?)\s*?<span[^>]*?>(.*?)<\/span>/$1/si) {
    ${$subtitle} = $2;
    ${$subtitle} =~ s/-&nbsp;/ /g;
    ${$subtitle} =~ s/&nbsp;/ /g;
    ${$subtitle} =~ s/^(\s*)//;
    ${$subtitle} =~ s/(\s*)$//;
            
  }
  ${$title} =~ s/^\s*//;
  ${$title} =~ s/\s*$//;
  if ($titleArray->[1] 
      && $titleArray->[1] =~ /\s*?<span[^<]*?>(.*?)<\/span>\s*/si) {
    ${$desc} = "${$desc}$1\n";
  }
  if ($titleArray->[2] 
      && $titleArray->[2] =~ /\s*?<span[^<]*?>(.*?)<\/span>\s*/si) {
    ${$desc} = "${$desc}$1";
  }
  
}

#gets channels from combo
#and max. date from combo
sub getChannels (\$$$) {
  my $browser = $_[0];
  my $url     = $_[1];
  my $dateMax = \$_[2];
  
  ${$browser}->get($url);
  my $response = ${$browser}->submit();
	my $content = $response->decoded_content() or die 'no response';
	
	#gets max date form combo on page
	$content =~ /<select[^>]*?name\="dmax"[^>]*?>(.*?)<\/select.*>/si 
      or die 'date max. not found';
  my $dates = $1;
  while ($dates =~ s/<option[^>]*?value='(.+?)'[^>]*?>([^<]+)(.*)/$3/si) {
    ${$dateMax} = $1;
  }
  if (! ${$dateMax}) { die 'date max. not found'; }
	
  $content =~ /<select[^>]*?name\=can\[\][^>]*?>(.*?)<\/select.*>/si 
      or die 'channels not found';
  my $channels = $1;
  my @channelsCyfra;
  while ($channels =~ s/<option[^>]*?value='(\w+?)'[^>]*?>([^<]+)(.*)/$3/si) {
    my @channel = ($1, $2);
    push(@channelsCyfra, \@channel);
  }
  return @channelsCyfra;
}

sub getDate (\@$$$) {
  my $datesRef   = $_[0];
  my $dateStr    = $_[1];
  my $events     = $_[2];
  my $name       = $_[3];
  my $dt;
  while (@{$datesRef}) {
    $dt = shift(@{$datesRef});
    if ($dt->[0] eq $dateStr) {
      return $dt->[1];
    }
  }
	Misc::pluginMessage("","");
	Misc::pluginMessage(
	    PLUGIN_NAME, 
	    "ERROR: Schedule for channel '$name' on '$dateStr' not ok!"," ");
  if (@{$events} > 0) { pop(@{$events}); }
}

sub getPageContent (\$$$$) {
  my $browser = shift;
  my $days = shift;
  my $channelCode = shift;
  my $url = shift;

  my $dateMinString = time2str("%Y.%m.%d",time);
  my $dateMaxString = time2str("%Y.%m.%d",time+(60*60*24*($days-1)));

  ${$browser}->get($url);
  ${$browser}->form_name('find_program') or die 'no form';
  ${$browser}->select('dmin', $dateMinString);
  ${$browser}->select('dmax', $dateMaxString);
  ${$browser}->select('can[]', $channelCode);
  ${$browser}->field('full', 'F');
  
  my $response = ${$browser}->submit();
  return $response->decoded_content();
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $days = $self->{'plugin_config'}->get('DAYS');
  my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
  my $dateMax;
  my @channelsCyfra = getChannels($browser, $self->{'url'}, $dateMax);
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");		
		my $events = $channels->{$name};
    my $channelCode = findChannel(@channelsCyfra, $name) or next;
    my $content = getPageContent($browser, $days, $channelCode, $self->{'url'}) or die 'no response';
    my @dates = fillDates($days, $dateMax) or die 'faild to fill dates array';
    while ($content =~ s/<table class\=\'ptv-table\'>(.*?)<\/table>(.*)/$2/si) {
      my $contentDay = $1;
      ($contentDay =~ /<thead[^>]*?>\s*?<tr[^>]*?>\s*?<th[^>]*?>\s*?<span[^>]*?>(.*?)<\/span>\s*?<span[^>]*?>(.*?)<\/span>\s*?<\/th>\s*?<\/tr>\s.*?<\/thead>/si) || last;
		  my $dateUnix = getDate(@dates, $2, $events, $name) or last;
		  my $dateString = time2str("%Y-%m-%d",$dateUnix);
		  checkContentDay($contentDay, $name, $dateString, $events) or last;
      while ($contentDay =~ s/<tr[^>]*?>\s*?<td[^>]*?>(.*?)<\/td>\s*?<td[^>]*?>(.*?)<\/td>\s*?<td[^>]*?>(.*?)<\/td>\s*?<\/tr>(.*)/$4/si) {
        my $hour = $1;
        my $titleCell = $2;
        $hour =~ s/\s*<span[^<]*?>(.*?)<\/span>\s*/$1/si;
        $titleCell =~ s/\n/ /;;
        my $title = '';
        my $subtitle = '';
        my $desc = '';
        my @titleArray;
        
        while ($titleCell =~ s/(.*?)(<br>)(.*)/$3/si) { push(@titleArray, $1);}
        push(@titleArray, $titleCell);
        getBaseFields(@titleArray, $title, $subtitle, $desc) or next;
				$dateString = time2str("%Y-%m-%d",$dateUnix+(24*60*60)) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
				$hour = str2time($dateString." ".$hour);
					
				#create event
				my $event = Event->new();
				$event->set('start',$hour);
				$event->set('stop',$hour+1);
				$event->set('title',$title);
				$event->set('title2',$subtitle);
				$event->set('description',$desc);
	
				#set the previous event stop timestamp
				my $previous = $#{$events};
				$events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;
			
				#put event to the events array
				push @{$events}, $event;
				
        undef @titleArray;
			}
	
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
