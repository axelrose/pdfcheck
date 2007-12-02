#!/bin/sh
# Axel Rose, 2006
eval 'read HELIOSDIR < /etc/HELIOSInstallPath ;
        exec "$HELIOSDIR"/var/run/runperl -x -S "$0" ${1+"$@"}'
        if $running_under_some_shell;
#!perl -w
$running_under_some_shell = $running_under_some_shell = 0; # silence warnings
#line 9

use strict;

require 5.005;

use File::Basename;
use FindBin;
use Carp;

my $DEBUG = 0;
my $Id    = '$Id: pdfcorrect.pl 194 2006-12-19 11:40:04Z rose $';

local $| = 1;     # unbuffered STDOUT
local $/ = "";    # slurp input in one go
my $PID = $$;

logit("INFO - version: $Id");


# get configuration from "pdfcorrect.conf.pl"
my $conf = getconf( $FindBin::Bin . '/' . basename( $0, '.pl' ) . '.conf.pl' );

# Helios dirs and binaries
$conf->{heliosdir} = getheliosdir() unless $conf->{heliosdir};
logit("FATAL - No Helios installation dir, please specify 'heliosdir' in 'pdfcorrect.conf.pl'!")
  unless -d $conf->{heliosdir};
my $dt = $conf->{heliosdir} . "/bin/dt";
my $prefvalue = $conf->{heliosdir} . "/bin/prefvalue";

# save watched base dir of hotfolder scripts
my $scriptpath = scriptpath( $0 ) if $ARGV[0];

# check for user specific configuration in IN folder
modconf( $ARGV[0] ? dirname( $ARGV[0] ) : dirname( $ENV{HELIOS_VFFILE} ) );

$DEBUG = 1 if $conf->{debug};

# cache repetitive prefvalue calls in recursivescript()
my %scriptpath;
# cache realpath() calls
my %realpath;

my $pdfcorr = $conf->{pdfcorr} || '/usr/local/pdfCorrect_CLI/pdfCorrect';

$conf->{convsuffix} ||= '.conv';
$conf->{resulttext} ||= "";
$conf->{maxnumsuffix} ||= 100;

# fixed dirs in HELIOS base dir
my $pdfCorrSettings = '/var/settings/pdfCorrect';

# get parameters from environment
my ( $queue, $input );
my $userdir = 0;
my $user;

if ( $ARGV[0] ) {    # called as hotfolder script
    $input = $ARGV[0];
	$userdir = "TRUE" if $conf->{userdirhf};
}
else {               # called as notification script
    $input = $ENV{HELIOS_VFFILE}      || logit( "FATAL - no HELIOS_VFFILE in environment.",      1 );
    $queue = $ENV{HELIOS_PRINTERNAME} || logit( "FATAL - no HELIOS_PRINTERNAME in environment.", 1 );
    chomp( $userdir = `$prefvalue -k Printers/\Q$queue\E/userdir` );
}
$conf->{insubdir} = 0 if $userdir && $userdir eq "TRUE";

my $errorexit = 0;

# First step is to lock the input file
system( $dt, "set", "-al", $input ) && logit("FATAL - unsuccessful lock of '$input'\n$!", 1);

# if configured remove suffixes from layout programs (.indd, .qxd, etc.)
$input = nametruncate($input) if $conf->{suffixremove} || $conf->{prefixremove};

# set file and directory names
my $infile   = basename($input);
my $indir    = dirname($input);
my $basename = basename( $input, '.pdf' );

$conf->{tmpdir} = '/tmp' unless $conf->{tmpdir};
logit( "FATAL - tmpdir '$conf->{tmpdir}' is not a directory!", 1 ) unless -d $conf->{tmpdir};
logit( "FATAL - tmpdir '$conf->{tmpdir}' is not writable!",    1 ) unless -w $conf->{tmpdir};

