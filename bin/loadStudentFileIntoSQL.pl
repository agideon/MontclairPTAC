#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Spreadsheet::Read;
use Excel::Writer::XLSX;
use Getopt::Long;
use DBI qw(:sql_types);


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
sub processRow($@)
{
	my ($rowHeaders, @row) = @_;
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

	my $rval = {};
	my $columnCount = scalar(@row);
#	print "Size of row: ", $columnCount, "\n";
#	print "Headers: ", Dumper($rowHeaders), "\n";
	if (scalar(@$rowHeaders) < $columnCount) { $columnCount = scalar(@$rowHeaders); }

#	print "Copy ", $columnCount, " elements.\n";

	for (my $column = 0; $column < $columnCount; $column++)
	{
	    $rval->{$rowHeaders->[$column]} = $row[$column];
	}

	return($rval);
}

sub processSimpleResults($$)
{
    my ($statement, $resultWithID) = @_;
    my $returnedID = undef;

    my $query = $statement->{Statement}; # Just used for error reporting
    $statement->execute() or die("Unable to execute query " . $query . ": " . $statement->err . ": " . $statement->errstr);

    my $resultSet = 0;
    do
    {
	$resultSet++;
	my $rowCount = $statement->rows;
	my $columnCount = $statement->{'NUM_OF_FIELDS'} or 0;

	# It seems that an insert returns a row count of 1 (or perhaps more than that for multivalued inserts)
	# but a column count of 0 or undef.  So both should be checked (though perhaps only columnCount
	# is strictly required?).
	if (($rowCount > 0) && ($columnCount))
	{
#	    print "Rows from result set ", $resultSet, "...\n";
	    while (my @row = $statement->fetchrow_array())
	    {
#		print "Row from result set ", $resultSet, ": ", join(', ', @row), "\n";
		if ($resultSet == $resultWithID) { $returnedID = $row[0];}
	    }
	}
	else
	{
#	    print "Skipping retrieval for result set ", $resultSet, ' with row count:', $rowCount, ' and column count: ', $columnCount, "\n";
	}
    } while ($statement->more_results);
    return($returnedID);
}




