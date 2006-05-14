package ConfigEuroTV;
use strict;
use include::Config;
@ConfigEuroTV::ISA = qw(Config);

=pod

=head1 NAME

ConfigEuroTV - represents the EuroTV plugin configuration

=head1 SYNOPSIS

 use include::ConfigEuroTV;
 $config = ConfigEuroTV->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'EuroTV' as second argument to get the EuroTV section config. Defaults method sets the default value. It also describes available options in the EuroTV section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'EuroTV');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'			=> '1'
	};
}


1;
