#!/usr/bin/perl -w

#config
use constant OUTPUT_FILE => "../channels.xml";
use constant PLUGIN_NAME => UPC;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use constant LIST_URL => "http://przewodnik-tv.upclive.pl/TV/Guide/Channel/TVP1";
use constant BASE_URL => "http://przewodnik-tv.upclive.pl/TV/Guide/Channel/";

#include
use WWW::Mechanize;
use strict;

=pod

=head1 NAME

listchannels.pl - Lists channels available in UPC Plugin 

=head1 SYNOPSIS

./listchannels.pl

=head1 DESCRIPTION

Script connects to http://upclive.pl website, checks which channels are available and saves it to file. Configuration is available by editing 'use constant' directives at the beginning of file.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Marcin Jagoda <marcin@jagoda.be>.

Date: Nov 2006

=cut


#main

my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
$browser->get(LIST_URL);

my $content = $browser->content();

if($content !~ s/(.*?)<option value="WONoSelectionString">Wybierz kana.<\/option>(.*?)<\/select>(.*)/$2/sm) {
	print "Unable to find channels list.\n";
	exit;
}

open(FILE,">".OUTPUT_FILE);
binmode(FILE, ":utf8");

print FILE "<CHANNELS>\n";

while($content =~ s/(.*?)<option value=\"(.*?)\">(.*?)<\/option>(.*)/$4/sm) {
	my $url = BASE_URL.$2;
	my $channel = $3;
	
	$channel =~ s/^[\s]//;
	$channel =~ s/[\s]$//;
	$channel =~ s/&amp;/&/;
	
	print FILE "\t<IMPORT NAME=\"".PLUGIN_NAME."\" CHANNEL=\"".$channel."\" DESCR=\"".$url."\">\n";
	print FILE "\t</IMPORT>\n";
}

print FILE "</CHANNELS>\n";

close(FILE);

print PLUGIN_NAME." plugin's available import channels saved to file ".OUTPUT_FILE."\n";

1;
