# configure.ac for GNU Objective-C library
# Process this file with autoconf to produce a configure script.
#
#   Copyright (C) 1993,1994, 1995, 1996, 1997 Free Software Foundation, Inc.
#
#   Written by:  Andrew Kachites McCallum <mccallum@cs.rochester.edu>
#   Dept. of Computer Science, U. of Rochester, Rochester, NY  14627
#
#   This file is part of the GNU Objective-C library.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#   
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this library; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA
builtin(include, config/objc-con-autoload.m4)dnl
builtin(include, config/objc-sys-dynamic.m4)dnl
builtin(include, config/procfs-exe-link.m4)dnl
builtin(include, config/procfs.m4)dnl
builtin(include, config/pathxml.m4)dnl
builtin(include, config/codeset.m4)dnl

AC_INIT
AC_CONFIG_SRCDIR([Source/NSArray.m])

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must have the gnustep-make package installed and set up the GNUSTEP_MAKEFILES environment variable to contain the path to the makefiles directory before configuring!])
fi

#---------------------------------------------------------------------
# Location of the GNUstep.conf config file (--with-config-file)
#---------------------------------------------------------------------
AC_MSG_CHECKING([for GNUstep configuration file to use])
AC_ARG_WITH(config-file,
[  --with-config-file=PATH       Specify path to the GNUstep config file.
				If unspecified, uses the same value as the
				GNUstep make package.
				If a leading './' is specified, the path
				is taken to be relative to the base library
				linked runtime, not all operating systems
				can support this, so on some platforms you
				may need --enable-environment-config-file.
				If a trailing '/' is specified, the path is
				used for locating domains but no GNUstep
				config file is read at runtime.], 
  GNUSTEP_CONFIG_FILE="$withval",
  [if test "$GNUSTEP_CONFIG_FILE" = ""; then
    GNUSTEP_CONFIG_FILE=`grep '^GNUSTEP_CONFIG_FILE *=' $GNUSTEP_MAKEFILES/config.make | sed -e 's/GNUSTEP_CONFIG_FILE *= *\(.*\)/\1/'`
  fi])
AC_MSG_RESULT($GNUSTEP_CONFIG_FILE)
AC_SUBST(GNUSTEP_CONFIG_FILE)

#-----------------------------------------------------------------
# Whether the GNUstep.conf file path can be set in the environment
#-----------------------------------------------------------------
AC_MSG_CHECKING([whether the GNUstep.conf file path can be set in the environment])
AC_ARG_ENABLE(environment-config-file, 
[  --enable-environment-config-file
                                Enable use of the GNUSTEP_CONFIG_FILE
				environment variable to specify/override
				the location of the GNUstep config file
				at runtime.  This option is occasionally
				useful for development/debugging or for
				providing a relocatable distribution package
				for platforms where the path to the base
				library can't be determined at runtime
				and the leading './' in the config file name
				is therefore not supported.], 
  ac_cv_environment_config_file=$enableval,
  ac_cv_environment_config_file="no")
if test "$ac_cv_environment_config_file" = "yes"; then
  AC_DEFINE(OPTION_NO_ENVIRONMENT, 0,
    [Enable GNUSTEP_CONFIG_FILE environment variable])
  AC_MSG_RESULT([yes])
else
  AC_DEFINE(OPTION_NO_ENVIRONMENT, 1,
    [Disable GNUSTEP_CONFIG_FILE environment variable])
  AC_MSG_RESULT([no: disabled from the command-line])
fi

#
# Set 'standard' defaults for values from configuration file.
#
case "$target_os" in
    mingw*)
      GNUSTEP_SYSTEM_ROOT=C:\\GNUstep\\System
      GNUSTEP_LOCAL_ROOT=C:\\GNUstep\\Local
      GNUSTEP_NETWORK_ROOT=C:\\GNUstep\\Local
      GNUSTEP_USER_DIR=GNUstep
      GNUSTEP_USER_DEFAULTS_DIR=GNUstep\\Defaults
      GNUSTEP_USER_CONFIG_FILE=.GNUstep.conf
      ;;
    *)
      GNUSTEP_SYSTEM_ROOT=/usr/GNUstep/System
      GNUSTEP_LOCAL_ROOT=/usr/GNUstep/Local
      GNUSTEP_NETWORK_ROOT=/usr/GNUstep/Local
      GNUSTEP_USER_DIR=GNUstep
      GNUSTEP_USER_DEFAULTS_DIR=GNUstep/Defaults
      GNUSTEP_USER_CONFIG_FILE=.GNUstep.conf
      ;;
esac

#---------------------------------------------------------------------
# Now read/import the existing configuration file, if any
#---------------------------------------------------------------------

# Reading/importing an existing configuration file is good as it means
# the built-in default paths in the code will match those of your
# installation (or of the config file you specify).
# It can be annoying in certain cases though; this option lets you
# turn it off
AC_MSG_CHECKING([if we should import an existing configuration file])
AC_ARG_ENABLE(importing-config-file, 
[  --disable-importing-config-file
                                Disable importing of an existing GNUstep config
				file and use inbuilt defaults instead.],
  ac_cv_importing_config_file=$enableval,
  ac_cv_importing_config_file="yes")
if test "$ac_cv_importing_config_file" = "no"; then
  AC_MSG_RESULT([no: disabled from the command-line])
else
  AC_MSG_RESULT([yes])
fi


if test "$ac_cv_importing_config_file" = "yes" ;
then
  AC_MSG_CHECKING([for default GNUstep configuration file to use])
  AC_ARG_WITH(default-config,
[  --with-defaults-config=PATH   Specify path to a GNUstep config file to be
				imported at configure time (now) and used to
				provide default values for the base library
				to use at runtime if no GNUstep config file
				is found at runtime.  If this is not specified
				then the path from --with-config-file is used.],
    GNUSTEP_DEFAULT_CONFIG="$withval", 
    [if test "$GNUSTEP_DEFAULT_CONFIG" = ""; then
      GNUSTEP_DEFAULT_CONFIG="$GNUSTEP_CONFIG_FILE"
    fi])
  AC_MSG_RESULT($GNUSTEP_DEFAULT_CONFIG)

  #
  # Use the default config file to override standard values.
  #
  if test ! -f "$GNUSTEP_DEFAULT_CONFIG"; then
    AC_MSG_RESULT([fail: file "$GNUSTEP_DEFAULT_CONFIG" does not exist])
    AC_MSG_NOTICE([Please run configure again with the --disable-importing-config-file option or specifying an alternative file using the --with-default-config= option])
  else
    AC_MSG_RESULT([trying to import "$GNUSTEP_DEFAULT_CONFIG"])
    AC_MSG_NOTICE([If this fails, please run configure again with the --disable-importing-config-file option or specifying an alternative file using the --with-default-config= option])
    . "$GNUSTEP_DEFAULT_CONFIG"
  fi
fi

#
# Add standard library and header directories for configure to use to locate
# plain C developer headers/libraries which haver been installed in the
# GNUstep hierarchy.
#
CPPFLAGS="$CPPFLAGS -I$GNUSTEP_SYSTEM_ROOT/Library/Headers"
LDFLAGS="$LDFLAGS -L$GNUSTEP_SYSTEM_ROOT/Library/Libraries"

