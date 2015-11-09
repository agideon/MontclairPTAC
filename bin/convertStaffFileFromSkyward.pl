#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;
use Excel::Writer::XLSX;
use Getopt::Long;

######################################################################
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



######################################################################
# This transformation removes the numeric prefix from the "location"
# column, making the location merely a building name.
#
sub remoteNumericPrefixFromBuildingName()
{
	return(
		{
			'dataRow'		=> 
				sub {
					my @row = @_;
					my $index = rowIndexByHeader('LOCATION');
					if ($row[$index] && ($row[$index] =~ /^[\s\d]+(.*)$/))
					{
						$row[$index] = $1;
					}
					return(@row);
			}
		}
		);
		
}


######################################################################
# This transformation adds a grade column, extracting the grade - where
# it is present - from the "title" column.
#
sub extractTeacherGrade()
{
	my $headerRowHandler = sub {
		my @row = @_;
		push(@row, 'GRADE');
		return(@row);
	};

	my $dataRowHandler = sub {
		my @row = @_;
		my $grade;
		if ($row[3] =~ /(\d+)/)
		{
			$grade = $1;
		}
		push(@row, $grade);
		return(@row);
	};

	return(
		{
			'headerRow'		=> $headerRowHandler,
			'dataRow'		=> $dataRowHandler,
		});
}


######################################################################
# This is invoked at startup to generate the list of transformations
# to be applied.  Ideally - satisfying open/closed - this would be
# accompished via subclassing or a Factory or some other safe extension 
# mechanism.  
#
# I'm avoiding that to make this easy to transport.  Once this is in a 
# stable location, though, this model should be revisited to permit 
# easy addition of new transforms w/o having to touch existing code.
#
sub provideTransforms()
{
	my $transforms = [];
	push(@$transforms, extractTeacherGrade());
	push(@$transforms, remoteNumericPrefixFromBuildingName());
	return($transforms);
}


######################################################################
# This is invoked to process the first/header row.  All transformatins
# for these rows are applied.
#
sub processHeaderRow($@)
{
	my ($transforms, @row) = @_;
	if (defined($transforms))
	{
		foreach my $transform (@$transforms)
		{
			if ($transform->{'headerRow'})
			{
				@row = $transform->{'headerRow'}->(@row);
			}
		}
	}
	return(@row);
}


######################################################################
# This is invoked to process each data row.  All transformations
# for these rows are applied.
#
sub processRow($@)
{
	my ($transforms, @row) = @_;
	if (defined($transforms))
	{
		foreach my $transform (@$transforms)
		{
			if ($transform->{'dataRow'})
			{
				@row = $transform->{'dataRow'}->(@row);
			}
		}
	}
	return(@row);
}

######################################################################
# Provide methods to accumulate and then acquire column widths.
#
{
	my @columnWidths;
	sub acquireColumnWidths(@)
	{
		my @rowData = @_;
		my $index = 0;
		foreach my $cell (@rowData)
		{
			if ($cell)
			{
				if (!$columnWidths[$index] || ($columnWidths[$index] < length($cell)))
				{
					$columnWidths[$index] = length($cell);
				}
			}
			$index++;
		}
	}
	sub theColumnWidths()
	{
		return(@columnWidths);
	}
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
Usage: $0 --in <input xlsx file> --out <output xlsx file>
FINI
		die("\tCommand line options incorrect\n");
	}

	# Collect the set of transformations to perform on each row
	my $transforms = provideTransforms();


	# Open input and output files.
	my $staffIn = ReadData($filenameIn, attr => 1) or die("Cannot read input file: $!\n");
	my $staffOut = Excel::Writer::XLSX->new($filenameOut) or die("Cannot write output file: $!\n");


	# Set up the output sheet.
	my $pageOut = $staffOut->add_worksheet('Staff Transformed') or die "Unable to create new output worksheet: $!";
	my $formatOut  = $staffOut->add_format();


	# Get the sheet with the staff data, along with some important details about that sheet.
	my $page = $staffIn->[1];
	my $pageMaxRow = $page->{maxrow};
	my $pageMaxCol = $page->{maxcol};
	my $attributesIn = $page->{attr};
#	print Dumper($attributesIn);


	# Acquire column labels.
	learnColumnHeaders(Spreadsheet::Read::cellrow($page, 1));

	# Loop over rows in sheet
	for my $row (1..$pageMaxRow) # Note: Row 1 is column headers
	{
		my @rowData = Spreadsheet::Read::cellrow($page, $row);
		if ($row == 1) # Note: Row 1 is column headers:
		{
			@rowData = processHeaderRow($transforms, @rowData);
		}
		else # Data rows:
		{
			@rowData = processRow($transforms, @rowData);
		}
		acquireColumnWidths(@rowData);
#		print join(', ', map { defined($_) ? $_ : '***'; } @rowData), "\n";

		$pageOut->write_row($row - 1, 0, \@rowData);
	}

	# Set the width of each column in the output to fit the widest of that
	# column's values.
	{
		my $index = 0;
		foreach my $cellWidth (theColumnWidths())
		{
			$pageOut->set_column($index, $index, $cellWidth);
			$index++;
		}
	}


}

main();


