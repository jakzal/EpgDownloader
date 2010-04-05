package ConfigInteria;
use strict;
use include::Config;
@ConfigInteria::ISA = qw(Config);

=pod

=head1 NAME

ConfigInteria - represents the Interia plugin configuration

=head1 SYNOPSIS

 use include::ConfigInteria;
 $config = ConfigInteria->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'Interia' as second argument to get the Interia section config. Defaults method sets the default value. It also describes available options in the Interia section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: may 2006

=cut

sub new {
  my $class = shift;
  my $fileName = shift;

  my $self = $class->SUPER::new($fileName,'Interia');

  bless( $self, $class );
  return $self;
}

sub defaults {
  return {
    'DAYS'             => '1',
    'FULL_DESCRIPTION' => '0',
    'THREADS'          => '5'
  };
}


1;