#
# Set the default configuration file values in config.h to be hard-coded
# into NSPathUtilities.m
#
GNUSTEP_SYSTEM_ROOT=`echo $GNUSTEP_SYSTEM_ROOT|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_ROOT,
  "$GNUSTEP_SYSTEM_ROOT",
  [Built in default value for GNUstep system root])
GNUSTEP_NETWORK_ROOT=`echo $GNUSTEP_NETWORK_ROOT|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_ROOT,
  "$GNUSTEP_NETWORK_ROOT",
  [Built in default value for GNUstep network root])
GNUSTEP_LOCAL_ROOT=`echo $GNUSTEP_LOCAL_ROOT|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_ROOT,
  "$GNUSTEP_LOCAL_ROOT",
  [Built in default value for GNUstep local root])
GNUSTEP_USER_DIR=`echo $GNUSTEP_USER_DIR|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR,
  "$GNUSTEP_USER_DIR",
  [Built in default value for GNUstep user directory])
GNUSTEP_USER_DEFAULTS_DIR=`echo $GNUSTEP_USER_DEFAULTS_DIR|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DEFAULTS_DIR,
  "$GNUSTEP_USER_DEFAULTS_DIR",
  [Built in default value for GNUstep user defaults directory])
GNUSTEP_USER_CONFIG_FILE=`echo $GNUSTEP_USER_CONFIG_FILE|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_CONFIG_FILE,
  "$GNUSTEP_USER_CONFIG_FILE",
  [Built in default value for GNUstep user config file])


#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR($GNUSTEP_MAKEFILES)

#--------------------------------------------------------------------
# Use a .h file with #define's, instead of -D command-line switches
#--------------------------------------------------------------------
AC_CONFIG_HEADER(Headers/Additions/GNUstepBase/config.h)

#--------------------------------------------------------------------
# Determine the host, build, and target systems
#--------------------------------------------------------------------
AC_CANONICAL_TARGET([])

#--------------------------------------------------------------------
# Find the compiler
#--------------------------------------------------------------------
AC_PROG_CC
AC_PROG_CPP

AC_PATH_PROG(WHOAMI, whoami, echo, $PATH:/usr/ucb)

#--------------------------------------------------------------------
# specific target_os options
#--------------------------------------------------------------------
INCLUDE_FLAGS="$CPPFLAGS"
LDIR_FLAGS="$LDFLAGS"
# This is just for configuring. Later, in config.make, INCLUDE_FLAGS
# goes in CONFIG_SYSTEM_INCL and LIBS goes in CONFIG_SYSTEM_LIBS
case "$target_os" in
  freebsd* | openbsd* )	
	        CPPFLAGS="$CPPFLAGS -I/usr/local/include"
		LDFLAGS="$LDFLAGS -L/usr/local/lib";;
  netbsd*)	CPPFLAGS="$CPPFLAGS -I/usr/pkg/include"
		LDFLAGS="$LDFLAGS -Wl,-R/usr/pkg/lib -L/usr/pkg/lib";;
esac

