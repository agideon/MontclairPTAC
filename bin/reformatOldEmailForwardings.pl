#!/usr/bin/perl -w

use strict;
use Data::Dumper;

# This program is to be used "once" (hopefully) to convert the email forwardings on 
# the being-retired servint/leaseweb hosting to forwardings that can be used in
# GSuite as per https://support.google.com/a/answer/4524505?hl=en
#

sub isNonemptyString($)
{
    my ($s) = @_;
    return(defined($s) && ($s !~ /^\s*$/));
}



# Read forwardings line-by-line, filtering out pipes (for now, anyway), and
# decompose them into the multiple-line entries used by Google.
sub acceptInputForwardings()
{
    my $oldForwardings = {};
    while (defined(my $line = <>))
    {
	chomp($line);
	if ($line =~ /^\s*([^:]+)\s*:\s*(.*)$/)
	{
	    my ($address, $destinationList) = ($1, $2);
	    if (isNonemptyString($address) && isNonemptyString($destinationList))
	    {
		# Note: This would break if there were forwarding pipes with commas.  Fortunately, there
		# aren't any.
		my $destinations = [map { $_ =~ s/^\s*"(.*)"\s*$/$1/; $_; } split(/\s*,\s*/, $destinationList)];
		$oldForwardings->{$address} = $destinations;
#		print "Adding forwarding for $address\n";
#		print "\t", join("\n\t", @{$oldForwardings->{$address}}), "\n";
	    }
	}
    }
    print "Result: ", Dumper($oldForwardings);
}


acceptInputForwardings();
