#!/bin/sh

STANDARD_ARGS='--username montclairpta0 --password montclair123 --dbname montclairpta0 --email'

bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 050 --out /tmp/MHS.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 060 --out /tmp/Bullock.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 100 --out /tmp/Bradford.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 110 --out /tmp/Edgemont.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 116 --out /tmp/Glenfield.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 123 --out /tmp/Hillside.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 127 --out /tmp/Buzz.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 130 --out /tmp/Nishuane.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 140 --out /tmp/Northeast.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 165 --out /tmp/Renaissance.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school 170 --out /tmp/Watchung.xlsx
bin/outputContactsAsXLXS.pl ${STANDARD_ARGS} --school DLC --out /tmp/DLC.xlsx