#----------------------------------------------------------------
# Find out if nested functions work on this machine
#----------------------------------------------------------------
AC_MSG_CHECKING(whether nested functions work)
AC_TRY_RUN([#include "$srcdir/config/config.nested.c"],
    gcc_nested=1, gcc_nested=0, gcc_nested=1)
if test $gcc_nested = 0; then
  AC_MSG_RESULT(no)
  AC_DEFINE(BROKEN_NESTED_FUNCTIONS,1,
            [Define if nested functions are broken on this compiler])
else
  AC_MSG_RESULT(yes)
fi

#--------------------------------------------------------------------
# Set Apple/Darwin/OSX/NeXT information for other tests
#--------------------------------------------------------------------
OBJC_RUNTIME_LIB=`echo $LIBRARY_COMBO | tr '-' ' ' | awk '{print $1}'`
AC_MSG_CHECKING(the Objective-C runtime)
if test "$OBJC_RUNTIME_LIB" = "nx" -o "$OBJC_RUNTIME_LIB" = "apple"; then
  AC_MSG_RESULT(NeXT)
  LIBOBJC='-lobjc'
  OBJCFLAGS="-fnext-runtime -DNeXT_RUNTIME"
else
  AC_MSG_RESULT(GNU)
  LIBOBJC='-lobjc'
  OBJCFLAGS="-fgnu-runtime"
fi

#--------------------------------------------------------------------
# Miscellaneous flags
#--------------------------------------------------------------------
# Set location of GNUstep dirs for later use
if test "$GNUSTEP_FLATTENED" = yes; then
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_ROOT/Library/Libraries
  GNUSTEP_HDIR=$GNUSTEP_SYSTEM_ROOT/Library/Headers
else
  clean_target_os=`$GNUSTEP_MAKEFILES/clean_os.sh $target_os`
  clean_target_cpu=`$GNUSTEP_MAKEFILES/clean_cpu.sh $target_cpu`
  obj_dir=$clean_target_cpu/$clean_target_os
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_ROOT/Library/Libraries/$obj_dir
  GNUSTEP_HDIR=$GNUSTEP_SYSTEM_ROOT/Library/Headers/$LIBRARY_COMBO
fi

#
# The following one is so that headers of custom libraries into
# $GNUSTEP_HDIR are used before the standard ones
#
INCLUDE_FLAGS="$INCLUDE_FLAGS -I$GNUSTEP_HDIR"
LDIR_FLAGS="$LDIR_FLAGS -L$GNUSTEP_LDIR/$LIBRARY_COMBO -L$GNUSTEP_LDIR"

#--------------------------------------------------------------------
# Check if Objective-C is installed
#--------------------------------------------------------------------
AC_CHECK_HEADERS(objc/objc.h)
if test $ac_cv_header_objc_objc_h = no; then
  echo "Check to make sure you have a full installation of the GCC"
  echo "compiler that includes the Objective-C headers and libraries"
  AC_MSG_ERROR(Could not find Objective-C headers)
fi

#--------------------------------------------------------------------
# Check for strange network stuff used by gdomap
#--------------------------------------------------------------------
AC_MSG_NOTICE(for gdomap network details)
AC_MSG_CHECKING(for variable length socket addresses)
AC_TRY_COMPILE([
  #include <sys/types.h>
  #include <sys/socket.h>
  #include <net/if.h>
  ],
  [struct ifreq s; s.ifr_addr.sa_len = 0;],
  sa_len=1, sa_len=0)
if test $sa_len = 1; then
  AC_MSG_RESULT([found])
  AC_DEFINE(HAVE_SA_LEN,1,
            [Define if your system has variable length network addresses])
else
  AC_MSG_RESULT([not found])
fi

#--------------------------------------------------------------------
# Check if system has buggy SO_REUSEADDR
#--------------------------------------------------------------------
AC_MSG_CHECKING(whether SO_REUSEADDR is broken)
AC_TRY_RUN([#include "$srcdir/config/config.reuseaddr.c"],
	reuseaddr_ok=1,
	reuseaddr_ok=0,
	reuseaddr_ok=0)
if test $reuseaddr_ok = 0; then
  AC_DEFINE(BROKEN_SO_REUSEADDR,1,
            [Define if SO_REUSEADDR is broken on this system])
  echo
  echo "The SO_REUSEADDR socket option for controlling re-use of network"
  echo "sockets immediately after shutdown appears to be broken on this"
  echo "machine.  Networking code will be built without using this"
  echo "feature."
  echo "The effect of this lack is that when a network service is shut"
  echo "down, it cannot be re-started on the same network port until"
  echo "an operating-system timeout has expired."
  echo "For servers other than gdomap, GNUstep does not normally need"
  echo "a particular network port, so the problem is unlikely to arise."
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
fi

#--------------------------------------------------------------------
# Check for thread flags for libobjc.
#--------------------------------------------------------------------
#
AC_MSG_CHECKING(for objc threading flags)
#
# Get them from gnustep-make which contains the real code to get them
#
objc_threaded=`grep objc_threaded: $GNUSTEP_MAKEFILES/$obj_dir/config.make | sed -e 's/objc_threaded:=//'`
#
AC_MSG_RESULT($objc_threaded)

#--------------------------------------------------------------------
# Byte order information needed for foundation headers.
#--------------------------------------------------------------------
AC_C_BIGENDIAN
if test $ac_cv_c_bigendian = yes; then
  GS_WORDS_BIGENDIAN=1
else
  GS_WORDS_BIGENDIAN=0
fi
AC_SUBST(GS_WORDS_BIGENDIAN)

#--------------------------------------------------------------------
# Type size information needed for foundation headers.
#--------------------------------------------------------------------
AC_CHECK_SIZEOF(void*)

GS_SINT8="signed char"
GS_UINT8="unsigned char"
AC_SUBST(GS_SINT8)
AC_SUBST(GS_UINT8)

AC_CHECK_SIZEOF(short)
AC_SUBST(ac_cv_sizeof_short)

AC_CHECK_SIZEOF(int)
AC_SUBST(ac_cv_sizeof_int)

AC_CHECK_SIZEOF(long)
AC_SUBST(ac_cv_sizeof_long)

AC_CHECK_SIZEOF(long long)
AC_SUBST(ac_cv_sizeof_long_long)

AC_CHECK_SIZEOF(float)
AC_SUBST(ac_cv_sizeof_float)

AC_CHECK_SIZEOF(double)
AC_SUBST(ac_cv_sizeof_double)

AC_SUBST(ac_cv_sizeof_voidp)
if test $ac_cv_sizeof_voidp = $ac_cv_sizeof_int; then
  GS_ADDR="unsigned int"
else
  if test $ac_cv_sizeof_voidp = $ac_cv_sizeof_long; then
    GS_ADDR="unsigned long"
  else
    if test $ac_cv_sizeof_voidp = $ac_cv_sizeof_long_long; then
      GS_ADDR="unsigned long long"
    else
      AC_MSG_ERROR([Unable to find integer of same size as void*])
    fi
  fi
fi
AC_SUBST(GS_ADDR)

if test $ac_cv_sizeof_short = 2; then
  GS_SINT16="signed short"
  GS_UINT16="unsigned short"
else
  if test $ac_cv_sizeof_int = 2; then
    GS_SINT16="signed int"
    GS_UINT16="unsigned int"
  else
    AC_MSG_ERROR([Unable to determine type for 16-bit integer])
  fi
fi
AC_SUBST(GS_SINT16)
AC_SUBST(GS_UINT16)

if test $ac_cv_sizeof_int = 4; then
  GS_SINT32="signed int"
  GS_UINT32="unsigned int"
else
  if test $ac_cv_sizeof_long = 4; then
    GS_SINT32="signed long"
    GS_UINT32="unsigned long"
  else
    if test $ac_cv_sizeof_short = 4; then
      GS_SINT32="signed short"
      GS_UINT32="unsigned short"
    else
      AC_MSG_ERROR([Unable to determine type for 32-bit integer])
    fi
  fi
fi
AC_SUBST(GS_SINT32)
AC_SUBST(GS_UINT32)

GS_HAVE_I64=1
if test $ac_cv_sizeof_int = 8; then
  GS_SINT64="signed int"
  GS_UINT64="unsigned int"
else
  if test $ac_cv_sizeof_long = 8; then
    GS_SINT64="signed long"
    GS_UINT64="unsigned long"
  else
    if test $ac_cv_sizeof_long_long = 8; then
      GS_SINT64="signed long long"
      GS_UINT64="unsigned long long"
    else
#     64-bit ints not supported - but we need a dummy type for byte-swapping
#     of 64-bit values arriving from another system.
      GS_SINT64="struct { gsu8 a[8]; }"
      GS_UINT64="struct { gsu8 a[8]; }"
      GS_HAVE_I64=0
    fi
  fi
fi
AC_SUBST(GS_SINT64)
AC_SUBST(GS_UINT64)
AC_SUBST(GS_HAVE_I64)

GS_HAVE_I128=1
if test $ac_cv_sizeof_long = 16; then
  GS_SINT128="signed long"
  GS_UINT128="unsigned long"
else
  if test $ac_cv_sizeof_long_long = 16; then
    GS_SINT128="signed long long"
    GS_UINT128="unsigned long long"
  else
#     128-bit ints not supported - but we need a dummy type for byte-swapping
#     of 128-bit values arriving from another system.
    GS_SINT128="struct { gsu8 a[16]; }"
    GS_UINT128="struct { gsu8 a[16]; }"
    GS_HAVE_I128=0
  fi
fi
AC_SUBST(GS_SINT128)
AC_SUBST(GS_UINT128)
AC_SUBST(GS_HAVE_I128)

if test $ac_cv_sizeof_float = 4; then
  GS_FLT32="float"
else
  AC_MSG_ERROR([Unable to determine type for 32-bit float])
fi
AC_SUBST(GS_FLT32)

if test $ac_cv_sizeof_double = 8; then
  GS_FLT64="double"
else
  AC_MSG_ERROR([Unable to determine type for 64-bit float])
fi
AC_SUBST(GS_FLT64)

#--------------------------------------------------------------------
# Type-size information for encoding into archives using NSArchiver etc.
#--------------------------------------------------------------------
if test $ac_cv_sizeof_short = 2; then
  _GSC_S_SHT=_GSC_I16
else
  _GSC_S_SHT=_GSC_I32
fi
AC_SUBST(_GSC_S_SHT)

if test $ac_cv_sizeof_int = 2; then
  _GSC_S_INT=_GSC_I16
else
  if test $ac_cv_sizeof_int = 4; then
    _GSC_S_INT=_GSC_I32
  else
    if test $ac_cv_sizeof_int = 8; then
      _GSC_S_INT=_GSC_I64
    else
      if test $ac_cv_sizeof_int = 16; then
	_GSC_S_INT=_GSC_I128
      fi
    fi
  fi
fi
AC_SUBST(_GSC_S_INT)

if test $ac_cv_sizeof_long = 4; then
  _GSC_S_LNG=_GSC_I32
else
  if test $ac_cv_sizeof_long = 8; then
    _GSC_S_LNG=_GSC_I64
  else
    if test $ac_cv_sizeof_long = 16; then
      _GSC_S_LNG=_GSC_I128
    fi
  fi
fi
AC_SUBST(_GSC_S_LNG)

if test $ac_cv_sizeof_long_long = 4; then
  _GSC_S_LNG_LNG=_GSC_I32
else
  if test $ac_cv_sizeof_long_long = 8; then
    _GSC_S_LNG_LNG=_GSC_I64
  else
    if test $ac_cv_sizeof_long_long = 16; then
      _GSC_S_LNG_LNG=_GSC_I128
    fi
  fi
fi
AC_SUBST(_GSC_S_LNG_LNG)

#--------------------------------------------------------------------
# Setup dynamic linking 
#--------------------------------------------------------------------
OBJC_SYS_DYNAMIC_LINKER()
if test x"$ac_cv_lib_dl_dladdr" = xyes; then
  AC_DEFINE([HAVE_DLADDR], 1,
            [Define if you have the dladdr function in the dl library])
fi

#--------------------------------------------------------------------
# Check whether Objective-C /really/ works
#--------------------------------------------------------------------
AC_MSG_CHECKING(whether objc really works)
saved_LIBS="$LIBS"
saved_CPPFLAGS="$CPPFLAGS"
LIBS="$LIBS $LIBOBJC"
CPPFLAGS="$CPPFLAGS $OBJCFLAGS -x objective-c"
if test x"$objc_threaded" != x""; then
  LIBS="$LIBS $objc_threaded"
fi
LIBS="$LIBS $extra_LIBS"
AC_CACHE_VAL(objc_works,
  AC_TRY_RUN([#include "$srcdir/config/config.objc.m"],
  objc_works=yes, 
  objc_works=no, 
  objc_works=yes)
)
if test $objc_works = yes; then
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
  echo "I don't seem to be able to use your Objective-C compiler to produce"
  echo "working binaries!  Please check your Objective-C compiler installation."
  echo "If you are using gcc-3.x make sure that your compiler's libgcc_s and libobjc"
  echo "can be found by the dynamic linker - usually that requires you to play"
  echo "with LD_LIBRARY_PATH or /etc/ld.so.conf."
  echo "Please refer to your compiler installation instructions for more help."
  AC_MSG_ERROR(The Objective-C compiler does not work or is not installed properly.)
fi

# Don't revert any Objective-C flags as they are used in the next test

#---------------------------------------------------------------------
# Guess if we are using a compiler which allows us to change the class
# to be used for constant strings by using the -fconstant-string-class
# option.  If that is the case, we change it to NSConstantString.
#---------------------------------------------------------------------
strclass_CPPFLAGS="$CPPFLAGS"
CPPFLAGS="$CPPFLAGS -fconstant-string-class=FooConstantString"
AC_MSG_CHECKING(if the compiler supports -fconstant-string-class)
AC_CACHE_VAL(objc_compiler_supports_constant_string_class,
  AC_TRY_RUN([#include "$srcdir/config/config.constant-string-class.m"],
  objc_compiler_supports_constant_string_class=yes,
  objc_compiler_supports_constant_string_class=no,
  objc_compiler_supports_constant_string_class=no)
)
if test $objc_compiler_supports_constant_string_class = yes; then
  NX_CONST_STRING_OBJCFLAGS="-fconstant-string-class=NSConstantString"
  NX_CONST_STRING_CLASS=NSConstantString
  AC_MSG_RESULT(yes)
else
  NX_CONST_STRING_OBJCFLAGS=""
  NX_CONST_STRING_CLASS=NXConstantString
  AC_MSG_RESULT(no)
fi
CPPFLAGS="$strclass_CPPFLAGS"

AC_SUBST(NX_CONST_STRING_OBJCFLAGS)
AC_SUBST(NX_CONST_STRING_CLASS)

# Don't revert any Objective-C flags as they are used in the next test

#---------------------------------------------------------------------
# Guess if we are using a compiler which has the (GNU extension) +load 
# method which is executed before main.  
# Defines HAVE_LOAD_METHOD if +load methods are called before main.
# Needed by NSProcessInfo.m
#---------------------------------------------------------------------
AC_MSG_CHECKING(if +load method is executed before main)
AC_CACHE_VAL(objc_load_method_worked,
  AC_TRY_RUN([#include "$srcdir/config/config.loadtest.m"],
	objc_load_method_worked=yes,
	objc_load_method_worked=no,
	objc_load_method_worked=no)
)
if test $objc_load_method_worked = yes; then
  AC_DEFINE(HAVE_LOAD_METHOD,1,
            [Define if your Obj-C compiler calls +load methods before main])
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
fi

# Don't revert any Objective-C flags as they are used in the next test

#--------------------------------------------------------------------
# This function needed by NSLock.m for conditioned wait
# get_uninstalled_dtable used by behavior.m and objc-load.m
# Thread functions used by NSThread
#--------------------------------------------------------------------
AC_CHECK_FUNCS(objc_condition_timedwait objc_thread_add)

AC_EGREP_HEADER(objc_get_uninstalled_dtable, objc/objc-api.h, 
	AC_DEFINE(HAVE_OBJC_GET_UNINSTALLED_DTABLE,1,
                  [ Define if objc-api.h defines this function]),)

LIBS="$saved_LIBS"
CPPFLAGS="$saved_CPPFLAGS"

#--------------------------------------------------------------------
# Generic settings needed by NSZone.m
#--------------------------------------------------------------------
AC_TYPE_SIZE_T
AC_C_INLINE

#--------------------------------------------------------------------
# Following header checks needed for bzero in Storage.m and other places
#--------------------------------------------------------------------
AC_HEADER_STDC
AC_CHECK_HEADERS(string.h memory.h)

#--------------------------------------------------------------------
# Following header check needed NSConnection.h
#--------------------------------------------------------------------
AC_CHECK_HEADERS(float.h)

#--------------------------------------------------------------------
# Header files and functions for files and filesystems
#--------------------------------------------------------------------
AC_CHECK_HEADERS(sys/stat.h sys/vfs.h sys/statfs.h sys/statvfs.h pwd.h grp.h)
AC_CHECK_HEADERS(sys/syslimits.h sys/param.h)
# Twisted header check for NetBSD
AC_CHECK_HEADERS([sys/mount.h], [], [],
  [#if HAVE_SYS_SYSLIMITS_H
   #include <sys/syslimits.h>
   #endif
   #if HAVE_SYS_PARAM_H
   #include <sys/param.h>
   #endif
  ])
AC_CHECK_HEADERS(sys/types.h windows.h locale.h langinfo.h)
saved_LIBS="$LIBS"
AC_CHECK_LIB(m, main)
AC_CHECK_FUNCS(statvfs link symlink readlink geteuid getlogin getpwnam getpwuid getgrgid rint getopt)
LIBS="$saved_LIBS"

#--------------------------------------------------------------------
# These two headers (functions) needed by Time.m
#--------------------------------------------------------------------
dnl AC_REPLACE_FUNCS(getrusage gettimeofday)

AC_CHECK_HEADERS(time.h sys/time.h tzfile.h sys/rusage.h ucbinclude/sys/resource.h)
AC_CHECK_FUNCS(time ctime tzset)

# Check if tzfile contains the proper definitions
if test $ac_cv_header_tzfile_h = yes; then
  AC_EGREP_HEADER(tzhead, tzfile.h, 
	AC_DEFINE(HAVE_TZHEAD,1,
                  [ Define if tzfile.h includes the proper definitions]),)
fi

#--------------------------------------------------------------------
# These headers/functions needed by GSTcpPort.m
#--------------------------------------------------------------------
AC_CHECK_HEADERS(sys/socket.h netinet/in.h)
dnl AC_REPLACE_FUNCS(recvfrom)

#--------------------------------------------------------------------
# These headers/functions needed by NSLog.m
#--------------------------------------------------------------------
AC_CHECK_HEADERS(syslog.h)
AC_CHECK_FUNCS(syslog)

#--------------------------------------------------------------------
# These headers/functions needed by NSRunLoop.m
#--------------------------------------------------------------------
AC_CHECK_HEADERS(poll.h)
AC_CHECK_FUNCS(poll)
have_poll=no
if test $ac_cv_header_poll_h = yes; then
  have_poll=yes
  AC_MSG_CHECKING(for poll emulation)
  AC_EGREP_CPP(emulating_poll, [#include "config/config.poll.c"], 
  	have_poll=no,)
  if test $have_poll = yes; then
    AC_MSG_RESULT(no)
    AC_DEFINE(HAVE_POLL_F,1, [ Define if poll is NOT emulated via select])
  else
    AC_MSG_RESULT(yes)
  fi
fi

#--------------------------------------------------------------------
# Check for pthread.h (only when building on Darwin machines)
#--------------------------------------------------------------------
AC_CHECK_HEADERS(pthread.h)
HAVE_PTHREAD_H=no
if test $ac_cv_header_pthread_h = yes ; then
  HAVE_PTHREAD_H=yes
fi
AC_SUBST(HAVE_PTHREAD_H)

#--------------------------------------------------------------------
# This function needed by StdioStream.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(vsprintf vasprintf)
if test $ac_cv_func_vsprintf = yes ; then
    AC_TRY_RUN([#include "$srcdir/config/config.vsprintf.c"],
		VSPRINTF_RETURNS_LENGTH=1,
		VSPRINTF_RETURNS_LENGTH=0,
		VSPRINTF_RETURNS_LENGTH=1)
    AC_DEFINE_UNQUOTED(VSPRINTF_RETURNS_LENGTH, $VSPRINTF_RETURNS_LENGTH,
                       [Define if vsprintf returns the length printed])
fi
if test $ac_cv_func_vasprintf = yes ; then
    AC_TRY_RUN([#include "$srcdir/config/config.vasprintf.c"],
		VASPRINTF_RETURNS_LENGTH=1,
		VASPRINTF_RETURNS_LENGTH=0,
		VASPRINTF_RETURNS_LENGTH=1)
    AC_DEFINE_UNQUOTED(VASPRINTF_RETURNS_LENGTH, $VASPRINTF_RETURNS_LENGTH,
                       [Define if vasprintf returns the length printed])
fi

#--------------------------------------------------------------------
# This function needed by NSFileManager.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(getcwd)
AC_HEADER_DIRENT

#--------------------------------------------------------------------
# This function needed by gdomap.c
#--------------------------------------------------------------------
AC_CHECK_HEADERS(getopt.h)

#--------------------------------------------------------------------
# This function needed by NSPage.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(valloc)

#--------------------------------------------------------------------
# This function needed by Time.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(times)

#--------------------------------------------------------------------
# These functions needed by NSData.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(mkstemp)
AC_CHECK_FUNCS(shmctl)
AC_CHECK_FUNCS(mmap)

#--------------------------------------------------------------------
# These functions needed by NSTask.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(killpg setpgrp setpgid)
AC_FUNC_SETPGRP

HAVE_PTS_STREAM_MODULES=0
case "${target}" in
  *-sysv-*)
    HAVE_PTS_STREAM_MODULES=1
    ;;
esac
AC_DEFINE_UNQUOTED(HAVE_PTS_STREAM_MODULES, $HAVE_PTS_STREAM_MODULES,
                   [Define this if you work on sysv])
AC_SUBST(HAVE_PTS_STREAM_MODULES)

AC_CHECK_HEADERS(libc.h limits.h malloc.h memory.h string.h signal.h dnl
	sys/signal.h sys/wait.h sys/file.h sys/fcntl.h sys/ioctl.h dnl
	sys/stropts.h unistd.h utime.h stdint.h inttypes.h sys/inttypes.h)

if test $ac_cv_header_stdint_h = yes; then
INCLUDE_STDINT="#include <stdint.h>"
elif test $ac_cv_header_inttypes_h = yes; then
INCLUDE_STDINT="#include <inttypes.h>"
elif test $ac_cv_header_sys_inttypes_h = yes; then
INCLUDE_STDINT="#include <sys/inttypes.h>"
else
INCLUDE_STDINT="no"
fi

if test "$INCLUDE_STDINT" = "no"; then
INCLUDE_STDINT=""
DEFINE_INT8_T="#define int8_t gss8"
DEFINE_UINT8_T="#define uint8_t gsu8"
DEFINE_INT16_T="#define int16_t gss16"
DEFINE_UINT16_T="#define uint16_t gsu16"
DEFINE_INT32_T="#define int32_t gss32"
DEFINE_UINT32_T="#define uint32_t gsu32"
DEFINE_INT64_T="#define int64_t gss64"
DEFINE_UINT64_T="#define uint64_t gsu64"
else
DEFINE_INT8_T=""
DEFINE_UINT8_T=""
DEFINE_INT16_T=""
DEFINE_UINT16_T=""
DEFINE_INT32_T=""
DEFINE_UINT32_T=""
DEFINE_INT64_T=""
DEFINE_UINT64_T=""
fi

AC_SUBST(INCLUDE_STDINT)
AC_SUBST(DEFINE_INT8_T)
AC_SUBST(DEFINE_UINT8_T)
AC_SUBST(DEFINE_INT16_T)
AC_SUBST(DEFINE_UINT16_T)
AC_SUBST(DEFINE_INT32_T)
AC_SUBST(DEFINE_UINT32_T)
AC_SUBST(DEFINE_INT64_T)
AC_SUBST(DEFINE_UINT64_T)

#--------------------------------------------------------------------
# These used by GSFileHandle.m and distributed objects
#--------------------------------------------------------------------
AC_CHECK_FUNCS(inet_aton sigaction)
USE_ZLIB=0
AC_CHECK_HEADERS(zlib.h)
if test $ac_cv_header_zlib_h = yes; then
  AC_CHECK_LIB(z, gzseek, zlib_ok=yes, zlib_ok=no)
  if test "$zlib_ok" = yes; then
    LIBS="$LIBS -lz"
    USE_ZLIB=1
  fi
fi
AC_SUBST(USE_ZLIB)

#--------------------------------------------------------------------
# One of these function needed by NSThread.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(nanosleep usleep)

#--------------------------------------------------------------------
# This function needed by NSDebug.m and NSProcessInfo.m
#--------------------------------------------------------------------
AC_CHECK_FUNCS(strerror)

#--------------------------------------------------------------------
# This type needed by GSFormat
#--------------------------------------------------------------------
AC_CHECK_TYPES([uintmax_t])

AC_MSG_CHECKING([whether precompiler handles LONG_LONG_MAX])
# We need to define _GNU_SOURCE for some systems to enable LONG_LONG_MAX
AC_TRY_CPP([#ifndef _GNU_SOURCE
	#define _GNU_SOURCE
	#endif
        #ifdef HAVE_STDINT_H
	#include <stdint.h>
	#endif
	#include <limits.h>
	#if defined(LONG_LONG_MAX)
	#if LONG_MAX == LONG_LONG_MAX
	#error long max equals long long max
	#endif
	#else
	#error long long max not defined
	#endif
	], llmax=yes, llmax=no)
if test $llmax = yes; then
	AC_MSG_RESULT(yes)
        AC_DEFINE(HANDLE_LONG_LONG_MAX,1,
                  [Define if this constant is defined])
else
	AC_MSG_RESULT(no)
fi

#
# Solaris and *BSD use LLONG_MAX instead
#
AC_MSG_CHECKING([whether we have LLONG_MAX])
AC_TRY_CPP([#include <limits.h>
	#if defined(LLONG_MAX)
	#if LONG_MAX == LLONG_MAX
	#error long max equals long long max
	#endif
	#else
	#error llong max not defined
	#endif
	], llmax=yes, llmax=no)

if test $llmax = yes; then
  AC_MSG_RESULT(yes)
  AC_DEFINE(HANDLE_LLONG_MAX,1,
            [Define if this constant is defined])
else
  AC_MSG_RESULT(no)
fi
AC_CHECK_HEADERS(wchar.h)

#--------------------------------------------------------------------
# Check if short and int values need to be word aligned
#--------------------------------------------------------------------
AC_MSG_CHECKING(short/int needs to be word aligned)
AC_TRY_RUN([#include "$srcdir/config/config.align.c"],
	NEED_WORD_ALIGNMENT=0,
	NEED_WORD_ALIGNMENT=1,
	NEED_WORD_ALIGNMENT=1)
AC_DEFINE_UNQUOTED(NEED_WORD_ALIGNMENT, $NEED_WORD_ALIGNMENT,
                   [Define if your system needs to have short/int word aligned])
if test $NEED_WORD_ALIGNMENT = 1; then
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
fi

#--------------------------------------------------------------------
# This function needed by NSString for handling of %@ printf directive.
#--------------------------------------------------------------------
AC_CHECK_FUNC(register_printf_function, register_printf=1, 
register_printf=0)
if test $register_printf = 1; then
  AC_TRY_RUN([#include "$srcdir/config/config.printf.c"],
	       working_register_printf=1, working_register_printf=0, 
               working_register_printf=1)
  if test $working_register_printf = 1; then
    AC_DEFINE(HAVE_REGISTER_PRINTF_FUNCTION,1,
              [Define if you have the register_printf_function function])
  fi
fi

#--------------------------------------------------------------------
# This function needed by NSString.
#--------------------------------------------------------------------
AC_CHECK_FUNCS(realpath)

#--------------------------------------------------------------------
# Check if the C Library defines extern char *program_invocation_name
# Used in critical cases by NSProcessInfo.m
#--------------------------------------------------------------------
AC_MSG_CHECKING(program_invocation_name in C Library)
AC_CACHE_VAL(program_invocation_name_worked,
[AC_TRY_RUN([
#include <string.h>
int 
main (int argc, char *argv[])
{
  extern char *program_invocation_name;
  return (strcmp (program_invocation_name, argv[0]));
}
], program_invocation_name_worked=yes, program_invocation_name_worked=no, program_invocation_name_worked=no)])
if test $program_invocation_name_worked = yes; then
  AC_DEFINE(HAVE_PROGRAM_INVOCATION_NAME,1,
            [Define if your Lib C defines program_invocation_name])
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
fi

#--------------------------------------------------------------------
# Defines HAVE_PROCFS if the kernel supports the /proc filesystem. 
# Needed by NSProcessInfo.m 
#--------------------------------------------------------------------
AC_CHECK_HEADERS(procfs.h)
AC_SYS_PROCFS
AC_SYS_PROCFS_PSINFO
AC_SYS_PROCFS_EXE_LINK

#--------------------------------------------------------------------
# Check if /proc/$$/cmdline terminates the last argument with a nul
#--------------------------------------------------------------------
AC_MSG_CHECKING(/proc/$$/cmdline terminated by nul)
AC_TRY_RUN([#include "$srcdir/config/config.proccmd.c"],
	CMDLINE_TERMINATED=1,
	CMDLINE_TERMINATED=0,
	CMDLINE_TERMINATED=0)
AC_DEFINE_UNQUOTED(CMDLINE_TERMINATED, $CMDLINE_TERMINATED,
		   [Define if your system terminates the final argument in /proc/$$/cmdline])
if test $CMDLINE_TERMINATED = 1; then
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
fi

#--------------------------------------------------------------------
# If /proc doesn't work, try kvm (on FreeBSD, for instance)
#--------------------------------------------------------------------
have_kvm_env=0
save_LIBS="$LIBS"
AC_CHECK_LIB(kvm, kvm_getenvv)
if test "$ac_cv_lib_kvm_kvm_getenvv" = yes; then
  AC_MSG_CHECKING(if we can access kernel memory)
  AC_TRY_RUN([#include "$srcdir/config/config.kvmopen.c"],
	have_kvm_env=1,
	have_kvm_env=0,
	have_kvm_env=0)
  if test $have_kvm_env = 1; then
    AC_MSG_RESULT(yes)
    AC_DEFINE(HAVE_KVM_ENV, 1, 
    			    [Define if you can access the kernel via kvm_open])
  else
    AC_MSG_RESULT(no)
    # Reset LIBS since we don't need kvm
    LIBS="$save_LIBS"
  fi
fi

#--------------------------------------------------------------------
# Include redefinition of main () only if needed.
# On some systems - force redefinition to be used as the /proc stuff
# doesn't work. Allow NSProcessInfo initialization method also.
#--------------------------------------------------------------------
PASS_ARG=no
case "$target_os" in
  cygwin*)	PASS_ARG=yes;;
esac

AC_MSG_CHECKING("use of pass-through arguments")
AC_ARG_ENABLE(pass-arguments,
  [  --enable-pass-arguments	Force user main call to NSProcessInfo initialize],,
  enable_pass_arguments=$PASS_ARG)

if test "$enable_pass_arguments" = "yes"; then
  GS_PASS_ARGUMENTS=1
else
  GS_PASS_ARGUMENTS=0
fi
AC_SUBST(GS_PASS_ARGUMENTS)
AC_MSG_RESULT($enable_pass_arguments)

AC_MSG_CHECKING("use of fake-main definition")
AC_ARG_ENABLE(fake-main,
  [  --enable-fake-main  		Force redefine of user main function],,
  enable_fake_main=no)

if test "$enable_pass_arguments" = "no"; then
  case "$target_os" in
    freebsd2*)	enable_fake_main=yes;;
    freebsd*)	;;
    netbsd*)	enable_fake_main=yes;;
    openbsd*)	enable_fake_main=yes;;
    *sysv*)	enable_fake_main=yes;;
  esac
fi

GS_FAKE_MAIN=0
if test "$enable_fake_main" = "yes"; then
  GS_FAKE_MAIN=1
elif test "$enable_pass_arguments" = "no"; then
  if test "$objc_load_method_worked" = yes -a \( "$ac_cv_sys_procfs" = yes -o "$have_kvm_env" = 1 -o "$ac_cv_sys_procfs_psinfo" = yes \); then
    GS_FAKE_MAIN=0
  else
    GS_FAKE_MAIN=1
    enable_fake_main=yes
  fi
fi
case "$target_os" in
    mingw*)	enable_fake_main=no; GS_FAKE_MAIN=0;;
esac
AC_SUBST(GS_FAKE_MAIN)
AC_MSG_RESULT($enable_fake_main)

#--------------------------------------------------------------------
# Simple way to add a bunch of paths to the flags
#--------------------------------------------------------------------
AC_ARG_WITH(include-flags,
    [  --with-include-flags=FLAGS    Specify all include flags at once],
    include_flags="$withval", include_flags="no")
if test ${include_flags} != "no"; then
    CPPFLAGS="$CPPFLAGS ${include_flags}"
    INCLUDE_FLAGS="$INCLUDE_FLAGS ${include_flags}"
fi

AC_ARG_WITH(library-flags,
    [  --with-library-flags=FLAGS    Specify all library flags at once],
    library_flags="$withval", library_flags="no")
if test ${library_flags} != "no"; then
    LDFLAGS="$LDFLAGS ${library_flags}"
    LDIR_FLAGS="$LDIR_FLAGS ${library_flags}"
fi

#--------------------------------------------------------------------
# Check for FFI interface libraries for invocations
# We enable ffcall by default now.
#--------------------------------------------------------------------
do_enable_libffi=no
# Enable libffi by default on the following machines
case "$target_os" in
    darwin*)	do_enable_libffi=yes;;
esac

AC_ARG_ENABLE(libffi,
  [  --enable-libffi  		Enable use of libffi library],,
  enable_libffi=$do_enable_libffi)

AC_ARG_ENABLE(ffcall,
  [  --enable-ffcall  		Enable use of ffcall library],,
  enable_ffcall=yes)

AC_ARG_ENABLE(do,
  [  --disable-do			Compile even if DO-dependencies are not met],,
  enable_do=yes)

# DO isn't used on apple-apple-apple
if test $LIBRARY_COMBO = apple-apple-apple; then
  enable_do=no
fi

AC_ARG_WITH(ffi-include,
[  --with-ffi-include=PATH       Include path for ffi (ffcall/libffi) headers],
    ffi_incdir="$withval", ffi_incdir="no")
if test ${ffi_incdir} != "no"; then
    CPPFLAGS="$CPPFLAGS -I${ffi_incdir}"
    INCLUDE_FLAGS="$INCLUDE_FLAGS -I${ffi_incdir}"
fi

AC_ARG_WITH(ffi-library,
[  --with-ffi-library=PATH       Library path for ffi (ffcall/libffi) libs],
    ffi_libdir="$withval", ffi_libdir="no")
if test ${ffi_libdir} != "no"; then
    LDFLAGS="$LDFLAGS -L${ffi_libdir}"
    LDIR_FLAGS="$LDIR_FLAGS -L${ffi_libdir}"
fi

AC_CHECK_HEADER(ffi.h, have_libffi=yes, have_libffi=no)
AC_CHECK_HEADERS(callback.h, have_ffcall=yes, have_ffcall=no)
if test $have_ffcall = no; then
  enable_ffcall=no
  # If we don't have ffcall but do have libffi, use libffi
  if test $have_libffi = yes; then
    enable_libffi=yes
  fi
fi
if test $have_libffi = no; then
  enable_libffi=no
fi

have_forward_hook=yes
saved_CPPFLAGS="$CPPFLAGS"
CPPFLAGS="$CPPFLAGS $OBJCFLAGS -x objective-c"
AC_MSG_CHECKING("for forwarding callback in runtime")
AC_COMPILE_IFELSE([#include "$srcdir/config/config.forward.m"],
	have_forward_hook=yes, have_forward_hook=no)
AC_MSG_RESULT($have_forward_hook)
if test $have_forward_hook = no; then
  enable_libffi=no
  enable_ffcall=no
fi
CPPFLAGS="$saved_CPPFLAGS"

AC_MSG_CHECKING("FFI library usage")
WITH_FFI=none
if test $enable_libffi = yes; then
  AC_DEFINE(USE_LIBFFI,1,
            [Define if using the libffi library for invocations])
  WITH_FFI=libffi
  LIBS="-lffi $LIBS"
  AC_TRY_LINK([#include <ffi.h>], ,ffi_ok="yes", ffi_ok="no")
  if test $ffi_ok = yes; then
    AC_MSG_RESULT(libffi)
  fi
elif test $enable_ffcall = yes; then
  AC_DEFINE(USE_FFCALL,1,
            [Define if using the ffcall library for invocations])
  WITH_FFI=ffcall
  LIBS="-lcallback -lavcall $LIBS"
  AC_TRY_LINK([#include <callback.h>], , ffi_ok="yes", ffi_ok="no")
  if test $ffi_ok = yes; then
    AC_MSG_RESULT(ffcall)
  fi
else
  ffi_ok=no
fi

if test $ffi_ok = no; then
  AC_MSG_RESULT(none)
  echo
  if test $have_forward_hook = no; then
    echo "You do not have an up-to-date libobjc library installed"
  else
    echo "You do not have either ffcall or libffi installed, or configure needs"
    echo "--with-ffi-include and/or --with-ffi-library flags so GNUstep can find them"
  fi
  echo "GNUstep requires ffcall or libffi and proper libobjc hooks to do"
  echo "invocations and DO."
  echo "(This does not apply on apple-apple-apple systems where DO is"
  echo "not compatible with other GNUstep systems.)"
  if test $enable_do = yes; then
    echo
    echo "You most likely do not want to build base without DO support. Many"
    echo "things, including all applications, won't work at all without DO."
    echo "If you really want to build -base without DO support, add --disable-do"
    echo "to the configure arguments."
    echo "For more information, read the GNUstep build guide, ffcall section:"
    echo "http://documents.made-it.com/GNUstep/buildguide.html#FOREIGN.FUNCTION.INTERFACES"
    AC_MSG_ERROR([Incomplete support for ffi functionality.])
  fi
  AC_MSG_WARN([Incomplete support for ffi funtionality.])
fi
AC_SUBST(WITH_FFI)


#--------------------------------------------------------------------
# Check for iconv support (for Unicode conversion).
#--------------------------------------------------------------------
# Do this before checking for xml2,  as xml2 may require iconv.
#
# We need to find an iconv library that matches the installed iconv.h header
# (if any). It is important to check header/library compatibility. It's
# fairly common to have iconv support both in libc and from libiconv. In that
# case, a naive check that iconv() is in libc will succeed, but if we use
# libiconv's iconv.h, it will redefine iconv() to functions that exist
# only in libiconv, and we'll get link errors.
#
# First, check if there's a working iconv in libc (ie. if the test program
# compiles and links without any extra flags).
AC_MSG_CHECKING(iconv support)
AC_LINK_IFELSE([[#include <iconv.h>
int main(int argc,char **argv) { iconv_open("foo","bar"); }]]
,
  # libc has a working iconv.
  AC_DEFINE(HAVE_ICONV,1, [Define if you have this function])
  AC_MSG_RESULT([[yes, in libc]])
  found_iconv=yes
,
  found_iconv=no
)

if test $found_iconv = no ; then
  # libc doesn't have a working iconv. Try adding -liconv and any user
  # supplied directory.
  AC_ARG_WITH(libiconv-library,
    [  --with-libiconv-library=PATH  Library path for libiconv libraries],
    libiconv_libdir="$withval", libiconv_libdir="no")

  if test "$libiconv_libdir" != "no"; then
    LDFLAGS="$LDFLAGS -L$libiconv_libdir"
    LDIR_FLAGS="$LDIR_FLAGS -L$libiconv_libdir"
  fi

  old_LIBS="$LIBS"
  LIBS="-liconv $LIBS"
  AC_LINK_IFELSE([[#include <iconv.h>
  int main(int argc,char **argv) { iconv_open("foo","bar"); }]]
  ,
    # -liconv works.
    AC_DEFINE(HAVE_ICONV,1, [Define if you have this function])
    AC_MSG_RESULT([[yes, -liconv]])
    found_iconv=yes
  ,
    found_iconv=no
    LIBS="$old_LIBS"
  )
fi

if test $found_iconv = no ; then
  # -liconv didn't work. Try giconv.h and -lgiconv.
  # BSDs install this lib as libgiconv.
  old_LIBS="$LIBS"
  LIBS="-lgiconv $LIBS"
  AC_LINK_IFELSE([[#include <giconv.h>
  int main(int argc,char **argv) { iconv_open("foo","bar"); }]]
  ,
    AC_DEFINE(HAVE_ICONV,1, [Define if you have this function])
    AC_DEFINE(HAVE_GICONV,1, [Define if you have this function])
    AC_MSG_RESULT([[yes, -lgiconv]])
  ,
    AC_MSG_RESULT([[no]])
    LIBS="$old_LIBS"
  )
fi

#--------------------------------------------------------------------
# Check recent libxml for Properytlists, GSXML, GSDoc etc.
#--------------------------------------------------------------------

AC_ARG_ENABLE(xml,
  [  --disable-xml			Compile even if XML-dependencies are not met],,
  enable_xml=yes)

if test $enable_xml = yes; then
  # Save CFLAGS and LIBS as AM_PATH_XML clobbers these variables regardless
  # of the success of the macro.
  saved_LIBS="$LIBS"
  saved_CFLAGS="$CFLAGS"

  AM_PATH_XML(2.3.0, enable_libxml=yes, enable_libxml=no)
  if test $enable_libxml = yes; then
    CPPFLAGS="$CPPFLAGS $XML_CFLAGS"
    INCLUDE_FLAGS="$INCLUDE_FLAGS $XML_CFLAGS"
    LIBS="$XML_LIBS $LIBS"
    HAVE_LIBXML=1
    AC_DEFINE(HAVE_LIBXML,1,[Define if libxml available])
    AC_CHECK_HEADERS(libxml/SAX2.h)
    #--------------------------------------------------------------------
    # Check for (optional) libxslt
    #--------------------------------------------------------------------
    AC_ARG_ENABLE(xslt,
      [  --disable-xslt		Compile even if XSLT-dependency is not met],,
      enable_xslt=yes)

    if test $enable_xslt = yes; then
      AC_CHECK_LIB(xslt, xsltApplyStylesheet, xslt_ok=yes, xslt_ok=no)
      if test "$xslt_ok" = "yes"; then
	AC_CHECK_HEADER(libxslt/xslt.h, xslthdr_ok=yes, xslthdr_ok=no)
	if test "$xslthdr_ok" = "no"; then
	  xslt_ok=no
	fi
      fi
      if test "$xslt_ok" = "yes"; then
	HAVE_LIBXSLT=1
	AC_DEFINE(HAVE_LIBXSLT,1,[Define if libxslt available])
	LIBS="-lxslt $LIBS"
      else
	echo
	echo "You most likely do not want to build base without XSLT support."
	echo "If you really want to build -base without XSLT support,"
	echo "add --disable-xslt to the configure arguments."
	AC_MSG_WARN([Missing support for XSLT functionality.])
      fi
    else
      HAVE_LIBXSLT=0
      AC_MSG_WARN([Disabled support for XSLT funtionality.])
    fi
    AC_SUBST(HAVE_LIBXSLT)
  else
    HAVE_LIBXML=0
    # Restore the CFLAGS and LIBS because AM_PATH_XML messes them
    LIBS="$saved_LIBS"
    CFLAGS="$saved_CFLAGS"
    echo
    echo "You most likely do not want to build base without XML support."
    echo "For instance, MacOS-X compatible property lists require XML."
    echo "If you really want to build -base without XML support,"
    echo "add --disable-xml to the configure arguments."
    AC_MSG_ERROR([Missing support for XML functionality.])
  fi
else
  AC_MSG_WARN([Disabled support for XML funtionality.])
  HAVE_LIBXML=0
fi
AC_SUBST(HAVE_LIBXML)

#--------------------------------------------------------------------
# Check GMP for NSDecimal
#--------------------------------------------------------------------
AC_ARG_WITH(gmp-include,
  [  --with-gmp-include=PATH  include path for gmp headers],
  gmp_incdir="$withval", gmp_incdir="no")

AC_ARG_WITH(gmp-library,
  [  --with-gmp-library=PATH  library path for gmp libraries],
  gmp_libdir="$withval", gmp_libdir="no")

libs_temp=$LIBS

if test "$gmp_incdir" != "no"; then
  CPPFLAGS="$CPPFLAGS -I$gmp_incdir"
  INCLUDE_FLAGS="$INCLUDE_FLAGS -I$gmp_incdir"
fi
if test "$gmp_libdir" != "no"; then
  LDFLAGS="$LDFLAGS -L$gmp_libdir"
  LDIR_FLAGS="$LDIR_FLAGS -L$gmp_libdir"
fi

USE_GMP=0
AC_CHECK_HEADERS(gmp.h)
if test $ac_cv_header_gmp_h = yes; then
  AC_CHECK_LIB(gmp, mpf_abs, gmp_ok=yes, gmp_ok=no)
  if test "$gmp_ok" = no; then
    AC_CHECK_LIB(gmp, __gmpf_abs, gmp_ok=yes, gmp_ok=no)
  fi
  if test "$gmp_ok" = yes; then
    LIBS="-lgmp $LIBS"
    USE_GMP=1
  fi
fi

AC_SUBST(USE_GMP)

#--------------------------------------------------------------------
# Check whether nl_langinfo(CODESET) is supported, needed by Unicode.m.
#--------------------------------------------------------------------
AM_LANGINFO_CODESET


AC_SUBST(INCLUDE_FLAGS)
AC_SUBST(LDIR_FLAGS)

#--------------------------------------------------------------------
# Configure flags from sub-configure runs, so they show up in our
# help file.
#--------------------------------------------------------------------
AC_ARG_ENABLE(openssl,
  [  --disable-openssl		Disable support for openssl in URL classes],,
  enable_openssl=yes)
AC_ARG_WITH(openssl-include,
  [  --with-openssl-include=PATH  include path for openssl headers],
  openssl_incdir="$withval", openssl_incdir="no")
AC_ARG_WITH(openssl-library,
  [  --with-openssl-library=PATH  library path for openssl libraries],
  openssl_libdir="$withval", openssl_libdir="no")

AC_CONFIG_SUBDIRS(Source/mframe SSL)

#--------------------------------------------------------------------
# Record the version
#--------------------------------------------------------------------
AC_MSG_CHECKING(for the version of gnustep-base we are compiling)
if test -f "Version"; then
  . ./Version
fi
AC_MSG_RESULT($VERSION)
AC_SUBST(VERSION)
AC_SUBST(MAJOR_VERSION)
AC_SUBST(MINOR_VERSION)
AC_SUBST(SUBMINOR_VERSION)
AC_SUBST(GCC_VERSION)

#--------------------------------------------------------------------
# Write the Makefiles
#--------------------------------------------------------------------
AC_CONFIG_FILES([config.mak base.make Headers/Additions/GNUstepBase/GSConfig.h 
	  Headers/Additions/GNUstepBase/preface.h])
AC_OUTPUT
