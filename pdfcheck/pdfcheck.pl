#!/bin/sh
# licensed under BSD license, see http://www.opensource.org/licenses/bsd-license.php
# or LICENSE paragraph in documentation below (perldoc -F pdfcheck.pl)
# Axel Rose, 2006
eval 'read HELIOSDIR < /etc/HELIOSInstallPath ;
	exec "$HELIOSDIR"/var/run/runperl -x -S "$0" ${1+"$@"}'
	if $running_under_some_shell;
#!perl -w
$running_under_some_shell = $running_under_some_shell = 0; # silence warnings
#line 11

use strict;

require 5.005;

use File::Basename;
use FindBin;
use Carp;

my $DEBUG = 0;
my $Id = '$Id$';

local $| = 1; # unbuffered STDOUT
local $/ = ""; # slurp input in one go
my $PID = $$;
my $errorexit = 0;

logit( "INFO - version: $Id" );

# get configuration from "pdfcheck.conf.pl"
my $conf = getconf( $FindBin::Bin . '/' . basename( $0, '.pl' ) . '.conf.pl' );

# Helios dirs and binaries
$conf->{heliosdir} = getheliosdir() unless $conf->{heliosdir};
$conf->{heliosdir} =~ s|/$||; # normalize
logit( "FATAL - No Helios installation dir, please specify 'heliosdir' in 'pdfcheck.conf.pl'!" ) unless -d $conf->{heliosdir};
my $dt = $conf->{heliosdir} . "/bin/dt";
my $prefvalue = $conf->{heliosdir} . "/bin/prefvalue";

# save watched base dir of hotfolder scripts
my $scriptpath = basename( $ARGV[0]) if $ARGV[0];

# check for user specific configuration in IN folder
modconf( $ARGV[0] ? dirname( $ARGV[0] ) : dirname( $ENV{HELIOS_VFFILE} ) );

$DEBUG = 1 if $conf->{debug};

# cache repetitive prefvalue calls in recursivescript()
my %scriptpath;
# cache realpath() calls
my %realpath;

# fixed dirs in HELIOS base dir
my $pdfInspSettings = '/var/settings/PDF Preflight';

$conf->{maxnumsuffix} ||= 100;

# get parameters from environment
my( $queue, $input );
my $userdir = 0;
my $user;

if( $ARGV[0] ) { # called as hotfolder script
	$input = $ARGV[0];
	$userdir = "TRUE" if $conf->{userdirhf};
}
else { # called as notification script
	$input   = $ENV{HELIOS_VFFILE}      || logit( "FATAL - no HELIOS_VFFILE in environment.",      1 );
	$queue   = $ENV{HELIOS_PRINTERNAME} || logit( "FATAL - no HELIOS_PRINTERNAME in environment.", 1 );
	chomp( $userdir = `$prefvalue -k Printers/\Q$queue\E/userdir` );
}
$conf->{insubdir} = 0 if $userdir && $userdir eq "TRUE";

# First step is to lock the input file
system( $dt, "set", "-al", $input ) && logit( "WARNING - unsuccessful lock of '$input'\n$!" );

# if configured remove suffixes from layout programs (.indd, .qxd, etc.)
$input = nametruncate( $input ) if $conf->{suffixremove} || $conf->{prefixremove};

# set file and directory names
my $infile     = basename($input);
my $indir      = dirname($input);
my $basename   = basename($input, '.pdf');

$conf->{tmpdir} = '/tmp' unless $conf->{tmpdir};
logit( "FATAL - tmpdir '$conf->{tmpdir}' is not a directory!", 1 ) unless -d $conf->{tmpdir};
logit( "FATAL - tmpdir '$conf->{tmpdir}' is not writable!", 1 ) unless -w $conf->{tmpdir};
# tmpdir from now on a unique output directory
my $tmpdir     = $conf->{tmpdir} . "/pdfcheck.$PID/";
my $x3out      = $tmpdir . '/' . $basename . $conf->{x3suffix};
my $txt_report = $tmpdir . '/' . $basename . $conf->{txtreportsuffix};
my $pdf_report = $tmpdir . '/' . $basename . $conf->{pdfreportsuffix};

my( $okdir, $copydir, $warndir, $errdir );

