# aclocal.m4 - configure macros for libobjects and projects that depend on it.
#
#   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
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


AC_DEFUN(OBJC_CON_AUTOLOAD,
#--------------------------------------------------------------------
# Guess if we are using a object file format that supports automatic
# loading of constructor functions.
#
# If this system supports autoloading of constructors, that means that gcc
# doesn't have to do it for us via collect2. This routine tests for this
# in a very roundabout way by compiling a program with a constructor and
# testing the file, via nm, for certain symbols that collect2 includes to
# handle loading of constructors.
#
# Makes the following substitutions:
#	Defines CON_AUTOLOAD (whether constructor functions are autoloaded)
#--------------------------------------------------------------------
[dnl
AC_MSG_CHECKING(loading of constructor functions)
AC_CACHE_VAL(objc_cv_con_autoload,
[dnl 
cat > conftest.constructor.c <<EOF
void cons_functions() __attribute__ ((constructor));
void cons_functions() {}
int main()
{
  return 0;
}
EOF
${CC-cc} -o conftest $CFLAGS $CPPFLAGS $LDFLAGS conftest.constructor.$ac_ext $LIBS 1>&5
if test -n "`nm conftest | grep _ctors_aux`"; then 
  objc_cv_con_autoload=yes
else
  objc_cv_con_autoload=no
fi
])
if test $objc_cv_con_autoload = yes; then
  AC_MSG_RESULT(yes)
  AC_DEFINE(CON_AUTOLOAD)
else
  AC_MSG_RESULT(no)
fi
])

AC_DEFUN(OBJC_SYS_DYNAMIC_LINKER,
[dnl
AC_REQUIRE([OBJC_CON_AUTOLOAD])dnl
#--------------------------------------------------------------------
# Guess the type of dynamic linker for the system
#
# Makes the following substitutions:
#	DYNAMIC_LINKER	- cooresponds to the interface that is included
#		in objc-load.c (i.e. #include "${DYNAMIC_LINKER}-load.h")
#--------------------------------------------------------------------
DYNAMIC_LINKER=null
AC_CHECK_HEADER(dlfcn.h, DYNAMIC_LINKER=simple)
if test $DYNAMIC_LINKER = null; then
  AC_CHECK_HEADER(dl.h, DYNAMIC_LINKER=hpux)
fi
if test $DYNAMIC_LINKER = null; then
  AC_CHECK_HEADER(windows.h, DYNAMIC_LINKER=win32)
fi
if test $DYNAMIC_LINKER = null; then
  AC_CHECK_HEADER(dld/defs.h, DYNAMIC_LINKER=dld)
fi

AC_SUBST(DYNAMIC_LINKER)dnl
])

AC_DEFUN(OBJC_SYS_DYNAMIC_FLAGS,
[dnl
AC_REQUIRE([OBJC_CON_AUTOLOAD])dnl
AC_REQUIRE([OBJC_SYS_DYNAMIC_LINKER])dnl
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
    save_LDFLAGS=$LDFLAGS
    LDFLAGS="-shared"
    AC_TRY_LINK([extern void loadf();], loadf();, 
	        objc_shared_linker=yes, objc_shared_linker=no)
    LDFLAGS=$save_LDFLAGS
    if test $objc_shared_linker = yes; then
      DYNAMIC_BUNDLER_LINKER='$(CC) -shared'
    elif test $objc_cv_con_autoload = yes; then 
      DYNAMIC_BUNDLER_LINKER='$(CC) -Xlinker -r'
    else
      DYNAMIC_BUNDLER_LINKER='$(CC) -nostdlib'
    fi
    save_LDFLAGS=$LDFLAGS
    LDFLAGS="-rdynamic"
    AC_TRY_RUN([], objc_dynamic_ldflag="-rdynamic", objc_dynamic_ldflag="",
	objc_dynamic_ldflag="")
    LDFLAGS=$save_LDFLAGS
    DYNAMIC_LDFLAGS="$objc_dynamic_ldflag"
    DYNAMIC_CFLAGS="-fPIC"
elif test $DYNAMIC_LINKER = hpux; then
    DYNAMIC_BUNDLER_LINKER='$(CC) -nostdlib -Xlinker -b'
    DYNAMIC_LDFLAGS="-Xlinker -E"
    DYNAMIC_CFLAGS="-fPIC"
elif test $DYNAMIC_LINKER = null; then
    DYNAMIC_BUNDLER_LINKER='$(CC) -nostdlib -Xlinker -r'
    DYNAMIC_LDFLAGS=""
    DYNAMIC_CFLAGS=""
else
    DYNAMIC_BUNDLER_LINKER='$(CC) -nostdlib -Xlinker -r'
    DYNAMIC_LDFLAGS=""
    DYNAMIC_CFLAGS=""
fi
AC_SUBST(DYNAMIC_BUNDLER_LINKER)dnl
AC_SUBST(DYNAMIC_LDFLAGS)dnl
AC_SUBST(DYNAMIC_CFLAGS)dnl
])
