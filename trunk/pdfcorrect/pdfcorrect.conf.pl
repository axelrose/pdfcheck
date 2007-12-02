# pdfcorrect.conf.pl
#
# configuration file for pdfcorrect.pl


# never delete this curly brace, file must have valid Perl syntax (check with "perl -c pdfcorrect.conf.pl")
{
# your Helios installation is in:
# keep empty to autodetect
# heliosdir => '/usr/local/helios',

# all work files go there, don't share this directory with Helios!
# empty value defaults to directory /tmp (subdirectories named 'pdfwork.<pid>')
# tmpdir => '/choose/your/own/tmpdir/pdfwork',

# choose binary for pdfInspektor
# just keep empty to use default '/usr/local/pdfCorrect_CLI/pdfCorrect'
# pdfcorr => '/path/to/your/installation/pdfCorrect',
# with remote execution:
# pdfcorr => 'ssh pdfserver.domain.org \'/usr/local/pdfCorrect_CLI/pdfCorrect',

# don't show progress info, always overwrite
pdfcorropt => '-p -a',

# start/end line of text reports in Helios log files
reporttxt0 => "\n------------- pdfCorrect -------------\n",
reporttxt1 =>   "------------- pdfCorrect -------------\n",

# txtreport: create a textual report of the correction process
# default: 0
# txtreport => 0,
# txtreport => 1,

# txtreportsuffix, e.g. myfile.pdf -> myfile.report.txt
# default: '.report.txt'
# txtreportsuffix => '.report.txt',

# Mac Creator Code for text report file
# leave empty for default of server or client, or choose text editing application, if HTML choose browser
# BBEdit: R*ch, TextMate: TxMt, Text Edit: TTXT, Safari: sfri, Firefox: MOZB
# the type code will always be set to TEXT, if creator code is used
txtreportcreator => 'sfri',

# output directory
# don't leave empty!
ok => 'OUT',

# output directory errors
# don't leave empty!
error => 'ERROR',

# copy original input files after processing to this directory
# may be left empty or identical to ok/error directory
copy => 'ORIG',

# if pdfCorrect run results in errors
# 0: copy all input files to copy dir
# 1: don't copy
# default: 0
# has no effect is copy dir is not defined
# dontcopyerrors => 0,
# dontcopyerrors => 1,

# 1: input directory is a subdirectory (DIR:IN, DIR:ERROR, DIR:OUT)
# 0: subdir is on top of output directories (DIR, DIR:ERROR, DIR:OUT)
insubdir => 1,

# effective only for notification script
# 1: always exit with success
# 0: FATAL errors will
#    move the input job (PostScript) to the error queue and
#    notify the client user with HELIOS standard methods
exit0 => 0,

# after finishing "pdfcorrect.pl" a postprocessing script might be called
# postprocess => 'pdfcheck.postprocess.pl',
# note:
# use a relative path to start path from directory where the executed "pdfcheck.pl" is
# use an absolute path otherwise
# if the script is not executable the Perl interpreter will be used to launch the script
# unless you have a different shell configured, see configuration key 'shell'

# base for out/err/copy dir
# default is to have those directories within the user dir
# userdirout => '',
# __DIR__ must be present and is replaced by ok/error/copy as configured above
# __USER__ will be replaced by content of $ENV{HELIOS_JOBFOR}
# relative path starting from dir where the input pdf file arrives
# userdirout => '../../__DIR__/__USER__',

# name of generated configuration file (from concatenation of existing .cfg files)
# default: _generated_
# suffix '.cfg' will be applied
generatedcfg => '_generated_',

# suffix will be used to mark converted files, will be added before any existing .pdf suffix
# default: '.conv'
# convsuffix => '.conv',

# always mark corrected files by 'convsuffix' (see below)
# default: 0
# markcorrected => 0,

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
# relative to HELIOSDIR/var/settings/pdfCorrect
# or Profiles subdir of pdfCorrect executable
# defaultprofile => 'Proof Profiles/Defaults/profiles/Digital press (color.kfp)',
defaultprofile => '',

# two part regex to configure profile lookup by filename
# leave empty or undefined to disable
# profileext1 => '',
# or use Perl regex profileext1 + profileext2
# match of profileext1 will be used as key entry into extlookup table below
# note that suffix removal is applied first
profileext1 => 'corr1|corr2|.corr3',
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
# path may be absolute, otherwise relative to HELIOSDIR/var/settings/pdfCorrect
# or Profiles subdir of pdfCorrect executable
extlookup => {
	'corr1' => '/esvols/konserve/reserve-pdf-out/TEST2/Profiles/Minimum file size PDF.cfg',
	'corr2' => '/esvols/konserve/reserve-pdf-out/TEST2/Profiles/Minimum file size PDF.cfg',
	'.corr3' => 'Flip pages horizontally.cfg',
	},

# processing information is signalled in a file <input>.infosuffix
infosuffix => '.info',

# maximum number of tries to avoid name conflicts by inserting a number suffix
# like "myfile.1.pdf" ... "myfile.100.pdf"
# please keep reasonably high
maxnumsuffix => 100,

infotext => '--- nur zur Info ---
Startzeit: __DATE__
Prozess ID: __PID__

Starte pdfCorrect Lauf ueber die Datei

  __FILE__
mit Profil

  __PROFILE__

Bitte etwas Geduld.

Wenn nach mehreren Minuten kein Ergebnis im Ausgabeordner erscheint, bitte diese Datei
an N.N. schicken.
',

errtext => '--- Interner Feher ---
__DATE__
Prozess ID: __PID__
Es gab leider einen internen Fehler.

Der pdfCorrect Lauf fuer Datei

  __FILE__

mit Profil

  __PROFILE__

scheiterte.

Bitte diese Datei an N.N. schicken.

',

resulttext => '--- pdfCorrect Ergebnis ---
__DATE__

Datei : __FILE__
Profil: __PROFILE__

',

# enable some debug output during runtime
debug => 0,

}

