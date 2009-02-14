package Interia;
use constant PLUGIN_NAME => Interia;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
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

Date: may 2006

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigInteria->new('config.xml');
	
	$self->{'url'} = 'http://programtv.interia.pl/kanaly/wszystkie,10';
	
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
	
	my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
	
	foreach my $name (keys(%{$channels})) {
		Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
		
		my $events = $channels->{$name};
		$browser->get($url);

		#special treatment for '+', '(', ')'
		$name =~ s/\+/\\\+/g;
		$name =~ s/\(/\\\(/g;
		$name =~ s/\)/\\\)/g;
	
		$browser->follow_link(text_regex => qr/$name$/);
	
		#special treatment for '+', '(', ')'
		$name =~ s/\\\+/+/g;
		$name =~ s/\\\(/\(/g;
		$name =~ s/\\\)/\)/g;
		
		my $base_uri = $browser->uri();
		
		for(my $i=1; $i <= $days; $i++) {
		
			my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i-1)));
			my $dateUnix = str2time($dateString);
			my $date_url = "";

      
      $base_uri =~ s/(sDate=[0-9]{4}-[0-9]{2}-[0-9]{2})/sDate=$dateString/;
      $base_uri =~ s/(sTimeF=(-|)[0-9]{1,2})/sTimeF=5/;
      $base_uri =~ s/(sTimeT=(-|)[0-9]{1,2})/sTimeT=4/;

			$browser->get($base_uri) if $i>1;

      #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
			#my $content = $browser->content();
      my $content = $browser->response()->decoded_content();
      if($content !~ s/.*?<table.*?class="channelCont".*?>(.*?)<\/table>/$1/sm) {
				Misc::pluginMessage("","");
				Misc::pluginMessage(
					PLUGIN_NAME,
					"ERROR: Schedule for channel '$name' on '$dateString' not found!"," ");
				last;
			}

			while($content =~ s/.*?<tr class="t[0-9]+">.*?<td class="hour".*?>(.*?)<\/td>.*?<td>(.*?)<\/td>.*?<\/tr>(.*)/$3/sm) {
				my $hour = $1;
				my $row = $2;

				last if $hour !~ s/(.*?)([0-9]{1,2}:[0-9]{2})(.*)/$2/sm;
				
				$row =~ s/.*?<a href="(.*?)">.*?<strong>(.*?)<\/strong>.*?<\/a>.*?<span class="type">[^a-zA-Z0-9]+([a-zA-Z0-9]+).*?<\/span>(.*)/$4/sm;
				
        my $fullDescriptionUrl = $1;
			  my $title = $2;
				my $category = $3;

        $row =~ s/.*?<div class="desc">(.*?)<\/div>.*/$1/sm;
				my $description = $row;
				my $description2 = "";
				
				#get full description if available and needed (follows another link so it costs time)
				if($fullDescription == 1 && $fullDescriptionUrl !~ /^$/) {
					$browser->get($fullDescriptionUrl);
					my $tmp = $browser->content();
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
				$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
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
