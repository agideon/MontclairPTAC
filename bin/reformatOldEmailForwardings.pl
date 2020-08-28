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
		my $destinations = [
		    grep { $_ !~ /^\s*:\s*(fail|blackhole)/; }	# Eliminate "fail" etc. actions
		    grep { $_ !~ /^\s*\|/; }			# Eliminate pipes
		    map { $_ =~ s/^\s*"(.*)"\s*$/$1/; $_; }	# Remove surrounding quotes
		    split(/\s*,\s*/, $destinationList)
		    ];

		if (scalar(@{$destinations}) > 0)
		{
		    $oldForwardings->{$address} = $destinations;
		}
#		print "Adding forwarding for $address\n";
#		print "\t", join("\n\t", @{$oldForwardings->{$address}}), "\n";
	    }
	}
    }
    return($oldForwardings);
}

sub detectTooLargeList($$)
{
    my ($oldForwardings, $limit) = @_;
    if (!defined($limit))
    {
	$limit = 10;
    }

    my $modified;

    do
    {
	$modified = 0; # assume no changes (yet);

	# Not using each() because the aarray may be modified
	my @aliases = keys(%{$oldForwardings});
	foreach my $alias (@aliases)
	{
	    my $destinations = $oldForwardings->{$alias};
	    if (scalar(@{$destinations}) > $limit)
	    {

		print "$alias destination list too large\n";
		my $midPoint = scalar(@{$destinations}) / 2;
		my @left = @{$destinations}[0..$midPoint-1];
#	    my @right = @{$destinations}[$midPoint..$#@{$destinations}];
		my @right = @{$destinations}[$midPoint..scalar(@{$destinations})-1];
		print "Splitting ", join(', ', @{$destinations}), " into\n\t", join(', ', @left), "\n\t", join(', ', @right), "\n";

		if ($alias =~ /^\s*([^@]+)@(.*)$/)
		{
		    my ($userpart, $hostname) = ($1, $2);
		    my ($leftaddr, $rightaddr) = ($userpart . '-left@' . $hostname, $userpart . '-right@' . $hostname);
		    $oldForwardings->{$alias} = [$leftaddr, $rightaddr];
		    $oldForwardings->{$leftaddr} = [@left];
		    $oldForwardings->{$rightaddr} = [@right];
		    $modified = 1;
		}
	    }
	}
    } while ($modified);

    return($oldForwardings);
}



sub main()
{
    my $oldForwardings = acceptInputForwardings();
    $oldForwardings = detectTooLargeList($oldForwardings, 3);

    print "Result: ", Dumper($oldForwardings);
}

main();

