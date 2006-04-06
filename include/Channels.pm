package Channels;
use strict;
use paths;

=pod

=head1 NAME

Channels

=head1 DESCRIPTION

Channels class represents channels file. It describes references between import and export plugins. Channels file example:

<CHANNELS>
        <IMPORT NAME="IMPORT_PLUGIN_NAME_1" CHANNEL="Channel Name">
                <EXPORT NAME="EXPORT_PLUGIN_NAME_1" CHANNEL="Export Channel Name" />
                <EXPORT NAME="EXPORT_PLUGIN_NAME_2" CHANNEL="Export Channel Name" />
        </IMPORT>
        <IMPORT NAME="IMPORT_PLUGIN_NAME_1" CHANNEL="Other Channel Name">
                <EXPORT NAME="EXPORT_PLUGIN_NAME_1" CHANNEL="Channel Name" />
        </IMPORT>
        <IMPORT NAME="IMPORT_PLUGIN_NAME_2" CHANNEL="Some Channel Name">
                <EXPORT NAME="EXPORT_PLUGIN_NAME_2" CHANNEL="Some Channel Name" />
        </IMPORT>

</CHANNELS>

convert method gets all import plugins events. After that it sends it to proper export plugins and saves events in proper format.
Second param of constructor is plugins list. It helps to check each plugin from xml file for its existance.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march, april 2006

=cut

sub new {
	my $class = shift;
	my $config = shift;
	my $plugins = shift;
	my $self = {};
	
	my $fileName = $config->get('CHANNELS_FILE');
	
	$self->{'config'} = $config;

	#read file content
	open( CHANNELS_FILE, "<$fileName" ) or die "Cant't open '$fileName' file: $!";
	my $prevLimiter = $/;
	$/ = undef;
	my $content = <CHANNELS_FILE>;
	$/ = $prevLimiter;
	close( CHANNELS_FILE );

	#parse file content
	$content =~ s/(.*?)<CHANNELS>(.*?)<\/CHANNELS>(.*)/$2/smi;
	$content =~ s/(\s){2,}/ /smg;
	$content =~ s/(\s<)/</smg;

	#remove comments
	$content =~ s/<!--(.*?)\-\-\>//smg;
	
	my $availablePlugins = " ".join(" ", @{$plugins})." ";
	my $importPluginsTree = {};
	my $exportPluginsTree = {};

	while($content =~ s/<IMPORT (.*?)>(.*?)<\/IMPORT>(.*)/$3/smi) {
		my $importOptions = $1;
		my $exportContent = $2;

		my $importName = $importOptions;
		my $importChannel = $importOptions;

		$importName =~ s/(.*?)NAME="(.*?)"(.*)/$2/i;
		$importChannel =~ s/(.*?)CHANNEL="(.*?)"(.*)/$2/i;
		
		#check if plugin is available
		next if($availablePlugins !~ /[\s]$importName[\s]/);
		
		$importPluginsTree->{$importName} = {} if !exists($importPluginsTree->{$importName});
		
		$importPluginsTree->{$importName}->{$importChannel} = [] if !exists($importPluginsTree->{$importName}->{$importChannel});
		
		#special treatment for '+'
		$exportContent =~ s/\+/\\+/smg;
		
		while($exportContent =~ s/<EXPORT (.*?)(\s)?\/>(.*)/$3/smi) {
			my $exportOptions = $1;
			my $exportName = $exportOptions;
			my $exportChannel = $exportOptions;
			
			#special treatment for '+'
			$exportChannel =~ s/\\\+/+/smg;
			
			$exportName =~ s/(.*?)NAME="(.*?)"(.*)/$2/i;
			$exportChannel =~ s/(.*?)CHANNEL="(.*?)"(.*)/$2/i;
			
			#check if plugin is available
			next if($availablePlugins !~ /[\s]$exportName[\s]/);
			
			$exportPluginsTree->{$exportName} = {} if !exists($exportPluginsTree->{$exportName});
		
			$exportPluginsTree->{$exportName}->{$exportChannel} = {$importName => $importChannel};
		}
	}
	
	$self->{'import'} = $importPluginsTree;
	$self->{'export'} = $exportPluginsTree;

	bless( $self, $class );
	
	return $self;
}

sub convert {
	my $self = shift;
	
	#import
	foreach my $importPluginName (keys(%{$self->{'import'}})) {
		my $importPlugin = $importPluginName->new($self->{'config'});
		
		$self->{'import'}->{$importPluginName} = $importPlugin->get($self->{'import'}->{$importPluginName});
	}
	
	#export
	foreach my $exportPluginName (keys(%{$self->{'export'}})) {
		my $exportPlugin = $exportPluginName->new($self->{'config'});
		my $events = {};
		
		foreach my $exportChannelName (keys(%{$self->{'export'}->{$exportPluginName}})) {
			
			foreach my $importPluginName (keys(%{$self->{'export'}->{$exportPluginName}->{$exportChannelName}})){
				my $importChannelName = $self->{'export'}->{$exportPluginName}->{$exportChannelName}->{$importPluginName};
				
				$events->{$exportChannelName} = $self->{'import'}->{$importPluginName}->{$importChannelName};
			}
		}
		
		$exportPlugin->save($events);
	}
}

1;
