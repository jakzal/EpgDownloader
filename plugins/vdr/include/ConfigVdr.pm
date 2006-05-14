package ConfigVdr;
use strict;
use include::Config;
@ConfigVdr::ISA = qw(Config);

=pod

=head1 NAME

ConfigVdr - represents the vdr plugin configuration

=head1 SYNOPSIS

 use include::ConfigVdr;
 $config = ConfigVdr->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'vdr' as second argument to get the vdr section config. Defaults method sets the default value. It also describes available options in the vdr section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'vdr');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'CHANNELS_CONF'		=> '/video/channels.conf',
		'OUTPUT_FILE'		=> 'epg.data',
		'INPUT_FILE'		=> '/video/epg.data',
		'START_EPISODE_ID'	=> '1'
	};
}

1;
