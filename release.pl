#!/usr/bin/perl -w
use strict;

my $svn = "https://pdfcheck.googlecode.com/svn/trunk";
chomp(my $date = `date +%Y-%m-%d`);
chomp(my $pwd =`pwd`);

my $proj = shift || die "usage: $0 <pdfcheck|pdfcolconv|pdfcorrect\n";
die "proj must be pdfcheck|pdfcolconv|pdfcorrect" unless $proj =~ /^(pdfcheck|pdfcolconv|pdfcorrect)/;
chdir($proj) || die $!;

system("rm", "-rf", "build") && die $!;
system("mkdir", "build") && die $!;
die "no 'build' dir!\n" if (!(-r "build" && -d "build"));
chdir("build")  || die $!;

system("svn", "export", $svn . "/$proj") and die $!;

my $tar = "$proj-$date.tgz";
my $zip = "$proj-$date.zip";

system("tar", "-cvzf", $tar, $proj) && die $!;
system("zip", "-r", $zip, $proj) && die $!;

chdir $pwd;
system "ls -l $proj/build/$tar $proj/build/$zip";

print "done.\n";
