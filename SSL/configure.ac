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
#   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA
AC_INIT
AC_CONFIG_SRCDIR([GSSSLHandle.m])

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use a .h file with #define's, instead of -D command-line switches
#--------------------------------------------------------------------
AC_CONFIG_HEADER(config.h)

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR($GNUSTEP_SYSTEM_ROOT/Makefiles)

#--------------------------------------------------------------------
# Miscellaneous flags
#--------------------------------------------------------------------
# Set location of GNUstep dirs for later use
GNUSTEP_HDIR=$GNUSTEP_SYSTEM_ROOT/Headers
if test "$GNUSTEP_FLATTENED" = yes; then
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_ROOT/Libraries
else
  clean_target_os=`$GNUSTEP_SYSTEM_ROOT/Makefiles/clean_os.sh $target_os`
  clean_target_cpu=`$GNUSTEP_SYSTEM_ROOT/Makefiles/clean_cpu.sh $target_cpu`
  obj_dir=$clean_target_cpu/$clean_target_os
  GNUSTEP_LDIR=$GNUSTEP_SYSTEM_ROOT/Libraries/$obj_dir
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

AC_CHECK_HEADERS(libc.h limits.h malloc.h memory.h string.h signal.h sys/signal.h sys/param.h sys/wait.h sys/file.h sys/fcntl.h sys/ioctl.h sys/stropts.h unistd.h utime.h stdint.h sys/inttypes.h)

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
libs_temp=$LIBS

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
  AC_CHECK_HEADERS(openssl/ssl.h)
  if test $ac_cv_header_openssl_ssl_h = no; then
    AC_MSG_WARN(Could not find openssl headers)
    AC_MSG_WARN(The SSL bundle will not be built)
    ssl_ok=no
  else
    AC_CHECK_LIB(crypto, CRYPTO_malloc, ssl_ok=yes, ssl_ok=no)
    if test "$ssl_ok" = yes; then
      base_libs="$LIBS"
      LIBS="$LIBS -lcrypto"
      AC_CHECK_LIB(ssl, ssl2_clear, ssl_ok=yes, ssl_ok=no)
      if test "$ssl_ok" = yes; then
        echo "found openssl"
        LIBS="$base_libs -lssl -lcrypto"
	SSLLIBS="$SSLLIBS -lssl -lcrypto"
      else
	SSLLIBS="$SSLLIBS -lcrypto"
        AC_MSG_WARN(Could not find openssl libraries)
	AC_MSG_WARN(The SSL bundle will not be built)
      fi

      AC_CHECK_LIB(cipher,des_setkey,cipher_ok=yes,cipher_ok=no)
      if test "$cipher_ok" = yes; then
        echo "found cipher"
        LIBS="$LIBS -lcipher"
        SSLLIBS="$SSLLIBS -lcipher"
      fi
    else
      AC_MSG_WARN(Could not find openssl libraries)
      AC_MSG_WARN(The SSL bundle will not be built)
    fi
  fi
else
  AC_MSG_WARN(The use of openssl was disabled)
  AC_MSG_WARN(The SSL bundle will not be built)
fi
HAVE_OPENSSL=$ssl_ok
AC_SUBST(HAVE_OPENSSL)
AC_SUBST(SSLFLAGS)
AC_SUBST(SSLLIBS)

CPPFLAGS="$cppflags_temp";
LIBS="$libs_temp";

#--------------------------------------------------------------------
# Write the Makefiles
#--------------------------------------------------------------------
AC_CONFIG_FILES([config.mak])
AC_OUTPUT
