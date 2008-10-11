package ConfigTelemanPl;
use strict;
use include::Config;
@ConfigTelemanPl::ISA = qw(Config);

=pod

=head1 NAME

ConfigTelemanPl - represents the TelemanPl plugin configuration

=head1 SYNOPSIS

 use include::ConfigTelemanPl;
 $config = ConfigTelemanPl->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'TelemanPl' as second argument to get the TelemanPl section config. Defaults method sets the default value. It also describes available options in the TelemanPl section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: october 2008

=cut

sub new {
  my $class    = shift;
  my $fileName = shift;

  my $self = $class->SUPER::new( $fileName, 'TelemanPl' );

  bless( $self, $class );
  return $self;
}

sub defaults {
  return {
    'DAYS'             => '1',
    'FULL_DESCRIPTION' => '0'
  };
}

1;


