#!/usr/bin/perl -w

use strict;
use Text::CSV;
use Excel::Writer::XLSX;
use Getopt::Long;
use DBI qw(:sql_types);


sub getContacts
{
    my ($dbName, $dbHostname, $dbPort, $dbUsername, $dbPassword, 
	$school, $useForDirectory, $useForEmailBcast, 
	$writeHeaderRow, $writeDataRow, $finish) = @_;
    my @rval;
    my $dsn = "DBI:mysql:database=$dbName;host=$dbHostname;port=$dbPort;mysql_multi_statements=1";
    my $dbh = DBI->connect($dsn, $dbUsername, $dbPassword,
			   {
			       AutoCommit => 0,
			   },
	) or die("Unable to connect to db: " . $DBI::errstr);
    
    my $query = <<FINI;

    select
		distinct

		if(p.number is not null, p.number, "-") as "Phone Num",
		if(scp.cellular>0 and scp.cellular is not null, "Cell", "-") as "Cell?",
		if(scp.home>0 and scp.cellular is not null, "Home", "-") as "Home?",
		if(scp.prime>0 and scp.cellular is not null, "Main-number", "-") as "Main Number?",

		if(e.address is not null,e.address,"-") as "Email",

		sc.first_name as "Guardian first name",
		sc.last_name as "Guardian last name",s.first_name "Student first name",
		s.last_name "Student last name",s.grade,

		if(sch.canonical_school_name is not null, sch.canonical_school_name, "-") as "School",

		if(h.room is not null, h.room, "-") as "Room",
		if(h.teacher is not null, h.teacher, "-") as "Teacher"


	from 
		student_contact sc join student_student_contact ssc on sc.student_contact_id = ssc.student_contact_id
		join student s on ssc.student_id = s.student_id

		left outer join student_contact_phone scp on sc.student_contact_id = scp.student_contact_id
		left outer join phone p on scp.phone_id = p.phone_id

		left outer join student_contact_email sce on sc.student_contact_id = sce.student_contact_id
		left outer join email e on sce.email_id = e.email_id

		left outer join homeroom h on s.homeroom_id = h.homeroom_id

		left outer join school sch on s.school_id = sch.school_id


	where
		sch.district_school_id = ?

		/* Avoid contact-free rows - only accept rows with either a phone or email */
		and ((p.number is not null) or (e.address is not null))



    /* Directory use */
		and ((? = 1) OR (sc.use_in_directory = 1))

    /* Email use */

		and ((? = 1) OR
			(
			  (sc.use_in_broadcast = 1) 
			and (e.address is not null)
			and (trim(e.address) != "")
			))
	order by sc.last_name, sc.first_name


FINI

    my $statement = $dbh->prepare($query) or die("Unable to prepare query " . $query . ": " . $dbh->err . ": " . $dbh->errstr);
    {
	my $pindex = 0;
	$statement->bind_param(++$pindex, $school);
	$statement->bind_param(++$pindex, !$useForDirectory); # Not 1 if listing those in directory
	$statement->bind_param(++$pindex, !$useForEmailBcast); # Not 1 if listing those in email
    }
    {
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
		# Column Headers
		my $columnNames = $statement->{NAME};
		$writeHeaderRow->($columnNames);

		# Data Rows
		while (my @row = $statement->fetchrow_array())
		{
		    $writeDataRow->(\@row);
		}
	    }
	    else
	    {
		print STDERR "Skipping retrieval for result set ", $resultSet, ' with row count:', $rowCount, ' and column count: ', $columnCount, "\n";
	    }
	} while ($statement->more_results);
    }


    $dbh->commit;
    $finish->();
}

sub setUpXLSXOutput
{
    my ($outputFilename) = @_;

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

    my $headerFormat = $sheetout->add_format('align' => 'center', 'bold' => 1);
    my $dataFormat = $sheetout->add_format('align' => 'left', 'bold' => 0);

    my $sheetRowIndex = 0;
    my $writeHeaderRow = sub
    {
	my ($columnNames) = @_;
	$pageout->write_row($sheetRowIndex++, 0, $columnNames, $headerFormat);
    };
    my $writeDataRow = sub
    {
	my ($row) = @_;
	$pageout->write_row($sheetRowIndex++, 0, 
			    $row, $dataFormat);
    };

    my $finish = sub
    {
	$pageout->set_column(0, 0, 15);
	$pageout->set_column(1, 2, 6);
	$pageout->set_column(3, 3, 13);
	$pageout->set_column(4, 8, 25);
	$pageout->set_column(9, 9, 5);
	$pageout->set_column(10, 10, 10);
	$pageout->set_column(11, 11, 5);
	$pageout->set_column(12, 12, 18);
	$pageout->freeze_panes(1, 0); # Freeze (or float) first row
	$sheetout;
    };

    return($writeHeaderRow, $writeDataRow, $finish);


}


sub main()
{
    my ($dbUsername, $dbPassword, $dbName, $dbHostname, $dbPort, $school, $useForEmailBcast, $useForDirectory);
    my ($outputFilename);
    my @inputErrors;
    GetOptions('out=s'			=>	\$outputFilename,
	       'username|u=s'	=>	\$dbUsername,
	       'password|p=s'	=>	\$dbPassword,
	       'db|dbname=s'	=>	\$dbName,
	       'dhhost|host=s'	=>	\$dbHostname,
	       'dbport|port=s'	=>	\$dbPort,
	       'school=s'	=>	\$school,
	       'email'		=>	\$useForEmailBcast,
	       'directory'	=>	\$useForDirectory,
	);

	if (!$dbUsername) { push(@inputErrors, "DB Username Required"); }
	if (!$dbPassword) { push(@inputErrors, "DB Password Required"); }
	if (!$dbName) { push(@inputErrors, "DB Name Required"); }
	if (!$dbHostname) { $dbHostname = '127.0.0.1'; }
	if (!$dbPort) { $dbPort = 3306; }
	if (!defined($school)) { push(@inputErrors, "A school must be specified"); }
    	if (defined($useForEmailBcast) && defined($useForDirectory))
	{
	    push(@inputErrors, "Only one of --email and --directory may be specified")
	}
	elsif (!defined($useForEmailBcast) && !defined($useForDirectory))
	{
	    push(@inputErrors, "One of --email and --directory must be specified")
	}


	if (scalar(@inputErrors) > 0)
	{
		print STDERR <<FINI;
Usage: $0 --out <output xlsx file> --username <dbusername> --password <dbpassword> --dbname <dbname> --dbhost <db hostname> --dbport <db port #> --school <school-id> [--directory] [--email]
FINI
		print "\t", join("\n\t", @inputErrors), "\n";
		die("\tCommand line options incorrect\n");
	}




    my ($writeHeaderRow, $writeDataRow, $finish) = setUpXLSXOutput($outputFilename);
    getContacts($dbName, $dbHostname, $dbPort, $dbUsername, $dbPassword, 
		$school, $useForDirectory, $useForEmailBcast, 
		$writeHeaderRow, $writeDataRow, $finish);



}

main();
