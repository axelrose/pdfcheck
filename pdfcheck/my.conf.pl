# pdfcheck.conf.pl
#
# configuration file for pdfcheck.p



# never delete this curly brace, file must have valid Perl syntax (check with "perl -c pdfceck.conf.pl")
{
reportstylepdf => 'PDFLAYER,ONHIT',
userdirout => '../../__USER__/__DIR__',
suffixremove => [ '.indd', '.qxd' ],
}

