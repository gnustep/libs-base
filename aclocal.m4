# aclocal.m4 - configure macros for libobjects and projects that depend on it.
#
#   Copyright (C) 1995 Free Software Foundation, Inc.
#
#   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
#
#   This file is part of the GNU Objective-C library.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Library General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#   
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Library General Public License for more details.
#
#   You should have received a copy of the GNU Library General Public
#   License along with this library; if not, write to the Free
#   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


AC_DEFUN(OBJC_SYS_AUTOLOAD,
[dnl
#--------------------------------------------------------------------
# Guess if we are using a object file format that supports automatic
# loading of constructor functions, et. al. (e.g. ELF format).
#
# Currently only looks for ELF format. NOTE: Checking for __ELF__ being
# defined doesnt work, since gcc on Solaris does not define this
#
# Makes the following substitutions:
#	Defines SYS_AUTOLOAD
#--------------------------------------------------------------------
AC_CACHE_VAL(objc_cv_sys_autoload,
[AC_CHECK_HEADER(elf.h, [objc_cv_sys_autoload=yes], [objc_cv_sys_autoload=no])
])
if test $objc_cv_sys_autoload = yes; then
  AC_DEFINE(SYS_AUTOLOAD)
fi
])

AC_DEFUN(OBJC_SYS_DYNAMIC_LINKER,
[dnl
#--------------------------------------------------------------------
# Guess the type of dynamic linker for the system
#
# Makes the following substitutions:
#	DYNAMIC_LINKER	- cooresponds to the interface that is included
#		in objc-load.c (i.e. #include "${DYNAMIC_LINKER}-load.h")
#	LIBS		- Updated to include the system library that 
#		performs dynamic linking. 
#--------------------------------------------------------------------
DYNAMIC_LINKER=null
AC_CHECK_LIB(dl, dlopen, [DYNAMIC_LINKER=simple LIBS="${LIBS} -ldl"])

if test $DYNAMIC_LINKER = null; then
    AC_CHECK_LIB(dld, main, [DYNAMIC_LINKER=dld LIBS="${LIBS} -ldld"])
    AC_CHECK_HEADER(dld/defs.h, [objc_found_dld_defs=yes, objc_found_dld_defs=no])
    # Try to distinguish between GNU dld and HPUX dld 
    AC_CHECK_HEADER(dl.h, [DYNAMIC_LINKER=hpux])
    if test $ac_cv_lib_dld = yes && test $objc_found_dld_defs = no && test $ac_cv_header_dl_h = no; then
        AC_MSG_WARN(Could not find dld/defs.h header)
        echo
        echo "Currently, the dld/defs.h header is needed to get information"
        echo "about how to use GNU dld. Some files may not compile without"
        echo "this header."
        echo
    fi
fi
AC_SUBST(DYNAMIC_LINKER)dnl
AC_SUBST(DLD_INCLUDE)dnl
])

AC_DEFUN(OBJC_SYS_DYNAMIC_FLAGS,
[AC_REQUIRE([OBJC_SYS_DYNAMIC_LINKER])dnl
AC_REQUIRE([OBJC_SYS_AUTOLOAD])dnl
#--------------------------------------------------------------------
# Set the flags for compiling dynamically loadable objects
#
# Makes the following substitutions:
#	DYNAMIC_BUNDLER_LINKER - The command to link the object files into
#		a dynamically loadable module.
#	DYNAMIC_LDFLAGS - Flags required when compiling the main program
#		that will do the dynamic linking
#	DYNAMIC_CFLAGS - Flags required when compiling the object files that
#		will be included in the loaded module.
#--------------------------------------------------------------------
if test $DYNAMIC_LINKER = dld; then
    DYNAMIC_BUNDLER_LINKER="ld -r"
    DYNAMIC_LDFLAGS="-static"
    DYNAMIC_CFLAGS=""
elif test $DYNAMIC_LINKER = simple; then
    if test $objc_cv_sys_autoload = yes; then 
      DYNAMIC_BUNDLER_LINKER="$(CC) -Xlinker -r"
    else
      DYNAMIC_BUNDLER_LINKER="$(CC) -nostdlib"
    fi
    DYNAMIC_LDFLAGS=""
    DYNAMIC_CFLAGS="-fPIC"
elif test $DYNAMIC_LINKER = hpux; then
    DYNAMIC_BUNDLER_LINKER="$(CC) -nostdlib -Xlinker -b"
    DYNAMIC_LDFLAGS="-Xlinker -E"
    DYNAMIC_CFLAGS="-fPIC"
elif test $DYNAMIC_LINKER = null; then
    DYNAMIC_BUNDLER_LINKER="$(CC) -nostdlib -Xlinker -r"
    DYNAMIC_LDFLAGS=""
    DYNAMIC_CFLAGS=""
else
    DYNAMIC_BUNDLER_LINKER="$(CC) -nostdlib -Xlinker -r"
    DYNAMIC_LDFLAGS=""
    DYNAMIC_CFLAGS=""
fi
AC_SUBST(DYNAMIC_BUNDLER_LINKER)dnl
AC_SUBST(DYNAMIC_LDFLAGS)dnl
AC_SUBST(DYNAMIC_CFLAGS)dnl
])
