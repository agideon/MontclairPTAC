#!/usr/bin/perl -w

use strict;
use Text::CSV;
use Excel::Writer::XLSX;
use Getopt::Long;
use DBI qw(:sql_types);



sub main1()
{
    my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
    my $out = *STDOUT;
    $csv->say($out, [1, 2, 'Hi, there', 3]);
}

sub main2()
{
    

    my ($outputFilename);
    GetOptions('out=s'			=>	\$outputFilename,
	);

    my $sheetout;
    if (defined($outputFilename))
    {
	$sheetout = Excel::Writer::XLSX->new($outputFilename) or
	    die "Unable to open XLSX file $outputFilename for output: $!";
    }
    else
    {
	binmode(STDOUT);
	$sheetout = Excel::Writer::XLSX->new( \*STDOUT );
    }

    my $pageout = $sheetout->add_worksheet('First Tab') or die "Unable to create sheet: $!";
    $pageout->write_row(0, 0, [1, 2, 'Hi, there', 3]);
}

sub main()
{
    my ($dbUsername, $dbPassword, $dbName, $dbHostname, $dbPort);
    my ($outputFilename);
    my $inputErrors = 0;
    GetOptions('out=s'			=>	\$outputFilename,
	       'username|u=s'	=>	\$dbUsername,
	       'password|p=s'	=>	\$dbPassword,
	       'db|dbname=s'	=>	\$dbName,
	       'dhhost|host=s'	=>	\$dbHostname,
	       'dbport|port=s'	=>	\$dbPort,
	       
	);

	if (!$dbUsername) { $inputErrors = 1; }
	if (!$dbPassword) { $inputErrors = 1; }
	if (!$dbName) { $inputErrors = 1; }
	if (!$dbHostname) { $dbHostname = '127.0.0.1'; }
	if (!$dbPort) { $dbPort = 3306; }


	if ($inputErrors)
	{
		print STDERR <<FINI;
Usage: $0 --out <output xlsx file> --username <dbusername> --password <dbpassword> --dbname <dbname> --dbhost <db hostname> --dbport <db port #>
FINI
		die("\tCommand line options incorrect\n");
	}


    my $sheetout;
    if (defined($outputFilename))
    {
	$sheetout = Excel::Writer::XLSX->new($outputFilename) or
	    die "Unable to open XLSX file $outputFilename for output: $!";
    }
    else
    {
	binmode(STDOUT);
	$sheetout = Excel::Writer::XLSX->new( \*STDOUT );
    }

    my $pageout = $sheetout->add_worksheet('First Tab') or die "Unable to create sheet: $!";

    my $dsn = "DBI:mysql:database=$dbName;host=$dbHostname;port=$dbPort;mysql_multi_statements=1";
    my $dbh = DBI->connect($dsn, $dbUsername, $dbPassword,
			   {
			       AutoCommit => 0,
			   },
	) or die("Unable to connect to db: " . $DBI::errstr);
    
    my $query = <<FINI;

    select distinct e.address "Email", sc.first_name as "Guardian first name",sc.last_name as "Guardian last name",s.first_name "Student first name",s.last_name "Student last name",s.grade from student_contact sc join student_student_contact ssc on sc.student_contact_id = ssc.student_contact_id join student s on ssc.student_id = s.student_id join student_contact_email sce on sce.student_contact_id = sc.student_contact_id join email e on e.email_id = sce.email_id where s.school_id = ? and (sc.use_in_directory = 0 OR sc.use_in_directory is null) and (sc.use_in_broadcast = 1) order by sc.last_name, sc.first_name;

FINI

    my $statement = $dbh->prepare($query) or die("Unable to prepare query " . $query . ": " . $dbh->err . ": " . $dbh->errstr);
    {
	my $pindex = 0;
	$statement->bind_param(++$pindex, 2220);
    }
    {
	my $query = $statement->{Statement}; # Just used for error reporting
	$statement->execute() or die("Unable to execute query " . $query . ": " . $statement->err . ": " . $statement->errstr);
	
	my $sheetRowIndex = 0;
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
		print STDERR "Rows from result set ", $resultSet, "...\n";

		# Column Headers
		my $columnNames = $statement->{NAME};
		$pageout->write_row($sheetRowIndex++, 0, $columnNames);

		# Data Rows
		while (my @row = $statement->fetchrow_array())
		{
		    $pageout->write_row($sheetRowIndex++, 0, 
					\@row);
		}
	    }
	    else
	    {
		print STDERR "Skipping retrieval for result set ", $resultSet, ' with row count:', $rowCount, ' and column count: ', $columnCount, "\n";
	    }
	} while ($statement->more_results);
    }

    $dbh->commit;
}

main();