package Event;
use strict;

=pod

=head1 NAME

Event

=head1 DESCRIPTION

Event represents single event. It should provide a standard interface to pass event data between plugins. This class should be extended if new properties are needed for new import/export plugins.

Import plugin method should return an array of events. Export plugin method should take a hash of tv channels name poitning to its events.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut

sub new {
	my $class = shift;
	
	my $self = {
		'id' 			=> '',
		'start'			=> '',
		'stop'			=> '',
		'title'			=> '',
		'title2'		=> '',
		'description'		=> '',
		'description2'		=> '',
		'category'		=> '',
		'credits'		=> '',
		'country'		=> '',
		'date'			=> ''
	};
	
	bless( $self, $class );
	return $self;
}

sub set {
	my $self = shift;
	my $name = shift;
	my $value = shift;
	
	$self->{$name} = $value if exists $self->{$name};
}

sub get {
	my $self = shift;
	my $name = shift;
	
	return $self->{$name} if exists $self->{$name};
	
	return 0;
}

1;
