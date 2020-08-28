#!/usr/bin/perl -w

use strict;

# This program is to be used "once" (hopefully) to convert the email forwardings on 
# the being-retired servint/leaseweb hosting to forwardings that can be used in
# GSuite as per https://support.google.com/a/answer/4524505?hl=en
#

# Read forwardings line-by-line, filtering out pipes (for now, anyway), and
# decompose them into the multiple-line entries used by Google.
sub acceptInputForwardings()
{
    while (defined(my $line = <>))
    {
	chomp($line);
	if ($line =~ /^\s*([^:]+)\s*:\s*(.*)$/)
	{
	    my ($address, $destinations) = ($1, $2);
	    print "Address: $address\n\tDestinations: ", join("\n\t\t", split(/\s*,\s*/, $destinations)), "\n";
	}
    }
}


acceptInputForwardings();
