#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;
use Excel::Writer::XLSX;
use Getopt::Long;

######################################################################
# Provide a mechanism whereby transformations may register themselves, 
# as well as a mechanism for acquiring the list of transformations.
#
#
{
	my $transformations = [];

	sub registerTransformation($)
	{
		push(@$transformations, $_[0]);
	}

	sub getTransformations()
	{
		return($transformations);
	}
}


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



######################################################################
# This transformation removes the numeric prefix from the "location"
# column, making the location merely a building name.
#
{
    my $schoolNameTranslations =
    {
	'Montclair High School' => 'MHS',
	'HIGH SCHOOL' => 'MHS',
	'MT. HEBRON' => 'MTHEBRON',
    };

	registerTransformation(
		{
			'dataRow'		=> 
				sub {
					my @row = @_;
					my $index = rowIndexByHeader('LOCATION') || rowIndexByHeader('School Name');
					if ($row[$index] && ($row[$index] =~ /^[\s\d]+(.*)$/))
					{
						$row[$index] = $1;
					}
					# Note: Forcing to upper case
					$row[$index] = uc($schoolNameTranslations->{$row[$index]} || $row[$index]);
					return(@row);
			}
		}
		);
		
}


######################################################################
# This transformation adds a grade column, extracting the grade - where
# it is present - from the "title" column.
#
{
	my $headerRowHandler = sub {
		my @row = @_;
		push(@row, 'GRADE');
		return(@row);
	};

	my $dataRowHandler = sub {
		my @row = @_;
		my $grade;
		if ($row[3] =~ /\b([k\d]+)/i)
		{
			$grade = uc($1);
		}
		push(@row, $grade);
		return(@row);
	};

	registerTransformation(
		{
			'headerRow'		=> $headerRowHandler,
			'dataRow'		=> $dataRowHandler,
		});
}


######################################################################
# This transformation adds a "full name" column, extracting the first
# and last names from separate fields,
#
{
	my $headerRowHandler = sub {
		my @row = @_;
		push(@row, 'FULL NAME');
		return(@row);
	};

	my $dataRowHandler = sub {
		my @row = @_;
		my $name = join(' ', @row[rowIndexByHeader('First Name'), 
					  rowIndexByHeader('Last Name')]);
		push(@row, $name);
		return(@row);
	};

	registerTransformation(
		{
			'headerRow'		=> $headerRowHandler,
			'dataRow'		=> $dataRowHandler,
		});
}




######################################################################
# This transformation adds a house column, currently blank.
#
{
	my $headerRowHandler = sub {
		my @row = @_;
		push(@row, 'HOUSE');
		return(@row);
	};

	my $dataRowHandler = sub {
		my @row = @_;
		push(@row, '');
		return(@row);
	};

	registerTransformation(
		{
			'headerRow'		=> $headerRowHandler,
			'dataRow'		=> $dataRowHandler,
		});
}

######################################################################
# This transformation adds a room column.
#
{
	my $headerRowHandler = sub {
		my @row = @_;
		push(@row, 'ROOM');
		return(@row);
	};

	my $dataRowHandler = sub {
		my @row = @_;
		push(@row, 
		     @row[rowIndexByHeader('Homeroom')]);
		return(@row);
	};

	registerTransformation(
		{
			'headerRow'		=> $headerRowHandler,
			'dataRow'		=> $dataRowHandler,
		});
}


######################################################################
# This is invoked to process the first/header row.  All transformatins
# for these rows are applied.
#
sub processHeaderRow(@)
{
	my (@row) = @_;
	my $transforms = getTransformations();
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
sub processRow(@)
{
	my (@row) = @_;
	my $transforms = getTransformations();
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

sub main()
{
	my ($filenameIn);

	my $inputErrors = 0;
	GetOptions('in=s'	=>	\$filenameIn, 
	    );
	if (!$filenameIn) { $inputErrors = 1; }
	if ($inputErrors)
	{
		print STDERR <<FINI;
Usage: $0 --in <input xlsx file> 
FINI
		die("\tCommand line options incorrect\n");
	}

	# Open input and output files.
	my $staffIn = ReadData($filenameIn, attr => 1) or die("Cannot read input file: $!\n");





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
			@rowData = processHeaderRow(@rowData);
		}
		else # Data rows:
		{
			@rowData = processRow(@rowData);
		}

		print join(', ', map { defined($_) ? $_ : '***'; } @rowData), "\n";

	}

}

main();

