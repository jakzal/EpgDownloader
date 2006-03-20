package ConfigTvMovieDe;
use strict;
use include::Config;
@ConfigTvMovieDe::ISA = qw(Config);

=pod

=head1 NAME

ConfigTvMovieDe - represents the TvMovieDe plugin configuration

=head1 SYNOPSIS

 use include::ConfigTvMovieDe;
 $config = ConifgTvMovieDe->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'TvMovieDe' as second argument to get the TvMovieDe section config. Defaults method sets the default value. It also describes available options in the TvMovieDe section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'TvMovieDe');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'		=> '1'
	};
}


1;
