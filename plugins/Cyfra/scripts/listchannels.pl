#!/usr/bin/perl -w

#config
use constant OUTPUT_FILE => "../channels.xml";
use constant PLUGIN_NAME => Cyfra;
use constant LIST_URL => "http://www.cyfraplus.pl/program/?";
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use constant TV_GUIDE_URL => "http://www.cyfraplus.pl/program/?";

#include
use WWW::Mechanize;
use strict;

=pod

=head1 NAME

listchannels.pl - Lists channels available in Cyfra Plugin 

=head1 SYNOPSIS

./listchannels.pl

=head1 DESCRIPTION

Script connects to http://cyfraplus.pl website, checks which channels are available and saves it to file. Configuration is available by editing 'use constant' directives at the beginning of file.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: <wrotkarz@gmail.com>.

Date: january 2009

=cut

#main

my $m = WWW::Mechanize->new();
my $res = $m->get(LIST_URL);
my $export = 1;

my $content = $res->decoded_content();
$content =~ /<select[^>]*?name\="?can\[\]"?[^>]*?>(.*?)<\/select.*>/si;
$content = $1;
open(FILE, ">".OUTPUT_FILE) or die 'file problem';
binmode FILE, ":utf8";
print FILE "<CHANNELS>\n";
while ($content =~ s/<option[^>]*?>([^<]+)(.*)/$2/si) {
	  print FILE "\t<IMPORT NAME=\"".PLUGIN_NAME."\" CHANNEL=\"$1\">\n";
    if ($export) {
      print FILE "\t\t<EXPORT NAME=\"xmltv\" CHANNEL=\"$1\" />\n";
    }
    print FILE "\t</IMPORT>\n";	  
}
print FILE "</CHANNELS>\n";
close(FILE);

print PLUGIN_NAME." plugin's available import channels saved to file ".OUTPUT_FILE."\n";

1;
