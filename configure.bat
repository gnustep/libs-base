@echo off
rem
rem  configure.bat
rem  Configuration program for GNUstep Base Library
rem  on WIN32 operating systems using Microsoft tools.
rem 
rem  Copyright (C) 1996 Free Software Foundation, Inc.
rem
rem  Written by: Scott Christley <scottc@net-community.com>
rem
rem  This file is part of the GNUstep Base Library.
rem
rem  This library is free software; you can redistribute it and/or
rem  modify it under the terms of the GNU Library General Public
rem  License as published by the Free Software Foundation; either
rem  version 2 of the License, or (at your option) any later version.
rem
rem  This library is distributed in the hope that it will be useful,
rem  but WITHOUT ANY WARRANTY; without even the implied warranty of
rem  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
rem  Library General Public License for more details.
rem
rem  You should have received a copy of the GNU Library General Public
rem  License along with this library; if not, write to the Free
rem  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA
rem

rem
rem Top level makefile
rem
echo "Top level makefile"
sed -f Makefile.sed.nt Makefile.in >Makefile

rem
rem src makefile
rem
echo "Src makefile"
cd src
sed -f Makefile.sed.nt Makefile.in >Makefile
touch 0
touch 1
touch 2
touch 3
touch 4
touch 5
touch 6
touch 7
touch 8
touch 9
touch 10
touch 11
touch 12
echo "include subdirectory"
cd include
rm -f config.h
cat config.h.in >config.h
cat config-win32.h >>config.h
cd ..
cd ..

rem
rem checks makefile
rem
echo "Checks makefile"
cd checks
sed -f Makefile.sed.nt Makefile.in >Makefile
cd ..

