package Config;
use strict;

=pod

=head1 NAME

Config - represents the configuration

=head1 SYNOPSIS

 use include::Config;
 $config = Conifg->new('fileName.xml','sectionName');

=head1 DESCRIPTION

Constructor sets config values found in config file given as arugment. Only values from given section are used. The section name is the second param. Config file is an xml file similar to this example:

<CONFIG>
	<SECTION NAME="MAIN">
		<OPTION NAME="OPTION_1" VALUE="1" DESCR="This is the first option" />
		<OPTION NAME="OTHER_OPTION" VALUE="Other option value" DESCR="Remember to set this value right" />
	</SECTION>

</CONFIG>

The DESCR attribute has only informative purpose.

Before constructor reads the file it sets default values by running defaults method. This method returns empty hash. Classes derivered from Config should overload the defaults method to set own default values.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: february 2006

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	my $section = shift;
	my $self = {};
	bless( $self, $class );
	
	$self = $self->defaults();

	#read file content
	open(CONFIG_FILE, "<$fileName") or die "Cant't open config file: $!";
  binmode(CONFIG_FILE, ":utf8");
	my $prevLimiter = $/;
	$/ = undef;
	my $content = <CONFIG_FILE>;
	$/ = $prevLimiter;
	close( CONFIG_FILE );

	#parse file content
	$content =~ s/(.*?)<CONFIG>(.*?)<\/CONFIG>(.*)/$2/smi;
	$content =~ s/(\s){2,}/ /smg;
	$content =~ s/(\s<)/</smg;

	#remove comments
	$content =~ s/<!--(.*?)\-\-\>//smg;
	
	#special treatment for '+'
	$content =~ s/\+/\\+/smg;

	while($content =~ s/<SECTION NAME="$section">(.*?)<\/SECTION>(.*)/$2/smi) {
		my $sectionContent = $1;
		
		while($sectionContent =~ s/<OPTION (.*?)>(.*)/$2/smi) {
			my $options = $1;

			#special treatment for '+'
			$options =~ s/\\\+/+/g;
			
			next if $options !~ /(.*)NAME(.*)/i || $options !~ /(.*)VALUE(.*)/i;

			my $name = $options;
			my $value = $options;

			$name =~ s/(.*?)NAME="(.*?)"(.*)/$2/i;
			$value =~ s/(.*?)VALUE="(.*?)"(.*)/$2/i;

			$name =~ tr/[a-z]/[A-Z]/;
			$self->{$name} = $value;
		}
	}

	return $self;
}

sub get {
	my $self = shift;
	my $name = shift;
	
	return $self->{$name} if defined($self->{$name});
	
	return "";
}

sub defaults {
	return {};
}

1;
