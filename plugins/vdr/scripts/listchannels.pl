#!/usr/bin/perl -w

#config
use constant OUTPUT_FILE => "../channels.xml";
use constant CHANNELS_CONF => "/video/channels.conf";
use constant PLUGIN_NAME => "vdr";

#include
use strict;

=pod

=head1 NAME

listchannels.pl - Lists channels available in VDR

=head1 SYNOPSIS

./listchannels.pl

=head1 DESCRIPTION

Script lists available channels in channels.conf file.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut


#main

open(CHANNELS_FILE, "<".CHANNELS_CONF);
open(O_FILE, ">".OUTPUT_FILE);

print O_FILE "<CHANNELS>\n";
while(<CHANNELS_FILE>) {
	my $line = $_;
	
	my $channelName = $line;
	$channelName =~ s/^(.*?):(.*)$/$1/;
	
	$channelName =~ s/\n//g;
	
	next if $channelName =~ /^$/;
	
	print O_FILE "\t\t<EXPORT NAME=\"".PLUGIN_NAME."\" CHANNEL=\"".$channelName."\" />\n";
}
print O_FILE "</CHANNELS>\n";

close(O_FILE);
close(CHANNELS_FILE);

print PLUGIN_NAME." plugin's available export channels saved to file ".OUTPUT_FILE."\n";

1;
