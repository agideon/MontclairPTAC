#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;



sub extractTeacherGrade($)
{
	my @row = @_;
	my $grade;
	if ($row[3] =~ /(\d+)/)
	{
		$grade = $1;
	}
	push(@row, $grade);
	return(@row);
}


sub processRow($@)
{
	my ($transforms, @row) = @_;
	if (defined($transforms))
	{
		foreach my $transform (@$transforms)
		{
			@row = $transform->(@row);
		}
	}
	return(@row);
}

sub main()
{
	# Collect the set of transformations to perform on each row
	my $transforms = [];
	push(@$transforms, \&extractTeacherGrade);

	my $staff = ReadData('data/PTAStaff.2015-10-21.xlsx') or die "Cannot read file: $!";
	my $page = $staff->[1];
	my $pageMaxRow = $page->{maxrow};
	my $pageMaxCol = $page->{maxcol};

	# Loop over rows in sheet
	for my $row (2..$pageMaxRow) # Note: Row 1 is column headers
	{
		my @rowData = Spreadsheet::Read::cellrow($page, $row);
		@rowData = processRow($transforms, @rowData);
		print join(', ', map { defined($_) ? $_ : '***'; } @rowData), "\n";
	}
}

main();