if( $userdir && $userdir eq "TRUE" ) {
	if( my $userconf = $conf->{userdirout} ) { # replace possible placeholder __DIR__, __USER__
		logit( "FATAL - configuration for 'userdirout' must contain __DIR__ placeholder", 1 )
			unless $userconf =~ /__DIR__/;
		# TODO: make absolute paths possible
		logit( "FATAL - cannot handle absolute paths for 'userdirout' yet", 1 )
			if $userconf =~ m|^/|;
		$user = $ENV{HELIOS_JOBFOR} || ( split( /\//, dirname( $input ) ) )[-1];
		$userconf =~ s/__USER__/$user/g;
		$okdir = $indir . '/' . $userconf;
		$okdir =~ s/__DIR__/$conf->{ok}/;
		$warndir = $indir . '/' . $userconf;
		$warndir =~ s/__DIR__/$conf->{warning}/;
		$errdir = $indir . '/' . $userconf;
		$errdir =~ s/__DIR__/$conf->{error}/;
		$copydir = $indir . '/' . $userconf;
		$copydir =~ s/__DIR__/$conf->{copy}/;
	}
	else {
		$okdir	 = ($conf->{ok} =~ m|^/| ? '' : $indir)      . '/' . $conf->{ok};
		$copydir = ($conf->{copy} =~ m|^/| ? '' : $indir)    . '/' . $conf->{copy};
		$warndir = ($conf->{warning} =~ m|^/| ? '' : $indir) . '/' . $conf->{warning};
		$errdir	 = ($conf->{error} =~ m|^/| ? '' : $indir)   . '/' . $conf->{error};
	}
}
else {
	$okdir	 = ($conf->{ok} =~ m|^/| ? '' : $indir)       . ($conf->{insubdir} ? '/../' : '/') . $conf->{ok};
	if( $conf->{copy} ) {
		$copydir = ($conf->{copy} =~ m|^/| ? '' : $indir) . ($conf->{insubdir} ? '/../' : '/') . $conf->{copy};
	}
	$warndir = ($conf->{warning} =~ m|^/| ? '' : $indir)  . ($conf->{insubdir} ? '/../' : '/') . $conf->{warning};
	$errdir	 = ($conf->{error} =~ m|^/| ? '' : $indir)    . ($conf->{insubdir} ? '/../' : '/') . $conf->{error};
}

my $logsuffix  = '.txt';
my $oklog      = $okdir . '/' . $basename . '.OK' . $logsuffix; # TODO: OK_LOG wird nirgends benutzt
my $errlog     = $errdir . '/' . $basename . '.ERROR' . $logsuffix;

# Helios dirs
for ( ($okdir, $errdir, $warndir, $conf->{copy} ? $copydir : undef) ) { $_ && checkcreate( $_ ) }
# pure Unix dirs
system( "mkdir", $tmpdir ) && logit( "FATAL - cannot create dir '$tmpdir'\n$!", 1 );

# get pdfInspektor profile

my( $profile, $profilekey );

if( $queue ) { # notification script
	my $prof = $conf->{heliosdir} . '/var/spool/qmeta/' . $queue . '/' . 'PDF_PROFILE';
	$profile = $prof if -f $prof && -r $prof;
}
else { # hotfolder
	if( $ENV{PDF_PROFILE} ) {
		my $prof = $ENV{PDF_PROFILE};
		$prof = $conf->{heliosdir} . $pdfInspSettings . '/' . $prof	if $prof !~ m|^/|;
		if( -f $prof && -r $prof ) { $profile = $prof }
		else { logit( "WARNING - PDF_PROFILE env var '$ENV{PDF_PROFILE}' doesn't point to usable profile" ) }
	}
}

my $inputsave = $input;

unless( $profile ) {
	$profile = findfile( [dirname($input), dirname($input) . '/..'], qr(\.kfp$) );
	logit( "INFO - using hotfolder specific profile '$profile'" ) if $profile;
}

unless( $profile ) {
	# idea by Peter Kleinheider
	if( $conf->{profileext1} && $conf->{extlookup} ) {
		($profile, $profilekey) = profilelookup( $input );
	}
	if( $profile && $profilekey && $conf->{profkeyremove} ) {
		$inputsave  = $input;
		$input      = profkeytruncate( $input, $profilekey );
		$basename   = basename($input, '.pdf');
		$x3out      = $tmpdir . '/' . $basename . $conf->{x3suffix};
		$txt_report = $tmpdir . '/' . $basename . $conf->{txtreportsuffix};
		$pdf_report = $tmpdir . '/' . $basename . $conf->{pdfreportsuffix};
		$oklog      = $okdir  . '/' . $basename . '.OK' . $logsuffix; # TODO: OK_LOG wird nirgends benutzt
		$errlog     = $errdir . '/' . $basename . '.ERROR' . $logsuffix;
	}
}

unless( $profile ) { # last resort
	if( $conf->{defaultprofile} ) {
		my $prof = $conf->{defaultprofile};
		$prof = $conf->{heliosdir} . $pdfInspSettings . '/' . $prof if $prof !~ m|^/|;
		$profile = $prof if -f $prof && -r $prof;
	}
}

unless( $profile ) {
	logfile( $errlog, logtext( $conf->{errtext} . 'FATAL - cannot find any pdfInspektor profile, please see docs how to configure this' ) );
	logit( 'FATAL - cannot find any pdfInspektor profile, please see docs how to configure this', 1 );
}

# TODO: filter -E only for specific dirs
my $pathpat = $conf->{insubdir} ? realpath( dirname( $input ) . '/..' ) : realpath( dirname( $input ) );
$pathpat = qr(\Q$pathpat\E);
if (
  	   ( realpath( dirname($input) ) eq realpath($okdir) )
	|| ( $copydir && ( realpath( dirname( $input ) ) eq realpath( $copydir ) ) )
	|| ( realpath( dirname( $input ) ) eq realpath( $errdir ) )
	|| ( realpath( dirname( $input ) ) eq realpath( $warndir ) )
	|| ( realpath($okdir) =~ $pathpat   && $scriptpath && recursivescript( $scriptpath ) )
	|| ( $copydir && ( realpath($copydir) =~ $pathpat && $scriptpath && recursivescript( $scriptpath ) ) )
	|| ( realpath($errdir) =~ $pathpat  && $scriptpath && recursivescript( $scriptpath ) )
	|| ( realpath($warndir) =~ $pathpat && $scriptpath && recursivescript( $scriptpath ) )
  )
{
	# filter -E from helios dt options to avoid endless loop
	logit( "DEBUG - filtering -E from dtopts to avoid recursion" );
	$conf->{dtopts} = [ grep( !/^-E$/, @{ $conf->{dtopts} } ) ];
}

# set to 1 if profile will cause PDF/X-3 creation
my $createx3 = checkx3profile( $profile );

my $pdfinsp = $conf->{pdfinsp} || $conf->{heliosdir} . '/callas/pdfInspektor3';
my $remote = 1 if $pdfinsp =~ /^ssh /;
unless( $remote ) {	logit( "FATAL - not executable '$pdfinsp'", 1 ) unless -x $pdfinsp }

# command options for pdfInspektor
my $pdfinspopt  = " " . $conf->{pdfinspopt} . " -l=$conf->{reportlang}";
my $pdfx3opt = $pdfinspopt . " -x=" . myquote($x3out);
my( $reporttxt0, $reporttxt1 ) = ( $conf->{reporttxt0}, $conf->{reporttxt1} );

# show user some feedback of processing activity
my $infofile = $okdir . '/' . $basename . $conf->{infosuffix};
logfile( $infofile, logtext( $conf->{infotext}, $createx3 ) );

my( $cmd, $outdir );

# pdfInspektor doesn't like a comma in report filename
( my $txt_report_esc = $txt_report ) =~ s/,/_/g;
( my $pdf_report_esc = $pdf_report ) =~ s/,/_/g;
my $txtrepopt = $conf->{reportstyletxt} ? " --report=$conf->{reportstyletxt}," . myquote($txt_report_esc) : "";
my $pdfrepopt = $conf->{reportstylepdf} ? " --report=$conf->{reportstylepdf}," . myquote($pdf_report_esc) : "";
my $x3repopt  = $createx3 ? "-x=" . myquote($x3out) : "";

$cmd = $pdfinsp . $pdfinspopt . " " . $txtrepopt . " " . $pdfrepopt . " " . $x3repopt .
#	 " \Q$profile\E  \Q$input\E" . ($remote ? "'" : "");
	 " " . myquote($profile) . " " . myquote($input) . ($remote ? "'" : "");
logit("INFO - executing check command:\n$cmd");
my $result = ""; my $outStr = "";
open( FD, $cmd . " 2>&1 |" ) || logit( "FATAL - cannot open piped output from '$cmd'", 1 );
while (<FD>) { $result .= $_ }
close FD;
if( $? & 127 ) { logit( sprintf( "FATAL - pdfInspektor3 died with signal %d, %s coredump\n", ($? & 127), ($? & 128) ? 'with' : 'without' ), 1 ) }

( my( $errors, $warnings ) ) = ($result =~ /\nSummary\s+(\d+)\s+Errors\nSummary\s+(\d+)\s+Warnings\n/s);
unless( defined $errors && defined $warnings ) {
	my $log = "ERROR - pdfInspektor result not understandable: \n\n-----\n$result-----\nCommand:\n$cmd";
	logfile( $errlog, logtext( $conf->{errtext} . $log ) );
	# restore original file name with possible profile key in filename
	if( $inputsave ne $input ) {
		# TODO: generate new names if necessary
		# currently revert failes if input file exists, error file is overwritten!
		if( -r $inputsave ) {
			logit( "WARNING - cannot restore original input name " . basename( $inputsave ) . " since file reappeared" );
		}
		else {
			system( $dt, "mv", $input, $inputsave ) && logit( "FATAL - cannot move '$input' to '$inputsave'\n$!", 1 );
			$input = $inputsave;
			my $errlog2 = $errlog;
			$errlog2 =~ s/\.ERROR\Q$logsuffix\E$/$profilekey.ERROR$logsuffix/;
			system( $dt, "mv", $errlog, $errlog2 ) && logit( "FATAL - cannot move '$errlog' to '$errlog2'\n$!", 1 );
			$errlog = $errlog2;
		}
	}
	logit( $log, 1 );
}
$DEBUG && logit( "DEBUG: errors = '$errors', warnings = '$warnings'" );

if( $errors == 0 ) {
	$outdir = ($warnings == 0) ? $okdir : $warndir;
	$outStr = "INFO - PDF check ok";
	$outStr .= ", $warnings Warning(s)" if $warnings;
	$outStr .= ".\n\n" . $reporttxt0 . $result . $reporttxt1;
}
else {
	$outdir = $errdir;
	$outStr = "INFO - PDF check failed, $errors error(s) found.\n\n" . $reporttxt0 . $result . $reporttxt1;
	$errorexit = 1;
	# restore original file name with possible profile key in filename
	if( $inputsave ne $input ) {
		# TODO: generate new names if necessary
		# currently revert failes if input file exists, error file is overwritten!
		if( -r $inputsave ) {
			logit( "WARNING - cannot restore original input name " . basename( $inputsave ) . " since file reappeared" );
		}
		else {
			system( $dt, "mv", $input, $inputsave ) && logit( "FATAL - cannot move '$input' to '$inputsave'\n$!", 1 );
			$input = $inputsave;
			if( -r $txt_report ) {
				$txt_report =~ s/\Q$conf->{txtreportsuffix}\E$/$profilekey$conf->{txtreportsuffix}/;
			}
			my $pat = $conf->{pdfreportsuffix};
			if( -r $pdf_report ) {
				$pdf_report =~ s/\Q$pat\E$/$profilekey$conf->{pdfreportsuffix}/;
			}
		}
	}
}

logit( $outStr );

# post-process text report
if( $conf->{reportstyletxt} ) {
	if( -r $txt_report_esc ) {
		# reverse report filename substition
		unless( $txt_report eq $txt_report_esc ) {
			system( "mv", $txt_report_esc, $txt_report ) && logit( "FATAL: cannot move '$txt_report_esc' to '$txt_report'\n$!", 1 );
		}
		patch_reportfile( $txt_report ) if $conf->{txtpatchscript}; # ignore errors
		my $txtfile = mover( $txt_report, $outdir );
		if( $conf->{txtreportcreator} ) {
			system( $dt, "set", "-c", $conf->{txtreportcreator}, $txtfile ) &&
			  logit( "WARNING - cannot set creator '$conf->{txtreportcreator}' for file '$txtfile'\n$!" );
		}
	}
}

# post-process pdf report
if( $conf->{reportstylepdf} ) {
	if( -r $pdf_report_esc ) {
		# reverse report filename substition
		unless( $pdf_report eq $pdf_report_esc ) {
			system( "mv", $pdf_report_esc, $pdf_report ) && logit( "FATAL: cannot move '$pdf_report_esc' to '$pdf_report'\n$!", 1 );
		}
		mover( $pdf_report, $outdir );
	}
}

# release lock
system( $dt, "set", "-a-l", $input ) && logit( "WARNING - unlocking input file failed\n$!" );

# copy input file to copy dir
my $copyfile;
if( $conf->{copy} ) {
	# just keep input file where it is if copy == input
	unless( realpath( $copydir ) eq dirname( $input ) ) {
		if( $errors ) {	$copyfile = copier( $input, $copydir ) unless $conf->{dontcopyerrors} }
		else { $copyfile = copier( $input, $copydir ) }
	}
}

my $finalpdf;
if( $createx3 ) {
	$DEBUG && logit( "DEBUG - createx3 = '$createx3', x3out = '$x3out', input = '$input'" );
	if( -r $x3out ) { # successful PDF/X-3 creation
		$finalpdf = mover( $x3out, $outdir );
		-r $input && system( $dt, "rm", "-f", $input ) && logit( "WARNING - cannot remove input pdf '$input'\n$!" );
	}
	else { # PDF/X-3 creation failed
		if( dirname( $input ) eq realpath( $outdir ) ) {
			$DEBUG && logit( "DEBUG: skipping move of resulting pdf" );
			$finalpdf = $input;
		}
		else {
			if( $conf->{discarderrinput} && (realpath($outdir) eq realpath($errdir)) ) {
				system( $dt, "rm", $input ) && logit( "WARNING - cannot remove input pdf '$input'\n$!" );
			}
			else {
				$finalpdf = mover( $input, $outdir );
				# TODO: unlock necessary?
				system( $dt, "set", "-a-l", $finalpdf ) && logit( "WARNING - cannot unlock output pdf '$finalpdf'\n$!" );
			}
		}
	}
}
else {
	$DEBUG && logit( "DEBUG: outdir = '$outdir', errdir = '$errdir'" );
	if( dirname( $input ) eq realpath( $outdir ) ) {
		$DEBUG && logit( "DEBUG: skipping move of resulting pdf" );
		$finalpdf = $input;
	}
	else {
		if( $conf->{discarderrinput} && (realpath($outdir) eq realpath($errdir)) ) {
			system( $dt, "rm", $input ) && logit( "WARNING - cannot remove input pdf '$input'\n$!" );
		}
		else {
			$finalpdf = mover( $input, $outdir );
			# TODO: unlock necessary?
			system( $dt, "set", "-a-l", $finalpdf ) && logit( "WARNING - cannot unlock output pdf '$finalpdf'\n$!" );
		}
	}
}

if( $conf->{postprocess} ) {
	my $postprocess = $conf->{postprocess};
	$postprocess = "$FindBin::Bin/" . $postprocess unless $postprocess =~ m|^/|;
	if( -r $postprocess ) {
		my @pcmd = -x $postprocess ? ( $postprocess ) : ( $conf->{shell} || $^X, $postprocess );
		push( @pcmd, '-f', $finalpdf );
		push( @pcmd, '-c', $copyfile ) if $copyfile;
		push( @pcmd, '-q', $queue ) if $queue;
		push( @pcmd, '-u', $ENV{HELIOS_JOBUSER} || $user ) if $ENV{HELIOS_JOBUSER} || $user;
		$DEBUG && logit( "DEBUG - postprocessing call: '@pcmd'\n" );
		# make configuration avaible as pdfcheck_something environment variables
		for my $ckey (keys %$conf) {
			if   ( ref $conf->{$ckey} eq 'ARRAY' ) { $ENV{'pdfcheck_' . $ckey} = join( ',', @{$conf->{$ckey}} ) }
			elsif( ref $conf->{$ckey} eq 'HASH'  ) { $ENV{'pdfcheck_' . $ckey} = join( ',', each %{$conf->{$ckey}} ) }
			else { $ENV{'pdfcheck_' . $ckey} = $conf->{$ckey} }
		}
		system( @pcmd ) && logit( "WARNING - exit ", $? << 8, " from '@pcmd'" );
	}
	else { logit( "WARNING - postprocessing script '$postprocess' not found" ) }
}

### end of main ###

END {
	$tmpdir && system( "rm", "-rf", $tmpdir ) && warn "WARNING - cannot remove working dir '$tmpdir'\n$!";

	# additional check, $input is normally already moved
	if( $input && -r $input ) {
		system( $dt, "set", "-a-l", $input ) && warn "WARNING - END block cannot unlock '$input'\n$!";
		$outdir = $errdir unless $outdir;

		# leave original input where it is if copydir = inputdir
		if( ! defined $copydir
			|| (defined $copydir && (realpath( $copydir ) ne dirname( $input ) ) )
		  ) {
			# leave original input if result would be moved to input dir
			if( (realpath( $outdir ) ne dirname( $input ) ) ) {
				mover( $input, $errdir ) if $outdir; # even errdir might not be set if configuration is corrupt
			}
		}
	}

	$infofile && -r $infofile && system( $dt, "rm", $infofile ) && warn "WARNING - (end block) cannot remove infofile '$infofile\n";

	if( $conf ) {
		$conf->{exit0} ? exit 0 : exit $errorexit || 0;
	}
}

sub getheliosdir {
	confess( "Not a Helios system!? File '/etc/HELIOSInstallPath' doesn't exist!" ) unless -r '/etc/HELIOSInstallPath';
	( my $path = do { local ( @ARGV, $/ ) = '/etc/HELIOSInstallPath'; <> } ) =~ s/\s+$//s;
	return $path;
}

sub profilelookup {
	my $inp = shift;
	my $prof;
	my $pat = $conf->{profileext1};
	# add capturing parens unless already specified
	$pat = '(' . $pat . ')' unless $pat =~ /\([^()]+\)/;
	$pat = $pat . ($conf->{profileext2} || '(\.pdf)*$');
	# TODO: escape regex tokens
	if( $inp =~ /$pat/i ) {
		my $key = lc $1;
		$DEBUG && logit("DEBUG - key for profilelookup = '$key'");
		$prof = $conf->{extlookup}{$key};
		# if profile uses relative path
		if( $prof && $prof !~ m|^/| ) {
			$prof = $conf->{heliosdir} . $pdfInspSettings . '/' . $prof;
		}
		logit( "WARNING - unsuccessful lookup for input '$inp' + matched suffix '$key'" ) unless $prof;
		unless( -f $prof && -r $prof ) {
			my $log = "FATAL - lookup profile '$prof' not found or not readable";
			logfile( $errlog, logtext( $conf->{errtext} . $log ) );
			logit( $log, 1 );
		}
		return ($prof, $key);
	}
	else {
		logit( "WARNING - '$inp' could not be matched against specified regex '$pat'" );
		return (undef, undef);
	}
}

sub profkeytruncate {
	my $input = shift || confess( "missing parameter to profkeytruncate()" );
	my $key = shift || confess( "missing parameter to profkeytruncate()" );

	(my( $base, $path, $suffix )) = fileparse( $input, '\.pdf$' );
	$base && $base =~ s/${key}//i;
	my $newname = $path . $base . $suffix;
	$DEBUG && logit("DEBUG - profkeytruncate() moves '$input' to '$newname'");
	system( $dt, "mv", $input, $newname ) && logit( "FATAL - move '$input' to '$newname' failed with $!", 1 );

	return $newname;
}

sub nametruncate {
	my $input = shift || die "missing parameter to nametruncate()";
	my $newname = $input;
	for my $suf ( @{$conf->{suffixremove}} ) {
		if( $input =~ /${suf}\.pdf$/ ) {
			$newname =~ s/${suf}\.pdf$/.pdf/;
			last; # only one substitution!
		}
	}

	for my $prefix ( @{$conf->{prefixremove}} ) {
		my $tmp_basename = basename($newname);
		my $tmp_dirname = dirname($newname);
		if( $tmp_basename =~ /^${prefix}/ ) {
			$tmp_basename =~ s/^${prefix}//;
			$newname = $tmp_dirname . "/" . $tmp_basename;
			last;
		}
	}

	unless( $newname eq $input ) {
		if( -r $newname ) {
			logit( "WARNING - suffix cannot be shortened: '$newname' already exists" );
			return $input;
		}
		else {
			# lock is automatically moved too (?)
			system( $dt, "mv", $input, $newname ) && logit( "FATAL - move '$input' to '$newname' failed with $!", 1 );
		}
	}
	return $newname;
}

sub checkx3profile {
	my $profile = shift or die "missing parameter to checkx3profile()";
	my $ok = 0;
	open( X3KFP, "<" . $profile ) or die $!;
	while( <X3KFP> ) {
		if( /<pdfxoutintent>/ ) {
			$ok = 1;
			last;
		}
	}
	close X3KFP;
	return $ok;
}

# return first found file (in scalar context) or list of all found files (in array context)
# searching in dirs, matching pattern
# findfile( [$dir1, $dir2, ...], $pattern )
# tuning: internally skips dir2 if dir2==dir1 or any previous dir parameter

sub findfile {
	my( $dirs, $pattern ) = @_;
	my $list = wantarray;
    confess( "INTERNAL ERROR - missing directory parameter to findfile()" ) unless $dirs->[0];
    confess( "INTERNAL ERROR - missing pattern parameter to findfile()" ) unless $pattern;

    my $files;
	my %dirsdone;

  DIRS: for my $dir ( @$dirs ) {
		next DIRS if $dirsdone{$dir};
		$dirsdone{$dir}++;
		# $DEBUG && logit( "DEBUG - findfile() in dir '$dir'" );
		opendir( DH, $dir ) or confess( "FATAL - cannot opendir('$dir')\n$!" );
		while ( defined( my $file = readdir DH ) ) {
			next unless -f $dir . '/' . $file;
			next if $file =~ /^\./;
			if ( $file =~ /$pattern/ ) {
				push( @$files, $dir . '/' . $file );
				unless( $list ) {
					closedir DH;
					last DIRS;
				}
			}
		}
		closedir DH;
	}

	if( $files->[0] ) {
		return( $list ? @$files : $files->[0] );
	}
	else { return undef }
}

sub mover {
	my( $from, $to ) = @_;
	my $target = namer( $to . '/' . basename( $from ) );
	system( $dt, "mv", grep {defined} (@{$conf->{dtopts}}, $from, $target) ) && logit( "FATAL - cannot move '$from' to '$target'\n$!" , 1 );
	return $target;
}

sub copier {
	my( $from, $to ) = @_;
	my $target = namer( $to . '/' . basename( $from ) );
	system( $dt, "cp", "-p", grep {defined} (@{$conf->{dtopts}}, $from, $target) ) && logit( "FATAL - cannot move '$from' to '$target'\n$!" , 1 );
	return $target;
}

sub namer {
	my $file = shift || confess "no input parameter!";

	# trivial case
	return $file if ! -r $file;

	my $suffix = "";
	my $pattern = join( '|', map{ "\Q$_\E" } ($conf->{txtreportsuffix}, $conf->{pdfreportsuffix}, $conf->{x3suffix}, $conf->{infosuffix}, '.ERROR' . $logsuffix, '.pdf') );

	if( $file =~ qr($pattern$) ) {
		$suffix = $&
	}
	my $numsuffix = '';
	my $basename = $file;
	$basename =~ s/${suffix}$//;
	my $newname = $basename;
	if( $basename =~ /\.(\d+)$/ ) {
		$numsuffix = $1;
		$newname =~ s|${numsuffix}$|++$numsuffix|e;
	}
	else { $newname .= '.1' }
	$newname .= $suffix;

	my $i = 0;
	while( $i++ < $conf->{maxnumsuffix} ) {
		if( ! -r $newname ) {
			return $newname;
		}
		$newname = $basename . ".$i" . $suffix;
	}
    logit( "FATAL - couldn't get new output name for '$file' after $conf->{maxnumsuffix} tries", 1 );
}

# check for modifcations of script configuration in input dir, parent input dir, script path dir
sub modconf {
	my $in = shift;
	my $where = [$in, $in . '/..'];

	my $conffile = findfile( $where, qr(\.conf.pl$) );
	return unless $conffile;
	logit( "INFO - processing extra configuration file '$conffile'" );

	my $c = do $conffile;
	die "FATAL: parse error in '$conffile'\n$@" if $@;
	for my $ckey (keys %$c) {
		# overwrite/insert into global conf
		$conf->{$ckey} = $c->{$ckey};
	}
}

sub getconf {
	my $cfile = shift || die;

	die "FATAL: '$cfile' not found\n" unless -r $cfile;
	my $conf = do $cfile;
	die "FATAL: parse error in '$cfile'\n$@" if $@;

	for my $envkey (keys %ENV) {
		if( exists $conf->{$envkey} ) {
			$conf->{$envkey} = $ENV{$envkey}
		}
	}

	return $conf;
}

sub patch_reportfile {
	my $file = shift || return;
	my $patchscript = $conf->{txtpatchscript};
	$patchscript = "$FindBin::Bin/" . $patchscript unless $patchscript =~ m|^/|;
	unless( -r $patchscript ) {
		logit( "WARNING - patch script '$patchscript' not readable, skipping ...\n" );
		return 1;
	}
	my @pcmd = -x $patchscript ? ( $patchscript, $file, $conf->{reportlang} ) : ( $conf->{shell} || $^X, $patchscript, $file, $conf->{reportlang} );
	logit( "INFO - transforming text report '@pcmd'" );
	system( @pcmd ) && logit( "WARNING - perl '$patchscript' '$file' return with errors" );
	return $? >> 8;
}

sub logtext {
	my( $txt, $x3 ) = @_;
	confess( "missing txt parameter to logtext( txt, x3 )" ) unless $txt;

	chomp( my $date = `date "+%d.%m.%Y %H:%M:%S"` );

	my $inpdf = basename( $input, '' );
	$txt =~ s/__DATE__/$date/sg;
	$txt =~ s/__FILE__/$inpdf/sg;
	$txt =~ s/__PID__/$PID/sg;
	$txt =~ s|__X3__|$x3 ? 'PDF/X3 ' : ''|esg;

	return $txt;
}

sub checkcreate {
	my $dir = shift || return;
	unless( -d $dir ) {
		system( $dt, "mkdir", "-p", "-m", 2777, $dir )
		  && logit( "FATAL - cannot create dir '$dir'\n$!", 1 );
	}
}

# creates a new file with text content and places the file safely in a Helios share
sub logfile {
	my( $file, $str ) = @_;
	logit( "INTERNAL ERROR - no parameters for sub logfile(), \@_ = @_", 1 ) unless $file && $str;
	my $tmplog = $tmpdir . '/' . basename( $file );

	open( LOGF, ">" . $tmplog ) || logit("WARNING: cannot write to temporary logfile '$tmplog'", 1 );
	print LOGF $str;
	close LOGF;

	mover( $tmplog, dirname( $file ) );
}

sub recursivescript {
	my $testpath = shift || confess( "INTERNAL ERROR - no parameter to recursivescript()" );
	# return cached result
	return $scriptpath{$testpath} if exists $scriptpath{$testpath};

	# get list of all installed scripts
	## VERY STRANGE:
	## my @scripts = `$prefvalue -k Programs/scriptsrv/Config -l`;
	## sometimes seems to return a scalar!
	my @scripts = split( /\n/s, `$prefvalue -k Programs/scriptsrv/Config -l` );

	for my $script ( @scripts ) {
		chomp( $script );
		chomp( my $path = `$prefvalue -k Programs/scriptsrv/Config/\Q$script\E/Path` );
		if( $path eq $testpath ) {
			chomp( my $recursive = `$prefvalue -k Programs/scriptsrv/Config/\Q$script\E/Recursive` );
			if( $recursive && $recursive eq "TRUE" ) {
				$DEBUG && logit( "DEBUG - found recursiveness" );
				# cache results
				$scriptpath{$testpath} = 1;
				return 1;
			}
			else {
				$scriptpath{$testpath} = 0;
				return 0;
			}
			last;
		}
	}
	$scriptpath{$testpath} = 0;
	return 0;
}

sub realpath {
	my $path = shift || confess( "INTERNAL ERROR - no parameter to realpath()" );

	# return cached result
	return $realpath{$path} if exists $realpath{$path};

	my $dir;

	if( -f $path ) { $dir = dirname( $path ) }
	elsif( -d $path ) { $dir = $path }
	else { warn "FAILED - realpath( '$path' ) can only work with plain files or directories\n"; return undef }

	chomp( my $oldpwd = `pwd` );
	chdir $dir || warn "FAILED - chdir( '$dir' )\n$!\n";
	chomp( my $pwd = `pwd` );
	chdir $oldpwd  || warn "FAILED: chdir( '$dir' )\n$!\n";
	# remove trailing / to make dirs comparable
	$pwd =~ s|/+$||;

	# cache results
	$realpath{$path} = $pwd;

	return $pwd;
}

sub myquote {
	# do not escape those characters
	# escaping of UTF-8 characters (bytes > \x7F) seems to be problematic
	# if standard mechanism \Q$cmd\E is used
	(my $s = $_[0] ) =~ s/([^A-Za-z_0-9.%\-\/\x80-\xff])/\\$1/g;
	return $s;
}

sub logit {
	my ( $msg, $exit ) = @_;
	chomp( my $date = `date "+%d.%m.%Y %H:%M:%S"` );
	warn "$date [$$]: $msg\n";
	if( defined $exit ) {
		$errorexit = $exit;
		exit $exit;
	}
}

sub heladminhelp {
	# support HELIOS Admin with a sample configuration
	my $default_settings = <<'</SETTINGS>';
<SETTINGS>
<General
        Enable="true"
        Hot_Folder="/choose/your/path"
        Include_Subdirectories="false"
        User="root"
        Timeout="0"
/>
<File_Types
        Types="PDF "
        Suffixes="pdf"
        Folder_Changes="false"
/>
<Environment
        PDF_PROFILE="Proof Profiles/Defaults/profiles/Digital press (color).kfp"
		reportlang="de"
/>
</SETTINGS>
}

__END__

=head1 NAME

	pdfcheck.pl

=head1 SYNOPSIS

	pdfcheck.pl

	see documentation by executing "perldoc -F pdfcheck.pl"

=head1 DESCRIPTION

Notification and hotfolder script for Helios EtherShare + pdfHandshake.

The script uses calles pdfInspector to check a spooled PDF file with the configured PDF preflight profile.
Output goes, if results are positve, to the configured B<okdir>, otherwise to the B<errdir> (see configuration file "pdfcheck.conf.pl")

A simple text logfile will accompany the checked PDF file.

=head1 INSTALLATION

Copy the script file (pdfcheck.pl) and the configuration file (pdfcheck.conf.pl) into your
scripts directory.

Further instruction may be found in the supplied "INSTALL" file.

=cut

=head1 WORKFLOW (slightly outdated description)

Spooled files go to an invisible folder PDF.

The Hotfolder accepts files copied into the IN folder.

First step is to create an small text file (default suffix ".info") in folder OUT.
This is to give the user some feedback and help debugging if a process terminates by accident.

Files in IN are locked with "dt set -al" as soon as the the script becomes active.

All intermediate files are copied with a unique name (by using the script's process id) into I<< $conf->{tmpdir}/<PID> >>
thus avoiding name conflicts with files processed by other queues using the same pdfcheck.pl script.

If there is any file PDF_CREATE_X3 in $HELIOSDIR/var/spool/qmeta/your-queue/ directory
the input PDF is converted with this pdfInspektor profile to PDF/X-3. If there is no
such file this step is skipped.

=head2  with PDF/X-3 creation

=over

If there was any error creating a PDF/X-3 file (e.g. if fonts are not included) the input
file is copied to the ERROR directory.
The reason is logged in "scriptsrv.log"/"printer.acct" and to a file .ERROR.txt.

=back

Either the created PDF/X-3 file or the PDF file from the IN directory is checked with
$HELIOSDIR/var/spool/qmeta/your-queue/PDF_PROFILE (when run as a notification script)
or with the profile taken from the environment variable PDF_PROFILE.

If there are errors detected by pdfInspektor the input PDF goes the the configured
ERROR directory accompanied by a short text report and a more comprehensive PDF report file.

If there are no errors but warnings you will get a text report and a PDF report.

If there are no errors and no warnings only a short text report is produced.
The input PDF or the created PDF go to the success dir. The configuration value
"alwayspdfreport" determines whether you will get PDF reports for clean cases too.

"preserveinfile" set to 1 will copy the input PDF file to the output directory
if the script creates PDF/X-3 files. Otherwise it will be deleted.

If no PDF/X-3 conversion takes place the input PDF will always be copied to
the output directory.

At last all intermediate files and the .info file in the OUT directory are removed,
locks are released.

=cut

=head1 BUGS/TODOS

AFP messages sent to the client if script exits with non zero value are not readable. Perhaps
this could be trapped and the message be simplified.

Logged messages don't show a clear preflight profile name but rather "PDF_PROFILE" as the used profile name.

Proper handling of directories copied into the hotfolder

convert decomposed/composed Unicode characters for log files and messages

=head1 AUTHOR

	Axel Rose

=head1 LICENSE

Copyright (c) 2006, Axel Rose
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

=over 2

=item

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

=item

Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

=item

Neither the name of Axel Rose nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 VERSION

	$Id$

=cut
