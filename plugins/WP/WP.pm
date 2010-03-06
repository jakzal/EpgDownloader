package WP;
use constant PLUGIN_NAME => WP;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
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

Date: march, april 2006, october 2008

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigWP->new('config.xml');
	
	$self->{'url'} = 'http://tv.wp.pl/katn,Lista kana��w,programy.html';
	
	bless( $self, $class );
	return $self;
}

#gets channel names list and returns events list
sub get {
	my $self = shift;
	my $channels = shift;
	
	my $url = $self->{'url'};
	
	my $days 		= $self->{'plugin_config'}->get('DAYS');
	my $fullDescription 	= $self->{'plugin_config'}->get('FULL_DESCRIPTION');
	
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
		
		my $events = $channels->{$name};
	
		my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
	
		$browser->get($url);
	
		#special treatment for '+', '(', ')'
		$name =~ s/\+/\\\+/g;
		$name =~ s/\(/\\\(/g;
		$name =~ s/\)/\\\)/g;

    my $channelRegex = qr/$name$/;
    
    if (!$browser->find_link(text_regex => $channelRegex)) {
      Misc::pluginMessage(PLUGIN_NAME,"Could not find schedule for ".$name);
      next;
    }
	
		$browser->follow_link(text_regex => $channelRegex);
	
		#special treatment for '+', '(', ')'
		$name =~ s/\\\+/+/g;
		$name =~ s/\\\(/\(/g;
		$name =~ s/\\\)/\)/g;
		
		my $base_uri = $browser->uri();
		
		for(my $i=1; $i <= $days; $i++) {
		
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i-1)));
			my $dateUnix = str2time($dateString);
			my $date_url = "";
			
			$browser->get($base_uri."&T[date]=".$dateString."&T[time]=0") if $i>1;
		
      #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
			#my $content = $browser->content();
      my $content = $browser->response()->decoded_content();
			if($content !~ s/(.*)<table(.*?)>(.*?)Program na(.*?)<\/table>(.*)/$4/sm) {
				Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
				last;
			}
			$content =~ s/(.*?)<\/div>(.*)/$2/sm;
	
			while($content =~ s/(.*?)<tr>(.*?)<\/tr>(.*)/$3/sm) {
				my $row = $2;
	
				my $hour = $row;
				last if $hour !~ s/(.*?)<b>([0-9]{1,2}:[0-9]{2})<\/b>(.*)/$2/sm;
				
				my $title = $3;
				$title =~ s/(.*?)<b>(.*?)<\/b>(.*)/$2/sm;
		
				my $description = $3;
				my $description2 = "";
				
        $description =~ s/(.*?)<span(.*?)>(.*?)<\/span>(.*)/$3/sm;
        $description =~ s/<a href="javascript:okno.*?".*?>.*?<\/a>//smg;
        $description =~ s/(&nbsp;|&raquo;)//smg;
				
				#get full description if available and needed (follows another link so it costs time)
				if($fullDescription == 1 && $title =~ /(.*?)javascript:okno\(\'(.*?)\'(.*)/) {
					$browser->get($2);
          #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
					#my $tmp = $browser->content();
          my $tmp = $browser->response()->decoded_content();
					$description  = $1 if $tmp =~ /.*?<p class="op">(.*?)<\/p>.*/sm;
					$description2 = $1 if $tmp =~ /.*?<p class="wystepuja">(.*?)<\/p>.*/sm;
          $description2.= $1 if $tmp =~ /.*?<span class="czas">(.*?)<\/span>.*/sm;
				}
				
				#remove html tags from title
				$title =~ s/<(\/?)(.*?)>//smg;
		
				#removing trash from description
				$description  =~ s/<br(.*?)>/\n/smgi;
				$description  =~ s/<(\/?)(.*?)>//smg;
        $description  =~ s/\s+/ /g;
				$description2 =~ s/<br(.*?)>/\n/smgi;
				$description2 =~ s/<(\/?)(.*?)>//smg;
        $description2 =~ s/\s+/ /g;
		
				#convert hour to unix timestamp, if it's after midnight, change base date string
				$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
				$hour = str2time($dateString." ".$hour);
	
				#create event
				my $event = Event->new();
				$event->set('start',$hour);
				$event->set('stop',$hour+1);
				$event->set('title',$title);
				$event->set('description',$description);
				$event->set('description2',$description2);
	
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
