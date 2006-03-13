package Misc;
use strict;

=pod

=head1 NAME

Misc

=head1 DESCRIPTION

This package contains various handy subroutines.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march 2006

=cut
sub message {
	my $sender = shift;
	my $message = shift;
	my $newLine = shift || "\n";
	
	$sender = "[".$sender."] " if $sender ne "";
	
	print $sender.$message.$newLine;
}

sub pluginMessage {
	my $sender = shift;
	my $message = shift;
	my $newLine = shift || "\n";

	$sender = " <".$sender."> " if $sender ne "";

	print $sender.$message.$newLine;
}

1;
