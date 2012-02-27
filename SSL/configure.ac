# configure.in for GNUstep base SSL bundle
# Process this file with autoconf to produce a configure script.
#
#   Copyright (C) 2002 Free Software Foundation, Inc.
#
#   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
#
#   This file is part of the GNU Objective-C library.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#   
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Library General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02111 USA
AC_INIT
AC_CONFIG_SRCDIR([GSSSLHandle.m])

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must have the gnustep-make package installed and set up the GNUSTEP_MAKEFILES environment variable to contain the path to the makefiles directory before configuring!])
fi

#--------------------------------------------------------------------
# Use a .h file with #define's, instead of -D command-line switches
#--------------------------------------------------------------------
AC_CONFIG_HEADER(config.h)

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR($GNUSTEP_MAKEFILES)

#--------------------------------------------------------------------
# Miscellaneous flags
#--------------------------------------------------------------------

#
# It looks like we ought to source the whole GNUstep.sh here, and even
# ask it to output all variables!  That way we have access to (eg)
# GNUSTEP_SYSTEM_HEADERS below.
#
GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
. "$GNUSTEP_MAKEFILES/GNUstep.sh"
unset GNUSTEP_SH_EXPORT_ALL_VARIABLES

# For backwards compatibility, define GNUSTEP_SYSTEM_HEADERS from
# GNUSTEP_SYSTEM_ROOT if not set yet.
if test x"$GNUSTEP_SYSTEM_HEADERS" = x""; then
  GNUSTEP_SYSTEM_HEADERS="$GNUSTEP_SYSTEM_ROOT/Library/Headers"
fi

if test x"$GNUSTEP_SYSTEM_LIBRARIES" = x""; then
  GNUSTEP_SYSTEM_LIBRARIES="$GNUSTEP_SYSTEM_ROOT/Library/Libraries"
fi

if test "$GNUSTEP_IS_FLATTENED" = no; then
  clean_target_os=`$GNUSTEP_MAKEFILES/clean_os.sh $target_os`
  clean_target_cpu=`$GNUSTEP_MAKEFILES/clean_cpu.sh $target_cpu`
  obj_dir=$clean_target_cpu/$clean_target_os
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_LIBRARIES/$obj_dir
  GNUSTEP_HDIR=$GNUSTEP_SYSTEM_HEADERS/$LIBRARY_COMBO
else
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_LIBRARIES
  GNUSTEP_HDIR=$GNUSTEP_SYSTEM_HEADERS
fi

#
# The following one is so that headers of custom libraries placed in
# $GNUSTEP_HDIR are used before the standard ones
#
CPPFLAGS="$CPPFLAGS -I$GNUSTEP_HDIR"
LDFLAGS="$LDFLAGS -L$GNUSTEP_LDIR/$LIBRARY_COMBO -L$GNUSTEP_LDIR"

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

AC_EXEEXT

#--------------------------------------------------------------------
# specific target_os options
#--------------------------------------------------------------------
case "$target_os" in
  freebsd*)	CPPFLAGS="$CPPFLAGS -I/usr/local/include"
		LIBS="$LIBS -L/usr/local/lib";;

esac

AC_CHECK_HEADERS(dnl
	fcntl.h dnl
	libc.h dnl
	limits.h dnl
	malloc.h dnl
	memory.h dnl
	signal.h dnl
	stdint.h dnl
	string.h dnl
	sys/fcntl.h dnl
	sys/file.h dnl
	sys/inttypes.h dnl
	sys/ioctl.h dnl
	sys/param.h dnl
	sys/signal.h dnl
	sys/stropts.h dnl
	sys/wait.h dnl
	unistd.h dnl
	utime.h dnl
	)

#--------------------------------------------------------------------
# Simple way to add a bunch of paths to the flags
#--------------------------------------------------------------------
AC_ARG_WITH(include-flags,
    [  --with-include-flags=FLAGS specify all include flags at once],
    include_flags="$withval", include_flags="no")
if test ${include_flags} != "no"; then
    CPPFLAGS="${include_flags} $CPPFLAGS"
    SSLFLAGS="${include_flags}"
fi

AC_ARG_WITH(library-flags,
    [  --with-library-flags=FLAGS specify all library flags at once],
    library_flags="$withval", library_flags="no")
if test ${library_flags} != "no"; then
    LIBS="${library_flags} $LIBS"
    SSLLIBS="${library_flags}"
fi

#--------------------------------------------------------------------
# Check OpenSSL for HTTPS support.
#--------------------------------------------------------------------
AC_ARG_ENABLE(openssl,
  [  --disable-openssl       	Disable support for openssl in URL classes],,
  enable_openssl=yes)
AC_ARG_WITH(openssl-include,
  [  --with-openssl-include=PATH  include path for openssl headers],
  openssl_incdir="$withval", openssl_incdir="no")
AC_ARG_WITH(openssl-library,
  [  --with-openssl-library=PATH  library path for openssl libraries],
  openssl_libdir="$withval", openssl_libdir="no")

cppflags_temp="$CPPFLAGS"

if test "$openssl_incdir" != "no"; then
  CPPFLAGS="$CPPFLAGS -I$openssl_incdir"
  SSLFLAGS="-I$openssl_incdir"
else
  SSLFLAGS=
fi

if test "$openssl_libdir" != "no"; then
  LIBS="$LIBS -L$openssl_libdir"
  SSLLIBS="-L$openssl_libdir"
else
  SSLLIBS=
fi

if test $enable_openssl = yes; then
  ssl_ok=no
  AC_CHECK_HEADERS(openssl/ssl.h)
  if test $ac_cv_header_openssl_ssl_h = yes; then
    AC_CHECK_LIB(crypto, CRYPTO_malloc)
    if test $ac_cv_lib_crypto_CRYPTO_malloc = yes; then
      # ssl needs socket on Solaris
      AC_CHECK_LIB(socket, main)
      AC_CHECK_LIB(ssl, SSL_clear)
      AC_CHECK_LIB(cipher,des_setkey)
      if test $ac_cv_lib_ssl_SSL_clear = yes; then
        ssl_ok=yes
      fi
      AC_CHECK_FUNC(CRYPTO_THREADID_set_callback)
    fi
  fi
  if test $ssl_ok = no; then
    AC_MSG_WARN(SSL bundle will not be built: Could not find openssl libraries)
  fi
else
  AC_MSG_WARN(SSL bundle will not be built: Openssl disabled by user)
fi
HAVE_OPENSSL=$ssl_ok
SSLLIBS="$SSLLIBS $LIBS"
AC_SUBST(HAVE_OPENSSL)
AC_SUBST(SSLFLAGS)
AC_SUBST(SSLLIBS)

CPPFLAGS="$cppflags_temp";

#--------------------------------------------------------------------
# Write the Makefiles
#--------------------------------------------------------------------
AC_CONFIG_FILES([config.mak])
AC_OUTPUT
