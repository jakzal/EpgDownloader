package ConfigMiGuiaTV;
use strict;
use include::Config;
@ConfigMiGuiaTV::ISA = qw(Config);

=pod

=head1 NAME

ConfigMiGuiaTV - represents the MiGuiaTV plugin configuration

=head1 SYNOPSIS

 use include::ConfigMiGuiaTV;
 $config = ConfigMiGuiaTV->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'MiGuiaTV' as second argument to get the MiGuiaTV section config. Defaults method sets the default value. It also describes available options in the MiGuiaTV section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'MiGuiaTV');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'			=> '1',
		'FULL_DESCRIPTION'	=> '0'
	};
}


1;
