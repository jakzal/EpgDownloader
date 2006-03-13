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

Date: march 2006

=cut

sub new {
	my $class = shift;
	my $config = shift;
	
	my $self = {};

	$self->{'config'} = $config;
	$self->{'plugin_config'} = ConfigWP->new('config.xml');
	
	$self->{'url'} = 'http://tv.wp.pl/katn,Lista kana³ów,programy.html';
	
	bless( $self, $class );
	return $self;
}

#gets single channel name and returns events list
sub get {
	my $self = shift;
	my $name = shift;
	
	my $events = ();
	my $url = $self->{'url'};
	
	Misc::pluginMessage(PLUGIN_NAME,"Downloading schedule for ".$name," ");
	
	my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
	
	$browser->get($url);
	
	#special treatment for '+', '(', ')'
	$name =~ s/\+/\\\+/g;
	$name =~ s/\(/\\\(/g;
	$name =~ s/\)/\\\)/g;
	
	$browser->follow_link(text_regex => qr/$name/);
	
	#special treatment for '+', '(', ')'
	$name =~ s/\\\+/+/g;
	$name =~ s/\\\(/\(/g;
	$name =~ s/\\\)/\)/g;
	
	my $base_uri = $browser->uri();
	
	for(my $i=1; $i <= $self->{'plugin_config'}->get('DAYS'); $i++) {
	
		my $dateString = time2str("%Y-%m-%d",time+(60*60*24*($i-1)));
		my $dateUnix = str2time($dateString);
		my $date_url = "";

		$browser->get($base_uri."&T[date]=".$dateString."&T[time]=0") if $i>1;
	
		my $content = $browser->content();
		
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
			$hour =~ s/(.*?)<b>([0-9]{1,2}:[0-9]{2})<\/b>(.*)/$2/sm;
			
			my $title = $3;
			$title =~ s/(.*?)<b>(.*?)<\/b>(.*)/$2/sm;
	
			my $description = $3;
			$description =~ s/(.*?)<span(.*?)>(.*?)<\/span>(.*)/$3/sm;
			$description =~ s/<br>/\n/smg;
	
			#remove html tags from title
			$title =~ s/<(\/?)(.*?)>//smg;
	
			#removing trash from description
			$description =~ s/<(\/?)(.*?)>//smg;
			$description =~ s/(wiêcej|&nbsp;|&raquo;)//smg;
	
			#convert hour to unix timestamp, if it's after midnight, change base date string
			$dateString = time2str("%Y-%m-%d",time+(60*60*24*($i))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
			$hour = str2time($dateString." ".$hour);

			#create event
			my $event = Event->new();
			$event->set('start',$hour);
			$event->set('stop',$hour+1);
			$event->set('title',$title);
			$event->set('description',$description);
	
			#set the previous event stop timestamp
			my $previous = $#{$events};
			$events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;
			
			#put event to the events array
			push @{$events}, $event;

		}

		Misc::pluginMessage("","#"," ");
	}

	Misc::pluginMessage("","");

	return $events;
}

#gets channels list with each one's events and exports it
sub save {
	my $self = shift;
	my $events = shift;
	
	Misc::pluginMessage(PLUGIN_NAME,"This plugin doesn't support export.");
}

1;
