#!/bin/sh
svn log -rPREV --xml --verbose | xsltproc /usr/local/share/svn2cl/svn2cl.xsl - > ChangeLog.new
cat ChangeLog >> ChangeLog.new
mv ChangeLog.new ChangeLog
$EDITOR ChangeLog
svn commit -m 'Added ChangeLog entry from last commit'
