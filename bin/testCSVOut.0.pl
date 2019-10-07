#!/usr/bin/perl -w

use strict;
use Text::CSV;
use Excel::Writer::XLSX;
use Getopt::Long;

sub main1()
{
    my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
    my $out = *STDOUT;
    $csv->say($out, [1, 2, 'Hi, there', 3]);
}

sub main()
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

main();
