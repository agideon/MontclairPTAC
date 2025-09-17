#FROM perl:5.42
FROM almalinux:10 AS build0

RUN dnf -y upgrade
RUN dnf -y install perl-CPAN nc traceroute perl-DBD-MySQL expat-devel mysql8.4

FROM build0 AS build1

#RUN cpan -T -i Spreadsheet::Read
RUN cpan -T -i Spreadsheet::Read Text::CSV_XS Text::CSV Text::CSV_PP HTML::TreeBuilder Tie::IxHash HTML::Entities::Numbered XML::Twig XML::Parser Spreadsheet::ParseXLSX Spreadsheet::XLSX Excel::Writer::XLSX


FROM build1

WORKDIR /app

# Force the shell to stop on a STOP
STOPSIGNAL SIGKILL

CMD ["/bin/sh"]