use constant studentFields => ('ID', 'Date Of Birth', 'Last Name', 'First Name', 'Grade');
sub getStudentID($$$$$)
{
    my ($dbh, $student, $schoolID, $homeroomID, $familyCodeID) = @_;

    # Note Convertion of date format using str_to_date - assumes a given format in the input
    my $query = <<FINI;
    insert ignore into student(district_student_id, first_name, last_name, date_of_birth, grade, school_id, homeroom_id, family_code_id)
	select ?, ?, ?, str_to_date(?,'%m/%d/%Y'), ?, ?, ?, ?;
    select student_id from student where district_student_id = ?
FINI

    my $statement = $dbh->prepare($query) or die("Unable to prepare query " . $query . ": " . $dbh->err . ": " . $dbh->errstr);

    $statement->bind_param(1, $student->{'ID'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption
    $statement->bind_param(2, $student->{'First Name'});
    $statement->bind_param(3, $student->{'Last Name'});
    $statement->bind_param(4, $student->{'Date Of Birth'});
    $statement->bind_param(5, $student->{'Grade'});
    $statement->bind_param(6, $schoolID);
    $statement->bind_param(7, $homeroomID);
    $statement->bind_param(8, $familyCodeID);

    $statement->bind_param(9, $student->{'ID'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption

    return(processSimpleResults($statement, 2));
}

# Note: This assumes that every row with a given (school,homeroom) will have the same teacher.
sub getHomeroomID($$$)
{
    my ($dbh, $input, $schoolID) = @_;
    my $query = <<FINI;
    insert ignore into homeroom(room, teacher, school_id) values (?, ?, ?);
    select homeroom_id from homeroom where room = ? AND school_id = ?;
FINI
    my $statement = $dbh->prepare($query) or die("Unable to prepare query " . $query . ": " . $dbh->err . ": " . $dbh->errstr);

    # Some student rows from the district leave homeroom and teacher blank
    my ($homeroom, $teacher) = ($input->{'ROOM'} || '', $input->{'Homeroom Teacher'} || '');


    $statement->bind_param(1, $homeroom, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption
    $statement->bind_param(2, $teacher);
    $statement->bind_param(3, $schoolID);

    $statement->bind_param(4, $homeroom, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption
    $statement->bind_param(5, $schoolID);

    return(processSimpleResults($statement, 2));
}



sub getFamilyCodeID($$)
{
    my ($dbh, $familyCode) = @_;

    my $query = <<FINI;
	insert ignore into family_code(code) values (?);

	select family_code_id from family_code where code = ?;
FINI

    my $statement = $dbh->prepare($query) or die("Unable to prepare query " . $query . ": " . $dbh->err . ": " . $dbh->errstr);

    $statement->bind_param(1, $familyCode->{'Family Code'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption
    $statement->bind_param(2, $familyCode->{'Family Code'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption

    return(processSimpleResults($statement, 2));
}



use constant schoolFields => ('School', 'School Name');
sub getSchoolID($$)
{
    my ($dbh, $school) = @_;
    # Could also use INSERT INTO ... ON DUPLICATE ...
    my $query = <<FINI;
	insert ignore into school(district_school_id, canonical_school_name) values (?, ?);

	insert ignore into school_name(school_id, school_name) select school_id, ? from school where district_school_id = ?;

	select school_id from school where district_school_id = ?;
FINI

    my $statement = $dbh->prepare($query) or die("Unable to prepare query " . $query . ": " . $dbh->err . ": " . $dbh->errstr);

    $statement->bind_param(1, $school->{'School'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption
    $statement->bind_param(2, $school->{'School Name'});

    $statement->bind_param(3, $school->{'School Name'});
    $statement->bind_param(4, $school->{'School'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption

    $statement->bind_param(5, $school->{'School'}, { TYPE => SQL_VARCHAR }); # Force non-numeric type assumption

    return(processSimpleResults($statement, 3));
}



sub main()
{
	my ($filenameIn, $dbUsername, $dbPassword, $dbName, $dbHostname, $dbPort);

	my $inputErrors = 0;
	GetOptions('in=s'		=>	\$filenameIn, 
		   'username|u=s'	=>	\$dbUsername,
		   'password|p=s'	=>	\$dbPassword,
		   'db|dbname=s'	=>	\$dbName,
		   'dhhost|host=s'	=>	\$dbHostname,
		   'dbport|port=s'	=>	\$dbPort,
	    );
	if (!$filenameIn) { $inputErrors = 1; }
	if (!$dbUsername) { $inputErrors = 1; }
	if (!$dbPassword) { $inputErrors = 1; }
	if (!$dbName) { $inputErrors = 1; }
	if (!$dbHostname) { $dbHostname = '127.0.0.1'; }
	if (!$dbPort) { $dbPort = 3306; }


	if ($inputErrors)
	{
		print STDERR <<FINI;
Usage: $0 --in <input xlsx file> --username <dbusername> --password <dbpassword> --dbname <dbname> --dbhost <db hostname> --dbport <db port #>
FINI
		die("\tCommand line options incorrect\n");
	}

	# Trying mysql_multi_statements.
	# Would mysql_server_prepare improve performance?
	# Also consider processing in "column first" order.  That is: all school data, then all student data, then all contact data.
	# This permits multivalued inserts if one assumes that this is loading into a clean/empty database.
	my $dsn = "DBI:mysql:database=$dbName;host=$dbHostname;port=$dbPort;mysql_multi_statements=1";
	my $dbh = DBI->connect($dsn, $dbUsername, $dbPassword,
			       {
				   AutoCommit => 0,
			       },
	    ) or die("Unable to connect to db: " . $DBI::errstr);
	

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
	my @rowHeaders;
	for my $row (1..$pageMaxRow) # Note: Row 1 is column headers
	{
		my @rowData = Spreadsheet::Read::cellrow($page, $row);
		if ($row == 1) # Note: Row 1 is column headers:
		{
			@rowHeaders = processHeaderRow(@rowData);
#			print "Headers read: ", Dumper(\@rowHeaders), "\n";
		}
		else # Data rows:
		{
#			print "Headers: ", Dumper(\@rowHeaders), "\n";
			my $rowData = processRow(\@rowHeaders, @rowData);
#			print join(', ', map { defined($_) ? $_ : '***'; } @rowData), "\n";
			print Dumper($rowData);
			if (1)
			{
			    eval
			    {
				my $schoolID = getSchoolID($dbh, $rowData);
				print "School ID: ", $schoolID, "\n";
				my $familyCodeID = getFamilyCodeID($dbh, $rowData);
				print "Family Code ID: ", $familyCodeID, "\n";
				my $homeroomID = getHomeroomID($dbh, $rowData, $schoolID);
				print "Homeroom ID: ", $homeroomID, "\n";
				my $studentID = getStudentID($dbh, $rowData, $schoolID, $homeroomID, $familyCodeID);
				print "Student ID: ", $studentID, "\n";
			    };
			    if ($@)
			    {
				print "Rollback transaction\n";
				$dbh->rollback;
			    }
			    else
			    {
				print "Commit transaction\n";
				$dbh->commit;
			    }
			}
		}

	}

}

main();


