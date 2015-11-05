#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;


{
	my $headerColumns = {};

	# Sets process-persistent value in $headerColumns
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

	# Uses process-persistent value in $headerColumns
	sub rowIndexByHeader($)
	{
		my ($header) = @_;
		my $index = $headerColumns->{lc($header)};
		return($index);
	}
}




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


sub extractTeacherGrade()
{
	my $headerRowHandler = sub {
		my @row = @_;
		push(@row, 'Grade');
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


sub provideTransforms()
{
	my $transforms = [];
	push(@$transforms, extractTeacherGrade());
	push(@$transforms, remoteNumericPrefixFromBuildingName());
	return($transforms);
}


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

sub main()
{
	# Collect the set of transformations to perform on each row
	my $transforms = provideTransforms();


	my $staff = ReadData('data/PTAStaff.2015-10-21.xlsx') or die "Cannot read file: $!";

	my $page = $staff->[1];
	my $pageMaxRow = $page->{maxrow};
	my $pageMaxCol = $page->{maxcol};

	learnColumnHeaders(Spreadsheet::Read::cellrow($page, 1));

	# Loop over rows in sheet
	for my $row (1..$pageMaxRow) # Note: Row 1 is column headers
	{
		my @rowData = Spreadsheet::Read::cellrow($page, $row);
		if ($row == 1) # Note: Row 1 is column headers
		{
			@rowData = processHeaderRow($transforms, @rowData);
		}
		else # Data rows
		{
			@rowData = processRow($transforms, @rowData);
		}
		print join(', ', map { defined($_) ? $_ : '***'; } @rowData), "\n";
	}
}

main();


