# Changes between version 2007-04-11 and 2008-01-25 #

(from svn log)
```
r22 | axel.roeslein | 2007-12-08
------------------------------------------------------------------------
Fix: scriptpath for checking recursivness was still not ok

r13 | axel.roeslein | 2007-11-29
------------------------------------------------------------------------
bugfixes:
- finding hotfolder specific configuration files ("my.conf.pl") was buggy
  (occured only when using several hotfolders, conf file from another tree
  was used, found by "pk")
- profileext1 works with patterns not immediately preceding ".pdf" suffix
  e.g. profileext1 => '(4c|tz).*'
- profile key lookup more robust (warning "Unitialized values ...")
```