# tmpdir from now on a unique output directory
my $tmpdir = $conf->{tmpdir} . "/pdfcorrect.$PID/";

$conf->{txtreportsuffix} ||= '.report.txt';
my $txtreport = $basename . $conf->{txtreportsuffix};
my $output = $tmpdir . '/' . basename( $input, '' );

my ( $okdir, $copydir, $errdir );
if ( $userdir && $userdir eq "TRUE" ) {
    if ( my $userconf = $conf->{userdirout} ) {    # replace possible placeholder __DIR__, __USER__
        logit( "FATAL - configuration for 'userdirout' must contain __DIR__ placeholder", 1 )
          unless $userconf =~ /__DIR__/;
		# TODO: make absolute paths possible
		logit( "FATAL - cannot handle absolute paths for 'userdirout' yet", 1 )
		  if $userconf =~ m|^/|;
		$user = $ENV{HELIOS_JOBFOR} || ( split( /\//, dirname( $input ) ) )[-1];
        $userconf =~ s/__USER__/$user/g;
        $okdir = $indir . '/' . $userconf;
        $okdir =~ s/__DIR__/$conf->{ok}/;
        $errdir = $indir . '/' . $userconf;
        $errdir =~ s/__DIR__/$conf->{error}/;
        $copydir = $indir . '/' . $userconf;
        $copydir =~ s/__DIR__/$conf->{copy}/;
    }
    else {
		$okdir	 = ($conf->{ok} =~ m|^/| ? '' : $indir)      . '/' . $conf->{ok};
		$copydir = ($conf->{copy} =~ m|^/| ? '' : $indir)    . '/' . $conf->{copy};
		$errdir	 = ($conf->{error} =~ m|^/| ? '' : $indir)   . '/' . $conf->{error};
    }
}
else {
	$okdir	 = ($conf->{ok} =~ m|^/| ? '' : $indir)      . ($conf->{insubdir} ? '/../' : '/') . $conf->{ok};
	$copydir = ($conf->{copy} =~ m|^/| ? '' : $indir)    . ($conf->{insubdir} ? '/../' : '/') . $conf->{copy};
	$errdir	 = ($conf->{error} =~ m|^/| ? '' : $indir)   . ($conf->{insubdir} ? '/../' : '/') . $conf->{error};
}

my $logsuffix = '.txt';
my $errlog    = $errdir . '/' . $basename . '.ERROR' . $logsuffix;

# Helios dirs
for ( ( $okdir, $errdir, $conf->{copy} ? $copydir : undef ) ) { $_ && checkcreate($_) }

# pure Unix dirs
system( "mkdir", $tmpdir ) && logit( "FATAL - cannot create dir '$tmpdir'\n$!", 1 );

# get pdfCorrect profile(s)

my ( $profile, $profilekey );

if ($queue) {    # notification script
    my $prof = $conf->{heliosdir} . '/var/spool/qmeta/' . $queue . '/' . 'PDF_CORRECT';
    $profile = $prof if -f $prof && -r $prof;
}
else {           # hotfolder
    if ( $ENV{PDF_CORRECT} ) {
        $profile = defprofile( $ENV{PDF_CORRECT} );
        logit("WARNING - PDF_CORRECT env var '$ENV{PDF_CORRECT}' doesn't point to usable profile") unless -f $profile && -r $profile;
    }
}

unless ($profile) {
	my @profiles = $scriptpath
	  ? findfile( [dirname($input), dirname($input) . '/..', $scriptpath], qr|^(?!$conf->{generatedcfg}).+\.cfg$| )
	  : findfile( [dirname($input), dirname($input) . '/..'], qr|^(?!$conf->{generatedcfg}).+\.cfg$| );
    if( $profiles[0] ) {
		# more than one .cfg file
		if( scalar @profiles > 1 ) {
			$DEBUG && logit( "DEBUG - found profiles: " . join( " ", @profiles  ) );
			$profile = generateprofile( @profiles );
		}
		# just one .cfg file
		else { $profile = $profiles[0] }
	}
    logit("INFO - using hotfolder specific profile '$profile'") if $profile;
}

my $inputsave = $input;

unless ($profile) {
    if ( $conf->{profileext1} && $conf->{extlookup} ) {
        ( $profile, $profilekey ) = profilelookup($input);
    }
    if ( $profile && $profilekey && $conf->{profkeyremove} ) {
		# remember old name if conversion failes
		$inputsave  = $input;
        $input      = profkeytruncate( $input, $profilekey );
		$txtreport  =~ s/$profilekey$conf->{txtreportsuffix}$/$conf->{txtreportsuffix}/i;
        $output     = $tmpdir . '/' . basename( $input, '' );
        $basename   = basename( $input, '.pdf' );
        $errlog     = $errdir . '/' . $basename . '.ERROR' . $logsuffix;
    }
}

unless ($profile) {                                                # last resort
    if ( $conf->{defaultprofile} ) {
        my $prof = defprofile( $conf->{defaultprofile} );
        $profile = $prof if -f $prof && -r $prof;
    }
}

unless( $profile ) {
	logfile( $errlog, logtext( $conf->{errtext} . 'FATAL - cannot find any pdfCorrect profile, please see docs how to configure this' ) );
	logit( "FATAL - cannot find any pdfCorrect profile, please see docs how to configure this", 1 );
}

# TODO: filter -E only for specific dirs
my $pathpat = $conf->{insubdir} ? realpath( dirname( $input ) . '/..' ) : realpath( dirname( $input ) );
$pathpat = qr(\Q$pathpat\E);
if (
  	   ( realpath( dirname($input) ) eq realpath($okdir) )
	|| ( realpath( dirname( $input ) ) eq realpath( $copydir ) )
	|| ( realpath( dirname( $input ) ) eq realpath( $errdir ) )
	|| ( realpath($okdir) =~ $pathpat && $scriptpath && recursivescript( $scriptpath ) )
	|| ( realpath($copydir) =~ $pathpat && $scriptpath && recursivescript( $scriptpath ) )
	|| ( realpath($errdir) =~ $pathpat && $scriptpath && recursivescript( $scriptpath ) )
  )
{
	# filter -E from helios dt options to avoid endless loop
	$DEBUG && logit( "DEBUG - filtering '-E' from dtopts to avoid recursion" );
	$conf->{dtopts} = [ grep( !/^-E$/, @{ $conf->{dtopts} } ) ];
}

# check for conflicts if output files go into the same directory
my $renameinfile = 0;
if( ( realpath( $copydir ) eq realpath( $okdir ) ) || ( realpath( $copydir ) eq realpath( $errdir ) ) ) {
	# user wants to have automatic renaming
	if( $conf->{markcorrected} ) {
		$output =~ s/(\.pdf)*$/$conf->{convsuffix}$1/;
	}
	# we have to rename the input file
	else {
		$renameinfile = 1;
	}
}

my $remote = 1 if $pdfcorr =~ /^ssh /;
unless ($remote) { logit( "FATAL - not executable '$pdfcorr'", 1 ) unless -x $pdfcorr }

my ( $reporttxt0, $reporttxt1 ) = ( $conf->{reporttxt0}, $conf->{reporttxt1} );

# show user some feedback of processing activity
my $infofile = $okdir . '/' . $basename . $conf->{infosuffix};
logfile( $infofile, logtext( $conf->{infotext} ) );

### the real work is done here ###

my $ret;
my $cmd = $pdfcorr . " " . $conf->{pdfcorropt} . " \Q$profile\E \Q$input\E \Q$output\E" . ( $remote ? "'" : "" );
logit("INFO - executing convert command:\n$cmd");
my $result = "";
my $outStr = "";
open( FD, $cmd . " 2>&1 |" ) || logit( "FATAL - cannot open piped output from '$cmd'", 1 );
while (<FD>) { $result .= $_ }
close FD;
if ( $? == -1 ) { logit( "FATAL - failed to execute '$pdfcorr':\n$!", 1 ) }
elsif ( $? & 127 ) {
    logit(
        sprintf(
            "FATAL - pdfCorrect died with signal %d, %s coredump\n",
            ( $? & 127 ),
            ( $? & 128 ) ? 'with' : 'without'
        ),
        1
    );
}
else { $ret = $? >> 8 }

# exit 0 - no correction necessary
# exit 1 - correction done
# exit 2 - error

# release lock
system( $dt, "set", "-a-l", $input ) && logit("WARNING - unlocking input file failed\n$!");

# copy input file to copy dir
my $copyfile;
if ( $conf->{copy} ) {

	# just keep input file where it is if copy == input
	unless( realpath( $copydir ) eq dirname( $input ) ) {

		# no error
		if ($ret == 0 || $ret == 1) { $copyfile = copier( $input, $copydir ) }
		# error return 2 or any other error
		else { $copyfile = copier( $input, $copydir ) unless $conf->{dontcopyerrors} }
	}
}

my $finalpdf;
my $reporttxt = $reporttxt0 . $result . $reporttxt1;
if ( $ret == 0 ) {
	$reporttxt = "INFO - no correction necessary, output = input" . $reporttxt;
    logit( $reporttxt );
	if( $conf->{txtreport} ) {
		my $report = $okdir . '/' . $txtreport;
		logfile( $report, logtext( $conf->{resulttext} . $reporttxt ) );
		settxtcreator( $report ) if $conf->{txtreportcreator};
	}
	# ensure input is really identical, but with configured new name ('markcorrected', 'profkeyremove')
	system( "cp", "-p", $input, $output ) && logit( "FATAL - cannot 'cp -p $input $output'\n$!", 1 );
	# don't move away input file if copydir is configured to be inputdir
	unless( realpath( $copydir ) eq dirname( $input ) ) {
		system( $dt, "rm", "-f", $input ) && logit("WARNING - cannot remove input pdf '$input'\n$!")
	}
	if( $renameinfile ) {
		copier( $input, $okdir );
		system( $dt, "rm", "-f", $input ) && logit("WARNING - cannot remove input pdf '$input'\n$!");
		$finalpdf = mover( $output, $okdir );
	}
    $finalpdf = mover( $output, $okdir );
}
elsif ( $ret == 1 ) {
    $reporttxt = "INFO - correction performed" . $reporttxt;
    logit( $reporttxt );
	if( $conf->{txtreport} ) {
		my $report = $okdir . '/' . $txtreport;
		logfile( $report, logtext( $conf->{resulttext} . $reporttxt ) );
		settxtcreator( $report ) if $conf->{txtreportcreator};
	}
	# don't move away input file if copydir is configured to be inputdir
	unless( realpath( $copydir ) eq dirname( $input ) ) {
		system( $dt, "rm", "-f", $input ) && logit("WARNING - cannot remove input pdf '$input'\n$!")
	}
	if( $renameinfile ) {
		copier( $input, $okdir );
		system( $dt, "rm", "-f", $input ) && logit("WARNING - cannot remove input pdf '$input'\n$!");
		$finalpdf = mover( $output, $okdir );
	}
	else { $finalpdf = mover( $output, $okdir ) }
}
else{
	if ( $ret == 2 ) { $reporttxt = "ERROR - correction failed" . $reporttxt }
	else { $reporttxt = "FATAL - unexepected return code: '$ret'" . $reporttxt }
	logfile( $errlog, logtext( $conf->{errtext} . $reporttxt . "\n\nCommand:\n$cmd\nreturns: $ret\n" ) );
	settxtcreator( $errlog ) if $conf->{txtreportcreator};
    logit( $reporttxt );
	# restore original file name with possible profile key in filename
	if( $inputsave ne $input ) {
		if( -r $inputsave ) {
			$inputsave = namer( $inputsave );
			logit( "WARNING - original input file '$ARGV[0]' reappeard, using new name '$inputsave'" );
		}
		system( $dt, "mv", $input, $inputsave ) && logit( "FATAL - cannot move '$input' to '$inputsave'\n$!", 1 );
		$input = $inputsave;
		my $errlog2 = $errlog;
		$errlog2 =~ s/\.ERROR\Q$logsuffix\E$/$profilekey.ERROR$logsuffix/;
		$errlog2 = namer( $errlog2 );
		system( $dt, "mv", $errlog, $errlog2 ) && logit( "FATAL - cannot move '$errlog' to '$errlog2'\n$!", 1 );
		$errlog = $errlog2;
	}
    $finalpdf = mover( $input, $errdir );
}

if ( $conf->{postprocess} ) {
    my $postprocess = $conf->{postprocess};
    $postprocess = "$FindBin::Bin/" . $postprocess unless $postprocess =~ m|^/|;
    if ( -r $postprocess ) {
        my @pcmd = -x $postprocess ? ($postprocess) : ( $conf->{shell} || $^X, $postprocess );
        push( @pcmd, '-f', $finalpdf );
        push( @pcmd, '-c', $copyfile ) if $copyfile;
        push( @pcmd, '-q', $queue ) if $queue;
		push( @pcmd, '-u', $ENV{HELIOS_JOBUSER} || $user ) if $ENV{HELIOS_JOBUSER} || $user;
        $DEBUG && logit("DEBUG - postprocessing call: '@pcmd'\n");

        # make configuration avaible as pdfcorrect_something environment variables
        for my $ckey ( keys %$conf ) {
            if ( ref $conf->{$ckey} eq 'ARRAY' ) { $ENV{ 'pdfcorrect_' . $ckey } = join( ',', @{ $conf->{$ckey} } ) }
            elsif ( ref $conf->{$ckey} eq 'HASH' ) {
                $ENV{ 'pdfcorrect_' . $ckey } = join( ',', each %{ $conf->{$ckey} } );
            }
            else { $ENV{ 'pdfcorrect_' . $ckey } = $conf->{$ckey} }
        }
        system(@pcmd) && logit( "WARNING - exit ", $? << 8, " from '@pcmd'" );
    }
    else { logit("WARNING - postprocessing script '$postprocess' not found") }
}

### end of main ###

END {
    $tmpdir && system( "rm", "-rf", $tmpdir ) && warn "WARNING - cannot remove working dir '$tmpdir'\n$!";

    # additional check, $input is normally already moved
    if ( $input && -r $input ) {
		# restore original file name with possible profile key in filename
		if( $inputsave ne $input ) {
			if( -r $inputsave ) {
				$inputsave = namer( $inputsave );
				logit( "WARNING - original input file '$ARGV[0]' reappeard, using new name '$inputsave'" );
			}
			system( $dt, "mv", $input, $inputsave ) && logit( "FATAL - cannot move '$input' to '$inputsave'", 1 );
		}
        system( $dt, "set", "-a-l", $input ) && warn "WARNING - END block cannot unlock '$input'\n$!";

		# leave original input where it is if copydir = inputdir
		if( ! defined $copydir || (defined $copydir && (realpath( $copydir ) ne dirname( $input ) ) ) ) {
			unless( realpath( $okdir ) eq dirname( $input ) ) {
				mover( $input, $errdir ) if $errdir; # even errdir might not be set if configuration is corrupt
			}
		}
    }

    $infofile
      && -r $infofile
      && system( $dt, "rm", $infofile )
      && warn "WARNING - (end block) cannot remove infofile '$infofile\n";

    if ($conf) {
        $conf->{exit0} ? exit 0 : exit $errorexit;
    }
}

sub getheliosdir {
	confess( "Not a Helios system!? File '/etc/HELIOSInstallPath' doesn't exist!" ) unless -r '/etc/HELIOSInstallPath';
    (
        my $path =
          do { local ( @ARGV, $/ ) = '/etc/HELIOSInstallPath'; <> }
    ) =~ s/\s+$//s;
    return $path;
}

sub settxtcreator {
	my $f = shift || confess "INTERNAL ERROR - missing paramter for settxtcreator()";
	return unless $conf->{txtreportcreator};
	system( $dt, "set", "-c", $conf->{txtreportcreator}, $f ) &&
	  logit( "WARNING - cannot set creator '$conf->{txtreportcreator}' for file '$f'\n$!" );
}

sub profilelookup {
    my $inp = shift;
    my $prof;
    my $pat = $conf->{profileext1};

    # add capturing parens unless already specified
    $pat = '(' . $pat . ')' unless $pat =~ /\([^()]+\)/;
    $pat = $pat . ( $conf->{profileext2} || '(\.pdf)*$' );
    if ( $inp =~ /$pat/i ) {
        my $key = lc $1;
		if( exists $conf->{extlookup}{$key} ) {
			if( $prof = defprofile( $conf->{extlookup}{$key} ) ) {
				if( -f $prof && -r $prof ) {
					return ( $prof, $key );
				}
				else {
					my $log = "FATAL - lookup profile '$prof' not usable";
					logfile( $errlog, logtext( $conf->{errtext} . $log ) );
					logit( $log, 1 );
				}
			}
			else {
				my $log = "FATAL - configured profile '$conf->{extlookup}{$key}' not found by key lookup '$key'";
				logfile( $errlog, logtext( $conf->{errtext} . $log ) );
				logit( $log, 1 )
			}
		}
		else {
			logit( "WARNING - key value '$key' does not exist in lookup table 'extlookup'" );
		}
    }
    else {
        logit("WARNING - '$inp' could not be matched against specified regex '$pat'");
    }
	return ( undef, undef );
}

sub profkeytruncate {
    my $input = shift || confess( "missing parameter to profkeytruncate()" );
    my $key   = shift || confess( "missing parameter to profkeytruncate()" );

    ( my ( $base, $path, $suffix ) ) = fileparse( $input, '\.pdf$' );
    $base && $base =~ s/${key}$//i;
    my $newname = $path . $base . $suffix;
    system( $dt, "mv", $input, $newname ) && logit( "FATAL - move '$input' to '$newname' failed with $!", 1 );

    return $newname;
}

sub nametruncate {
    my $input = shift || die "missing parameter to nametruncate()";
    my $newname = $input;
    for my $suf ( @{ $conf->{suffixremove} } ) {
        if ( $input =~ /${suf}\.pdf$/ ) {
            $newname =~ s/${suf}\.pdf$/.pdf/;
            last;    # only one substitution!
        }
    }

    for my $prefix ( @{ $conf->{prefixremove} } ) {
        my $tmp_basename = basename($newname);
        my $tmp_dirname  = dirname($newname);
        if ( $tmp_basename =~ /^${prefix}/ ) {
            $tmp_basename =~ s/^${prefix}//;
            $newname = $tmp_dirname . "/" . $tmp_basename;
            last;
        }
    }

    unless ( $newname eq $input ) {
        if ( -r $newname ) {
            logit("WARNING - suffix cannot be shortened: '$newname' already exists");
        }
        else {

            # lock is automatically moved too (?)
            system( $dt, "mv", $input, $newname ) && logit( "FATAL - move '$input' to '$newname' failed with $!", 1 );
        }
    }
    return $newname;
}

# defprofile( profilepath )
# search for profile file in standard paths pdfCorrSettings = HELIOSDIR/var/settings/pdfCorrect
# and Profile subdir of pdfCorrect_CLI installation if profilepath argument is not an abolute path
# return: full path to profile if profile is a plain file and readable, undef otherwise

sub defprofile {
	my $prof = shift;
	if ( $prof !~ m|^/| ) {
		if( -f $conf->{heliosdir} . $pdfCorrSettings . '/' . $prof ) {
			$prof = $conf->{heliosdir} . $pdfCorrSettings . '/' . $prof;
		}
		elsif ( -f dirname($pdfcorr) . '/Profiles/'  . $prof ) {
			$prof = dirname($pdfcorr) . '/Profiles/' . $prof;
		}
	}
	return $prof if( -f $prof && -r $prof );
	return undef;
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
		$DEBUG && logit( "DEBUG: findfile() in dir '$dir'" );
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

# return path of hotfolder scripts
# in: absolute path or path relative to Helios base dir
# out: absolute path value of watched directory
# assert: heliosdir must not end with trailing '/'
sub scriptpath {
	my $p = shift || confess( "FATAL: no parameter to scriptpath()" );
	$p = $conf->{heliosdir} . '/' . $p unless $p =~ m|^/|;

	my @scripts = split( /\n/s, `$prefvalue -k Programs/scriptsrv/Config -l` );
	for my $script ( @scripts ) {
		chomp( $script );
		chomp( my $scriptpath = `$prefvalue -k Programs/scriptsrv/Config/\Q$script\E/Script` );
		$scriptpath = $conf->{heliosdir} . '/' . $scriptpath unless $scriptpath =~ m|^/|;
		if( $p eq $scriptpath ) {
			chomp( my $path = `$prefvalue -k Programs/scriptsrv/Config/\Q$script\E/Path` );
			$DEBUG && logit( "DEBUG - scriptpath() found path '$path' for script '$p'" );
			return $path;
		}
	}
	logit( "DEBUG - internal error: path of script '$p' could not be found!" );
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

sub mover {
    my ( $from, $to ) = @_;
    my $target = namer( $to . '/' . basename( $from, '' ) );
    system( $dt, "mv", grep { defined } ( @{ $conf->{dtopts} }, $from, $target ) )
      && logit( "FATAL - cannot move '$from' to '$target'\n$!", 1 );
    return $target;
}

sub copier {
    my ( $from, $to ) = @_;
    my $target = namer( $to . '/' . basename( $from, '' ) );
    system( $dt, "cp", "-p", grep { defined } ( @{ $conf->{dtopts} }, $from, $target ) )
      && logit( "FATAL - cannot move '$from' to '$target'\n$!", 1 );
    return $target;
}

sub namer {
	my $file = shift || confess "no input parameter!";

	# trivial case
	return $file if ! -r $file;

	my $suffix = "";
	my $pattern = join( '|', map{ "\Q$_\E" } ($conf->{infosuffix}, $conf->{convsuffix} . '.pdf', $conf->{txtreportsuffix}, '.ERROR' . $logsuffix, '.pdf') );

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
	# called as hotfolder script
	if( $scriptpath ) {
		# check base path of hotfolder script if input is in a deeper hierarchy
		if( ! $queue && ( $in ne $scriptpath || realpath( $in . '/..' ) ne $scriptpath ) ) {
			# priority for scriptpath conf.pl file
			unshift( @$where, $scriptpath );
		}
	}

    my $conffile = findfile( $where, qr(\.conf.pl$) );
    return unless $conffile;
    logit("INFO - processing extra configuration file '$conffile'");
    my $c = do $conffile;
    die "FATAL: parse error in '$conffile'\n$@" if $@;
    for my $ckey ( keys %$c ) {

        # overwrite/insert into global conf
        $conf->{$ckey} = $c->{$ckey};
    }
}

sub getconf {
    my $cfile = shift || die;

    die "FATAL: '$cfile' not found\n"        unless -r $cfile;
	my $conf = do $cfile;
    die "FATAL: parse error in '$cfile'\n$@" if $@;

    return $conf;
}

sub logtext {
    my $txt = shift || confess( "missing parameter to logtext()" );

    chomp( my $date = `date "+%d.%m.%Y %H:%M:%S"` );

	my $inpdf = basename( $input, '' );

    $txt =~ s/__DATE__/$date/sg;
    $txt =~ s/__FILE__/$inpdf/sg;
    $txt =~ s/__PROFILE__/$profile/sg;
    $txt =~ s/__PID__/$PID/sg;

    return $txt;
}

sub checkcreate {
    my $dir = shift || return;
    unless ( -d $dir ) {
        system( $dt, "mkdir", "-p", "-m", 2777, $dir )
          && logit( "FATAL: cannot create dir '$dir'\n$!", 1 );
    }
}

# creates a new file with text content and places the file safely in a Helios share
sub logfile {
    my ( $file, $str ) = @_;
    logit( "INTERNAL ERROR - no parameters for sub logfile(), \@_ = @_", 1 ) unless $file && $str;
    my $tmplog = $tmpdir . '/' . basename($file);

    open( LOGF, ">" . $tmplog ) || logit( "WARNING: cannot write to temporary logfile '$tmplog'", 1 );
    print LOGF $str;
    close LOGF;

    mover( $tmplog, dirname($file) );
}

sub logit {
    my ( $msg, $exit ) = @_;
    chomp( my $date = `date "+%d.%m.%Y %H:%M:%S"` );
    warn "$date [$$]: $msg\n";
    if ( defined $exit ) {
        $errorexit = $exit;
        exit $exit;
    }
}

sub generateprofile {
	logit( "DEBUG - in generateprofile()" );
	# concatenate file parameters alphabetically
	# assumptions:
	# profiles are in the same directory
	# profiles are not sorted yet
	# return:
	# name of generated profile with full path

	my @profs = sort @_;
	my $dir = dirname( $profs[0] );
	my $cfg = $dir . '/' . $conf->{generatedcfg} . '.cfg';
	my $tmpg = $tmpdir . '/' . 'generated.tmp';
	my $cmd = "cat " . join( " ", map { "\Q$_\E " } @profs ) . " > $tmpg";
	system( $cmd ) and logit( "FATAL - cannot create '$tmpg' with\n$cmd", 1 );
	# compare content of already generated cfg with a new setup
	if( -r $cfg ) {
		system( "/usr/bin/diff -q \Q$tmpg\E \Q$cfg\E >/dev/null 2>&1" );
		if( $? ) {
			system( $dt, "cp", "-p", grep { defined } ( @{ $conf->{dtopts} }, $tmpg, $cfg ) )
			  && logit( "FATAL: cannot copy '$tmpg' to dir '$dir'", 1 );
		}
		else { logit( "INFO - skipping generation of cfg file (identical)" ) }
	}
	else {
		system( $dt, "cp", "-p", grep { defined } ( @{ $conf->{dtopts} }, $tmpg, $cfg ) )
          && logit( "FATAL: cannot copy '$tmpg' to dir '$dir'", 1 );
	}
	return $cfg;
}

sub heladminhelp {

    # support HELIOS Admin with a sample configuration
    my $default_settings = <<'</SETTINGS>';
<SETTINGS>
<General
        Enable="true"
        Hot_Folder="/Volumes/PDF-Correct/IN"
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
        PDF_CORRECT=""
/>
</SETTINGS>
}

__END__

=head1 NAME

	pdfcorrect.pl

=head1 SYNOPSIS

	pdfcheck.pl

	see documentation by executing "perldoc -F pdfcorrect.pl"

=head1 DESCRIPTION


=head1 BUGS/TODOS

=head1 AUTHOR

	Axel Rose

=head1 LICENSE

=head1 VERSION

	$Id: pdfcorrect.pl 194 2006-12-19 11:40:04Z rose $

=cut
