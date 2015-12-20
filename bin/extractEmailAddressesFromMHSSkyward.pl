#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;
use Getopt::Long;
use FileHandle;

#####################################################################
# The idea is to provide a way to access the columns by column label.
# Is this a good idea?  I don't know.  I suspect that column order is
# more stable than column label, but this depends upon the person/program
# generating the input files over time and both are somewhat unknown to me.
# So: we'll see.
#
{
	my $headerColumns = {};

	# Invoked at startup to acquire and store the name->index mapping
	sub learnColumnHeaders(@)
	{
		my @headers = @_;
		my $index = 0;
		foreach my $header (@headers)
		{
			$headerColumns->{lc($header)} = $index;
			$index++;
		}
	}

	# Accessor of name->index mapping
	sub rowIndexByHeader($)
	{
		my ($header) = @_;
		my $index = $headerColumns->{lc($header)};
		return($index);
	}
}



sub compareEmailAddressPairByServer($$)
{
    my ($a, $b) = @_;
    my ($a_base, $a_host, $b_base, $b_host);
    if ($a =~ /^([^@]*)@(.*)$/)
    {
	($a_base, $a_host) = ($1, $2);
    }
    else
    {
	($a_base, $a_host) = ($a, ''); # Should never occur!
    }
    if ($b =~ /^([^@]*)@(.*)$/)
    {
	($b_base, $b_host) = ($1, $2);
    }
    else
    {
	($b_base, $b_host) = ($b, ''); # Should never occur!
    }
    my $rval = lc($a_host) cmp lc($b_host);
    if ($rval == 0)
    {
	$rval = lc($a_base) cmp lc($b_base);
    }
    return($rval);
}




sub main()
{
	my ($filenameIn, $filenameOut);

	my $inputErrors = 0;
	GetOptions('in=s'	=>	\$filenameIn, 
			   'out=s'	=>	\$filenameOut);
	if (!$filenameIn) { $inputErrors = 1; }
	if (!$filenameOut) { $inputErrors = 1; }
	if ($inputErrors)
	{
		print STDERR <<FINI;
Usage: $0 --in <input xlsx file> --out <output file>
FINI
		die("\tCommand line options incorrect\n");
	}

	# Open input and output files.
	my $mhsStudentsIn = ReadData($filenameIn, attr => 1) or die("Cannot read input file: $!\n");
	my $mhsStudentsOut = FileHandle->new('>' . $filenameOut) or die("Cannot write output file: $!\n");


	# Get the sheet with the staff data, along with some important details about that sheet.
	my $page = $mhsStudentsIn->[1];
	my $pageMaxRow = $page->{maxrow};
	my $pageMaxCol = $page->{maxcol};
	my $attributesIn = $page->{attr};
#	print Dumper($attributesIn);


	# Acquire column labels.
	learnColumnHeaders(Spreadsheet::Read::cellrow($page, 1));

	my ($parentEmailIndex,
	    $secondaryEmailIndex) = (rowIndexByHeader('Parent E-Mail'), 
				     rowIndexByHeader('Secondary E-mail'));

	my %emailAddresses;

	# Loop over rows in sheet
	for my $row (1..$pageMaxRow) # Note: Row 1 is column headers
	{
	    my @rowData = Spreadsheet::Read::cellrow($page, $row);
	    if ($row == 1) # Note: Row 1 is column headers:
	    {
	    }
	    else # Data rows:
	    {
		my ($parentEmail, $secondaryEmail) = @rowData[$parentEmailIndex, $secondaryEmailIndex];
		if ($parentEmail)
		{
		    $emailAddresses{$parentEmail} = 1;
		}
		if ($secondaryEmail)
		{
		    $emailAddresses{$secondaryEmail} = 1;
		}
	    }
	}
	my (@goodAddress, @badAddress);
	for my $address (keys(%emailAddresses))
	{
	    if ($address =~ /^\s*(([^@]*)@(([^\.@]*)\.)+[^\.@]{2,3})\.?\s*$/)
	    {
		push(@goodAddress, $1);
	    }
	    else
	    {
		push(@badAddress, $address);
	    }
	}

	my @uniqueEmailAddresses = sort { compareEmailAddressPairByServer($a, $b); } @goodAddress;

	print $mhsStudentsOut join("\n", @uniqueEmailAddresses), "\n";
	print scalar(@uniqueEmailAddresses), ' addresses written to ', $filenameOut, "\n";

	print 'Bad addresses: ', join(', ', @badAddress), "\n";
}

main();


