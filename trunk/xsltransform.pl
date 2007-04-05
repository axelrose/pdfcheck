#!/usr/bin/perl

use FindBin;

my $Id = '$Id: xsltransform.pl 180 2006-12-07 14:49:00Z rose $';

my $file = shift || die "no input, no output";

my $xsl = $FindBin::Bin . '/xslt/pdfinsp.xsl';
die "not readable: '$xsl'" unless -r $xsl;

my $outfile = $file . '.1';

# xsltproc doesn't like % in filenames
$outfile =~ s/%/_/g;

my @cmd = ( "xsltproc", "-o", $outfile, $xsl, $file );
system @cmd and die "$0: system error ", $? >> 8, " running command:\n@cmd";

# DEBUG
# save a copy of XML and HTML files
# system( "cp", $file, "/tmp/" ) and warn $!;
# system( "cp", $outfile, "/tmp/" ) and warn $!;

system( "mv", $outfile, $file ) and die $!;

exit 0;


