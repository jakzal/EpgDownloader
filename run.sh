#!/bin/sh
#This script can be used to run EpgDownloader from outside of its directory

PERL=`which perl`
PATH=`echo "$0" | sed -e 's/\(.*\)\/\(.*\)/\1/' -`

cd $PATH > /dev/null
$PERL epgdownloader.pl
cd - > /dev/null
