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
# in a very roundabout way by intentionally trying to link a program that
# will give a link error, and examining the output to see if collect2 gave
# the error (which means the system does not autoload constructors)
# The only problem is this test might incorrectly return yes if it fails
# for some other reason besides a link problem.
#
# Makes the following substitutions:
#	Defines CON_AUTOLOAD (whether constructor functions are autoloaded)
#--------------------------------------------------------------------
[dnl
AC_MSG_CHECKING(loading of constructor functions)
AC_CACHE_VAL(objc_cv_con_autoload,
[dnl 
cat > conftest.constructor.c <<EOF
extern void undefined_function();
int main()
{
  undefined_function();
}
EOF
if test -n "`${CC-cc} -o conftest.constructor conftest.constructor.c 2>&1 | grep collect2`"; then
  objc_cv_con_autoload=no
else
  objc_cv_con_autoload=yes
fi
])
if test $objc_cv_con_autoload = yes; then
  AC_MSG_RESULT(yes)
  AC_DEFINE(CON_AUTOLOAD)
else
  AC_MSG_RESULT(no)
fi
])

AC_DEFUN(OBJC_SYS_AUTOLOAD,
#--------------------------------------------------------------------
# Guess if we are using a object file format that supports automatic
# loading of init functions.
#
# Makes the following substitutions:
#	Defines SYS_AUTOLOAD (whether initializer functions are autoloaded)
#--------------------------------------------------------------------
[AC_MSG_CHECKING(loading of initializer functions)
AC_CACHE_VAL(objc_cv_subinit_worked,
[AC_TRY_RUN([
static char *argv0 = 0;
static char *env0 = 0;
static void args_test (int argc, char *argv[], char *env[])
{
  argv0 = argv[0];
  env0 = env[0];
}
static void * __libobjects_subinit_args__
__attribute__ ((section ("__libc_subinit"))) = &(args_test);
int main(int argc, char *argv[])
{
  if (argv[0] == argv0 && env[0] == env0)
    exit (0);
  exit (1);
}
], objc_cv_subinit_worked=yes, objc_cv_subinit_worked=no, objc_cv_subinit_worked=no)])
if test $objc_cv_subinit_worked = yes; then
  AC_DEFINE(SYS_AUTOLOAD)
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
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
AC_CHECK_HEADER(dlfcn.h, DYNAMIC_LINKER=simple)
if test $DYNAMIC_LINKER = null; then
  AC_CHECK_HEADER(dl.h, DYNAMIC_LINKER=hpux)
fi
if test $DYNAMIC_LINKER = null; then
  AC_CHECK_HEADER(dld/defs.h, DYNAMIC_LINKER=dld)
fi
# Should only include one of the following libs.
AC_CHECK_LIB(dl, dlopen, LIBS="${LIBS} -ldl")
AC_CHECK_LIB(dld, main, LIBS="${LIBS} -ldld")

AC_SUBST(DYNAMIC_LINKER)dnl
])

AC_DEFUN(OBJC_SYS_DYNAMIC_FLAGS,
[dnl
AC_REQUIRE([OBJC_CON_AUTOLOAD])dnl
AC_REQUIRE([OBJC_SYS_AUTOLOAD])dnl
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
    DYNAMIC_LDFLAGS=""
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
