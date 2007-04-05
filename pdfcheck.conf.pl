# pdfcheck.conf.pl
#
# configuration file for pdfcheck.pl


# never delete this curly brace, file must have valid Perl syntax (check with "perl -c pdfcheck.conf.pl")
{
# your Helios installation is in:
# keep empty to autodetect
# heliosdir => '/usr/local/helios',

# all work files go there, don't share this directory with Helios!
# empty value defaults to directory /tmp (subdirectories named 'pdfwork.<pid>')
# tmpdir => '/choose/your/own/tmpdir/pdfwork',

# choose binary for pdfInspektor
# just keep empty to use default
# standard with Helios installation is in:
# pdfinsp => '/usr/local/helios/callas/pdfInspektor3',
# with a fresh callas version:
# pdfinsp => '/usr/local/pdfInspektor3_CLI/pdfInspektor3',
# with remote execution:
# pdfinsp => 'ssh fserver.sjintra.net \'/usr/local/pdfInspektor3_CLI/pdfInspektor3',

# don't show progress info, always overwrite
pdfinspopt => '--ignorehash --noprogress --o',

# pdfInspektor report language
# Danish: da, German: de, English: en, French: fr, Italian: it, Netherlands: nl, Portuguese: pt, Svedish: sv
reportlang => 'de',

# start/end line of text reports in Helios log files
reporttxt0 => "------------- Start pdfInspector output -------------\n",
reporttxt1 => "-------------- End pdfInspector output --------------\n",

# PDF report
# choose from PDFCOMMENTS PDFMASK PDFLAYER
# choose from ALWAYS ONHIT ONERROR ONWARNING ONINFO ONNONE
reportstylepdf => 'PDFCOMMENTS,ONHIT',
# or leave empty to skip PDF report
# reportstylepdf => '',

# Text report
# examples:
# reportstyletxt => 'COMPACT,SHORT,UTF8,ALWAYS',
# see pdfInspektor manual or output from "pdfInspektor3 -h" for further report options
# or leave empty to skip text report
# reportstyletxt => '',
reportstyletxt => 'XML,ALWAYS,SHORT,PAGEINFO,DOCRSRC',

# shell
# will be used to launch txtpatchscript and postprocess scripts
# leave empty to use the same Perl interpreter as "pdfcheck.pl" uses itself
# shell => '/bin/bash',

# Text report might be patched with this script
# txtpatchscript => 'patch-txtreport.pl',
# or transformed to html
txtpatchscript => 'xsltransform.pl',
# or left untouched
# txtpatchscript => '',
# note:
# use a relative path to start path from directory where the executed "pdfcheck.pl" is
# use an absolute path otherwise
# if the script is not executable the Perl interpreter will be used to launch the script
# unless you have a different shell configured, see configuration key 'shell'

# output directory for 0 errors, 0 warnings
# don't leave empty!
ok => 'OUT',

# output directory for 0 errors, 1 or more warnings
# you may use the same directory as for "error"
# don't leave empty!
warning => 'SCHAU',

# output directory for 1 or more errors
# you may use the same directory as for "warning"
# don't leave empty!
error => 'ERROR',

# copy original input files after processing to this directory
# may be left empty or identical to ok/warning/error directory
copy => 'ORIG',

# if pdfinspektor run results in errors
# 0: copy all input files to copy dir
# 1: don't copy
# default: 0
# has no effect is copy dir is not defined
# dontcopyerrors => 1,

# don't move input pdf to error dir when pdfInspektor finds errors
# 0: move input file to error dir
# 1: discard (remove) input file
# default: 0
# dangerous! if you activate this feature input files may be lost unless "copy" is enabled
# otherwise handy to prevent users from working with erroneous files
# discarderrinput => 1

# 1: input directory is a subdirectory (DIR:IN, DIR:ERROR, DIR:OUT)
# 0: subdir is on top of output directories (IN, IN:ERROR, IN:OUT)
insubdir => 1,

# effective only for notification script
# 1: always exit with success
# 0: FATAL errors or errors in PDF checks will
#    move the input job (PostScript) to the error queue and
#    notify the client user with HELIOS standard methods
exit0 => 0,

# after finishing "pdfcheck.pl" a postprocessing script might be called
# postprocess => 'pdfcheck.postprocess.pl',
# note:
# use a relative path to start path from directory where the executed "pdfcheck.pl" is
# use an absolute path otherwise
# if the script is not executable the Perl interpreter will be used to launch the script
# unless you have a different shell configured, see configuration key 'shell'

# userdirhf
# will assume userdir output for hotfolders
# name of input directory is taken as username which is replaced with placeholder __USER__
# in configuration for 'userdirout' below
# default: 0
# userdirhf => 1,

# base for out/err/warn/copy dir
# default is to have those directories within the user dir
# userdirout => '',
# __DIR__ must be present and is replaced by ok/warning/error/copy as configured above
# __USER__ will be replaced by content of $ENV{HELIOS_JOBFOR}
# relative path starting from dir where the input pdf file arrives
# userdirout => '../../__DIR__/__USER__',

# optionally remove suffixes from PDF files and report files
# "somefile.indd.pdf" becomes "somefile.pdf", "somefile.indd.report.pdf" becomes "somefile.report.pdf"
suffixremove => [ '.indd', '.qxd' ],

# optionally remove prefixes from PDF files and report files
# "123456_somefile.pdf" becomes "somefile.pdf", "123456_somefile.report.pdf" becomes "somefile.report.pdf"
# prefixremove => [ '[0-9]{6}_' ],

# extra options to "dt mv" or "dt cp"
# e.g. want to have a notify event triggered each time a file is moved/copied:
# dtopts => ['-E'],
# + "suppress close delay for desktop"
dtopts => ['-E', '-X'],

# profile to use as a last resort
# absolute path
# defaultprofile => '/path/to/profil.kfp',
# relative to HELIOSDIR/var/settings/PDF Preflight
# defaultprofile => 'Proof Profiles/Defaults/profiles/Digital press (color.kfp)',
defaultprofile => '',

# two part regex to configure profile lookup by filename
# leave empty or undefined to disable
# profileext1 => '',
# or use Perl regex profileext1 + profileext2
# match of profileext1 will be used as key entry into extlookup table below
# note that suffix removal is applied first
# profileext1 => '4c|tz',
# file names must end with:
# leave empty to use default = '(\.pdf)*$'
# profileext2 => '(\.pdf)*$',

# set to 1 if you want to have profile key from profileext1 be removed from input filename
# only effecitve if profileext1 und extlookup is set
profkeyremove => 1,

# lookuptable for filename profile recognition, use lower-case keys
# leave empty to disable
# extlookup => '',
# or use hash reference { key => path_to_profile }
# path may be absolute, otherwise relative to HELIOSDIR/var/settings/PDF Preflight
extlookup => {
	'4c' => 'Proof Profiles/Defaults/pdfx-profiles/Create PDF_X-3 (OutputIntent_ ISO Coated).kfp',
	'tz' => 'Digital/sj-tz+x3.kfp',
	},

# generated files will use these suffixes
x3suffix => '.x3.pdf',
txtreportsuffix => '.report.html',
# txtreportsuffix => '.report.txt',

# leave empty for default of server or client, or choose text editing application, if HTML choose browser
# BBEdit: R*ch, TextMate: TxMt, Text Edit: TTXT, Safari: sfri, Firefox: MOZB
# the type code will always be set to TEXT, if creator code is used
txtreportcreator => 'sfri',
pdfreportsuffix => '.report.pdf',
infosuffix => '.info',

# maximum number of tries to avoid name conflicts by inserting a number suffix
# like "myfile.1.pdf" ... "myfile.100.pdf"
# please keep reasonably high
maxnumsuffix => 100,

infotext => '--- nur zur Info ---
Startzeit: __DATE__
Prozess ID: __PID__

Erzeuge __X3__Pruefbericht fuer Eingabedatei:

  __FILE__

Bitte Geduld.

Wenn nach mehreren Minuten kein Ergebnis im Ausgabeordner erscheint, bitte diese Datei
an N.N. schicken.
',

errtext => '--- Interner Feher ---
__DATE__
Prozess ID: __PID__
Es gab leider einen internen Fehler.

Die PDF/X-3 Erzeugung bzw. die Pruefung fuer Datei

  __FILE__

scheiterte.

Bitte diesen Datei an N.N. schicken.

',

# enable some debugging output during runtime
debug => 0,

}
