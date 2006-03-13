package ConfigXmltv;
use strict;
use include::Config;
@ConfigXmltv::ISA = qw(Config);

=pod

=head1 NAME

ConfigXmltv - represents the xmltv plugin configuration

=head1 SYNOPSIS

 use include::ConfigXmltv;
 $config = ConifgXmltv->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'xmltv' as second argument to get the xmltv section config. Defaults method sets the default value. It also describes available options in the xmltv section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'xmltv');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'OUTPUT_FILE'		=> 'xmltv.xml',
		'HEADER_ENCODING'	=> 'ISO-8859-1',
		'TIMEZONE'		=> '+0100'
	};
}

1;
