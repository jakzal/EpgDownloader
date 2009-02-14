package TelemanPl;
use constant PLUGIN_NAME => TelemanPl;
use constant BROWSER     => 'Opera/7.54 (X11; Linux i686; U)';
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use plugins::TelemanPl::include::ConfigTelemanPl;
use strict;

=pod

=head1 NAME

TelemanPl - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://www.teleman.pl website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: october 2008

=cut

sub new {
  my $class  = shift;
  my $config = shift;

  my $self = {};

  $self->{'config'}        = $config;
  $self->{'plugin_config'} = ConfigTelemanPl->new('config.xml');

  $self->{'url'} = 'http://www.teleman.pl/station.html';

  bless( $self, $class );
  return $self;
}

#gets channel names list and returns events list
sub get {
  my $self     = shift;
  my $channels = shift;

  my $url = $self->{'url'};

  my $days            = $self->{'plugin_config'}->get('DAYS');
  my $fullDescription = $self->{'plugin_config'}->get('FULL_DESCRIPTION');

  foreach my $name ( keys( %{$channels} ) ) {
    Misc::pluginMessage( PLUGIN_NAME, "Downloading schedule for " . $name,
      " " );

    my $events = $channels->{$name};

    my $browser = WWW::Mechanize->new( 'agent' => BROWSER );

    $browser->get($url);

    #special treatment for '+', '(', ')'
    $name =~ s/\+/\\\+/g;
    $name =~ s/\(/\\\(/g;
    $name =~ s/\)/\\\)/g;

    $browser->follow_link( text_regex => qr/$name$/ );

    #special treatment for '+', '(', ')'
    $name =~ s/\\\+/+/g;
    $name =~ s/\\\(/\(/g;
    $name =~ s/\\\)/\)/g;

    my $base_uri = $browser->uri();

    for ( my $i = 0 ; $i < $days ; $i++ ) {
      $browser->get( $base_uri . "&day=" . $i ) if $i > 0;

      my $dateString = time2str( "%Y-%m-%d", time + ( 60 * 60 * 24 * ( $i ) ) );
      #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
      #my $content = $browser->content();
      my $content = $browser->response()->decoded_content();
      
      if ( $content !~
        s/.*<table id="programmes" cellspacing="0">(.*?)<\/table>(.*)/$1/sm )
      {
        Misc::pluginMessage( "", "" );
        Misc::pluginMessage( PLUGIN_NAME,
          "ERROR: Schedule for channel '$name' on '$dateString' not found!",
          " " );
        last;
      }

      while (
        $content =~ s/.*?<tr><th>.*?([0-9]{1,2}:[0-9]{1,2}).*?<\/th><td>(.*?)<\/td><\/tr>(.*)/$3/sm )
      {
        my $hour           = $1;
        my $description    = $2;
        my $description2   = "";
        my $category       = "";
        my $descriptionUrl = "";
        my $title          = "";

        $description =~ /<a href="(.*?)" title=".*?">(.*?)<\/a>/;
        $descriptionUrl = $1;
        $title          = $2;

        $category     = $1 if $description =~ /<span class="categ.*?">(.*?)<\/span>/;
        $description2 = $2 if $category =~ s/(.*), (.*)/$1/;
        $description  =~ s/.*?<p>(.*?)<\/p>.*/$1/;

        #get full description if available and needed (follows another link so it costs time)
        if($fullDescription == 1 && $descriptionUrl =~ /\/prog.*/) {
          $browser->get($descriptionUrl);
          #@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
          #my $tmp = $browser->content();
          my $tmp = $browser->response()->decoded_content();
          $description = $1 if $tmp =~ /.*?<div class="desc">(.*?)<\/div>.*/sm;
        }
        
        #remove html tags from title
        $title =~ s/<(\/?)(.*?)>//smg;

        #removing trash from description
        $description  =~ s/<br(.*?)>/\n/smgi;
        $description  =~ s/<(\/?)(.*?)>//smg;
        $description2 =~ s/<br(.*?)>/\n/smgi;
        $description2 =~ s/<(\/?)(.*?)>//smg;

        #convert hour to unix timestamp, if it's after midnight, change base date string
        $dateString = time2str( "%Y-%m-%d", time + ( 60 * 60 * 24 * ($i + 1) ) )
          if $hour =~ /0[0-3]{1}:[0-9]{2}/;
        $hour = str2time( $dateString . " " . $hour );

        #create event
        my $event = Event->new();
        $event->set( 'start',        $hour );
        $event->set( 'stop',         $hour + 1 );
        $event->set( 'title',        $title );
        $event->set( 'category',     $category );
        $event->set( 'description',  $description );
        $event->set( 'description2', $description2 );

        #set the previous event stop timestamp
        my $previous = $#{$events};
        $events->[$previous]->set( 'stop', $event->{'start'} )
          if $previous > -1;

        #put event to the events array
        push @{$events}, $event;
      }

      Misc::pluginMessage( "", "#", " " );
    }

    Misc::pluginMessage( "", "" );
  }

  return $channels;
}

#gets channels list with each one's events and exports it
sub save {
  my $self   = shift;
  my $events = shift;

  Misc::pluginMessage( PLUGIN_NAME, "This plugin doesn't support export." );
}

1;


