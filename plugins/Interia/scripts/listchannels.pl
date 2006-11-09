#!/usr/bin/perl -w

#config
use constant OUTPUT_FILE => "../channels.xml";
use constant PLUGIN_NAME => Interia;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use constant LIST_URL => "http://program.interia.pl";

#include
use WWW::Mechanize;
use strict;

=pod

=head1 NAME

listchannels.pl - Lists channels available in Interia Plugin 

=head1 SYNOPSIS

./listchannels.pl

=head1 DESCRIPTION

Script connects to http://tv.interia.pl website, checks which channels are available and saves it to file. Configuration is available by editing 'use constant' directives at the beginning of file.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006

=cut


#main

my $browser = WWW::Mechanize->new( 'agent' => BROWSER );
	
$browser->get(LIST_URL);

$browser->submit_form(form_name => "nawigacja", fields => {'p' => "Wszystkie"});

my $content = $browser->content();

if($content !~ s/(.*?)<div(.*?)><b>Stacje:<\/b>(.*?)<\/div>(.*)/$3/sm) {
	print "Unable to find channels list.\n";
	exit;
}

open(FILE,">".OUTPUT_FILE);

print FILE "<CHANNELS>\n";

while($content =~ s/(.*?)<a class=stacja(.*?)href=\"(.*?)\">(.*?)<\/a>(.*)/$5/sm) {
	my $url = LIST_URL.$3;
	my $channel = $4;
	
	$channel =~ s/^[\s]//;
	$channel =~ s/[\s]$//;
	
	print FILE "\t<IMPORT NAME=\"".PLUGIN_NAME."\" CHANNEL=\"".$channel."\" DESCR=\"".$url."\">\n";
	print FILE "\t</IMPORT>\n";
}

print FILE "</CHANNELS>\n";

close(FILE);

print PLUGIN_NAME." plugin's available import channels saved to file ".OUTPUT_FILE."\n";

1;
