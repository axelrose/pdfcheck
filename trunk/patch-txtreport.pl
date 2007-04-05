#!/usr/bin/perl -i -p

# $Id: patch-txtreport.pl 92 2006-08-10 14:31:39Z rose $

s/^=+$/'=' x 60/seg;
s/^Pfad:.+$//s;
