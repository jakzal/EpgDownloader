package ConfigUPC;
use strict;
use include::Config;
@ConfigUPC::ISA = qw(Config);

=pod

=head1 NAME

ConfigUPC - represents the UPC plugin configuration

=head1 SYNOPSIS

 use include::ConfigUPC;
 $config = ConfigUPC->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'UPC' as second argument to get the UPC section config. Defaults method sets the default value. It also describes available options in the UPC section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Marcin Jagoda <marcin@jagoda.be>.

Date: Nov 2008

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'UPC');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'			=> '1',
		'FULL_DESCRIPTION' 	=> '0'
	};
}


1;
