package ConfigMain;
use strict;
use include::Config;
@ConfigMain::ISA = qw(Config);

=pod

=head1 NAME

ConfigMain - represents the main configuration

=head1 SYNOPSIS

 use include::ConfigMain;
 $config = ConifgMain->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'MAIN' as second argument to get the main section config. Defaults method sets the default value. It also describes available options in the MAIN section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'MAIN');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'CHANNELS_FILE'		=> 'channels.xml',
		'PLUGINS_DIR'		=> 'plugins'
	};
}

1;
