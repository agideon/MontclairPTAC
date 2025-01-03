#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;
use Spreadsheet::Write;
#use Excel::Writer::XLSX;
use Getopt::Long;


sub main()
{
	my ($filenameIn, $filenameOutPrefix);

	my $inputErrors = 0;
	GetOptions('in=s'	=>	\$filenameIn, 
		   'out=s'	=>	\$filenameOutPrefix);
	if (!$filenameIn) { $inputErrors = 1; }
	if (!$filenameOutPrefix) { $inputErrors = 1; }
	if ($inputErrors)
	{
		print STDERR <<FINI;
Usage: $0 --in <input xlsx file> --out <output xlsx filename prefix>
FINI
		die("\tCommand line options incorrect\n");
	}

#	my $in = ReadData($filenameIn, attr => 1) or die("Cannot read input file: $!\n");
	my $in = Spreadsheet::Read->new($filenameIn, attr => 1)
	    or die("Cannot read input file: $!\n");
	# print STDERR "Input: ", Dumper($in);
	# my $pageIn = $in->[1]; # Get tab/sheet
	my $pageIn = $in->sheet(1); # Get tab/sheet
	# Get characteristics of the tab(le):
	my $pageInMaxRow = $pageIn->{maxrow};
	my $pageInMaxCol = $pageIn->{maxcol};
	my $attributesIn = $pageIn->{attr};

	# my @headerRowIn = Spreadsheet::Read::row($pageIn, 1);
	my @headerRowIn = $pageIn->row(1);
	# print STDERR "Header row: ", Dumper(\@headerRowIn);

	# These don't seem useful, mostly because there's no width information
	# for my $colIndex (1..$pageInMaxCol)
	# {
	# my $attr = $pageIn->attr(1, $colIndex);
	# print STDERR "Attributes for header column ", $colIndex, ": ", Dumper($attr);
	# }


	my $widths = {};
	my $outputSheets = {};
	# Loop over data rows
	for my $rowIndex (2..$pageInMaxRow) # Reminder: Row 1 is column headers
	{
	    # my @rowData = Spreadsheet::Read::cellrow($pageIn, $rowIndex);
	    my @rowData = $pageIn->cellrow($rowIndex);
	    my $school = $rowData[2];
	    $school =~ s/\s/-/g;
	    # print STDERR "School for row ", $rowIndex, " is ", $school, "\n";

	    # Create a new file for every school:
	    if (!defined($outputSheets->{$school}))
	    {
		my $filenameOut = $filenameOutPrefix . '-' . $school . '.xlsx';
		$outputSheets->{$school} =
		    Spreadsheet::Write->new(file => $filenameOut,
					    sheet => substr($school, 0, 30),
		    )
		    or die("Cannot open output file " . $filenameOut . ": " . $!);
		$outputSheets->{$school}->addrow(@headerRowIn);
	    }

	    # Build cell data for output including width for the column.  Some
	    # cells' data will force a column's width to expand.
	    my @rowDataWithWidth;
	    for my $cellIndex (0 .. $pageInMaxCol-1)
	    {
		# Note concatenation of the cell data with a string to force it to be
		# interpreted as a string rather than a number for length().  This also
		# makes it easy to add some "padding".

		# Reasonable initial widths
		$widths->{$school} ||= [];
		$widths->{$school}->[$cellIndex] ||= length($headerRowIn[$cellIndex] . '');

		# Set a new column width if a cell's value exceeds the current width for this column
		if ($widths->{$school}->[$cellIndex] < length($rowData[$cellIndex] . ' '))
		{
		    $widths->{$school}->[$cellIndex] = length($rowData[$cellIndex] . ' ');
		    # if ($cellIndex ==0)
		    # {
		    # print STDERR 'Setting width of column 0 in ', $school, ' to ',
		    # $widths->{$school}->[$cellIndex], "\n";
		    # }
		}
		push(@rowDataWithWidth, {
		    'width' => $widths->{$school}->[$cellIndex],
			'content' => $rowData[$cellIndex],
		     });
	    }

	    $outputSheets->{$school}->addrow(@rowDataWithWidth);


	}
}



main();
