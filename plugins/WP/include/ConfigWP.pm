package ConfigWP;
use strict;
use include::Config;
@ConfigWP::ISA = qw(Config);

=pod

=head1 NAME

ConfigWP - represents the WP plugin configuration

=head1 SYNOPSIS

 use include::ConfigWP;
 $config = ConifgWP->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'WP' as second argument to get the WP section config. Defaults method sets the default value. It also describes available options in the WP section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'WP');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'		=> '1'
	};
}


1;
