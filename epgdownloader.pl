#!/usr/bin/perl -w
#EpgDownloader is a converter between various Electronic Program Guides.
#Copyright (C) 2005-2009 Jakub Zalas
#
#This program is free software; you can redistribute it and/or modify it under 
#the terms of the GNU General Public License as published by the Free Software 
#Foundation; either version 2 of the License, or (at your option) any later 
#version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT 
#ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
#FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with 
#this program; if not, write to the Free Software Foundation, Inc., 
#59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=pod

=head1 NAME

epgdownloader.pl

=head1 SYNOPSIS

 ./epgdownloader.pl

=head1 DESCRIPTION

EpgDownloader is a converter between various Electronic Program Guides. It is plugin based to make it easy to implement new formats. 

This script reads the main configuration file and checks for available plugins. After that it reads channels file which describes how the programme guide data should be imported and saved. The last thing is to run the proper plugins.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>

Date: june 2005, january-march 2006, february 2009

=cut

use strict;
use include::Misc;
use include::ConfigMain;
use include::Plugins;
use include::Channels;
use include::Event;

my $startTime = time;

#force to flush after every write or print
$|=1;

binmode(STDOUT, ":utf8");

#read config file
Misc::message("MAIN","Reading config file");
my $config = ConfigMain->new('config.xml');

#read available plugins
Misc::message("MAIN","Reading available plugins");
my $plugins = Plugins->new($config);
$plugins->printFound();

#read channels
Misc::message("MAIN","Reading channels");
my $channels = Channels->new($config, $plugins->get());

#run plugins
Misc::message("MAIN","Running plugins...");
$channels->convert();

Misc::message("MAIN","Finished in ".(time - $startTime)." seconds.");

1;
