#!/usr/bin/perl -w

#config
use constant OUTPUT_FILE => "../channels.xml";
use constant PLUGIN_NAME => Interia;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use constant LIST_URL => "http://programtv.interia.pl/kanaly/wszystkie,10";
use constant BASE_URL => "http://programtv.interia.pl/kanaly/";

#include
use WWW::Mechanize;
use strict;

=pod

=head1 NAME

listchannels.pl - Lists channels available in Interia Plugin 

=head1 SYNOPSIS

./listchannels.pl

=head1 DESCRIPTION

Script connects to http://programtv.interia.pl website, checks which channels are available and saves it to file. Configuration is available by editing 'use constant' directives at the beginning of file.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006

=cut


#main

my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
$browser->get(LIST_URL);

#@todo From version 1.50 of WWW-Mechanize content is decoded by default. For now we have to handle it this way.
#my $content = $browser->content();
my $content = $browser->response()->decoded_content();

if($content !~ s/(.*?)<ul id="channelList">(.*?)<\/ul>(.*)/$2/sm) {
	print "Unable to find channels list.\n";
	exit;
}

open(FILE,">".OUTPUT_FILE);
binmode(FILE, ":utf8");

print FILE "<CHANNELS>\n";

#<a href="wszystkie/tvp-1,44,10?sDate=2008-10-06&sTimeF=22&sTimeT=4&sTimeT=4&cn=&p=1">TVP 1</a>

while($content =~ s/(.*?)<a href=\"(.*?)\">(.*?)<\/a>(.*)/$4/sm) {
	my $url = BASE_URL.$2;
	my $channel = $3;
	
	$channel =~ s/^[\s]//;
	$channel =~ s/[\s]$//;
	
	print FILE "\t<IMPORT NAME=\"".PLUGIN_NAME."\" CHANNEL=\"".$channel."\" DESCR=\"".$url."\">\n";
	print FILE "\t</IMPORT>\n";
}

print FILE "</CHANNELS>\n";

close(FILE);

print PLUGIN_NAME." plugin's available import channels saved to file ".OUTPUT_FILE."\n";

1;
