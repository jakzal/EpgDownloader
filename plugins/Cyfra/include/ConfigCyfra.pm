package ConfigCyfra;
use strict;
use include::Config;
@ConfigCyfra::ISA = qw(Config);

=pod

=head1 NAME

ConfigCyfra - represents the Cyfra plugin configuration

=head1 SYNOPSIS

 use include::ConfigCyfra;
 $config = ConfigCyfra->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'Cyfra' as second argument to get the Interia section config. Defaults method sets the default value. It also describes available options in the Cyfra section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: <wrotkarz@gmail.com>.

Date: january 2009

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'Cyfra');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'			=> '7',
	};
}

1;
