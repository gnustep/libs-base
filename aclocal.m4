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
#   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA


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

if test $DYNAMIC_LINKER = simple; then
  AC_TRY_LINK([#include <dlfcn.h>], dladdr(0,0);, 
	      AC_DEFINE(HAVE_DLADDR))
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

#-----------------------------------------------------------------------------
# Check for libxml; macro taken from libxml 2.2.10 installation
#-----------------------------------------------------------------------------
dnl Code shamelessly stolen from glib-config by Sebastian Rittau
dnl AM_PATH_XML([MINIMUM-VERSION [, ACTION-IF-FOUND [, ACTION-IF-NOT-FOUND]]])
AC_DEFUN(AM_PATH_XML,[
AC_ARG_WITH(xml-prefix,
            [  --with-xml-prefix=PFX    Prefix where libxml is installed (optional)],
            xml_config_prefix="$withval", xml_config_prefix="")
AC_ARG_ENABLE(xmltest,
              [  --disable-xmltest        Do not try to compile and run a test XML program],,
              enable_xmltest=yes)

  if test x$xml_config_prefix != x ; then
    xml_config_args="$xml_config_args --prefix=$xml_config_prefix"
    if test x${XML_CONFIG+set} != xset ; then
      XML_CONFIG=$xml_config_prefix/bin/xml-config
    fi
  fi

  AC_PATH_PROG(XML_CONFIG, xml-config, no)
  min_xml_version=ifelse([$1], ,2.0.0, [$1])
  AC_MSG_CHECKING(for libxml - version >= $min_xml_version)
  no_xml=""
  if test "$XML_CONFIG" = "no" ; then
    no_xml=yes
  else
    XML_CFLAGS=`$XML_CONFIG $xml_config_args --cflags`
    XML_LIBS=`$XML_CONFIG $xml_config_args --libs`
    xml_config_major_version=`$XML_CONFIG $xml_config_args --version | \
      sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\1/'`
    xml_config_minor_version=`$XML_CONFIG $xml_config_args --version | \
      sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\2/'`
    xml_config_micro_version=`$XML_CONFIG $xml_config_args --version | \
      sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\3/'`
    if test "x$enable_xmltest" = "xyes" ; then
      ac_save_CFLAGS="$CFLAGS"
      ac_save_LIBS="$LIBS"
      CFLAGS="$CFLAGS $XML_CFLAGS"
      LIBS="$XML_LIBS $LIBS"
dnl
dnl Now check if the installed libxml is sufficiently new.
dnl
      rm -f conf.xmltest
      AC_TRY_RUN([
#include <stdlib.h>
#include <stdio.h>
#include <xmlversion.h>
#include <parser.h>

int
main()
{
  int xml_major_version, xml_minor_version, xml_micro_version;
  int major, minor, micro;
  char *tmp_version;

  system("touch conf.xmltest");

  tmp_version = xmlStrdup("$min_xml_version");
  if(sscanf(tmp_version, "%d.%d.%d", &major, &minor, &micro) != 3) {
    printf("%s, bad version string\n", "$min_xml_version");
    exit(1);
  }

  tmp_version = xmlStrdup(LIBXML_DOTTED_VERSION);
  if(sscanf(tmp_version, "%d.%d.%d", &xml_major_version, &xml_minor_version, &xml_micro_version) != 3) {
    printf("%s, bad version string\n", "$min_xml_version");
    exit(1);
  }

  if((xml_major_version != $xml_config_major_version) ||
     (xml_minor_version != $xml_config_minor_version) ||
     (xml_micro_version != $xml_config_micro_version))
    {
      printf("\n*** 'xml-config --version' returned %d.%d.%d, but libxml (%d.%d.%d)\n", 
             $xml_config_major_version, $xml_config_minor_version, $xml_config_micro_version,
             xml_major_version, xml_minor_version, xml_micro_version);
      printf("*** was found! If xml-config was correct, then it is best\n");
      printf("*** to remove the old version of libxml. You may also be able to fix the error\n");
      printf("*** by modifying your LD_LIBRARY_PATH enviroment variable, or by editing\n");
      printf("*** /etc/ld.so.conf. Make sure you have run ldconfig if that is\n");
      printf("*** required on your system.\n");
      printf("*** If xml-config was wrong, set the environment variable XML_CONFIG\n");
      printf("*** to point to the correct copy of xml-config, and remove the file config.cache\n");
      printf("*** before re-running configure\n");
    }
  else
    {
      if ((xml_major_version > major) ||
          ((xml_major_version == major) && (xml_minor_version > minor)) ||
          ((xml_major_version == major) && (xml_minor_version == minor) &&
           (xml_micro_version >= micro)))
        {
          return 0;
        }
      else
        {
          printf("\n*** An old version of libxml (%d.%d.%d) was found.\n",
            xml_major_version, xml_minor_version, xml_micro_version);
          printf("*** You need a version of libxml newer than %d.%d.%d. The latest version of\n",
            major, minor, micro);
          printf("*** libxml is always available from ftp://ftp.gnome.org.\n");
          printf("***\n");
          printf("*** If you have already installed a sufficiently new version, this error\n");
          printf("*** probably means that the wrong copy of the xml-config shell script is\n");
          printf("*** being found. The easiest way to fix this is to remove the old version\n");
          printf("*** of libxml, but you can also set the XML_CONFIG environment to point to the\n");
          printf("*** correct copy of xml-config. (In this case, you will have to\n");
          printf("*** modify your LD_LIBRARY_PATH enviroment variable, or edit /etc/ld.so.conf\n");
          printf("*** so that the correct libraries are found at run-time))\n");
        }
    }
  return 1;
}
],, no_xml=yes,[echo $ac_n "cross compiling; assumed OK... $ac_c"])

      CFLAGS="$ac_save_CFLAGS"
      LIBS="$ac_save_LIBS"
    fi
  fi

  if test "x$no_xml" = x ; then
    AC_MSG_RESULT(yes)
    ifelse([$2], , :, [$2])
  else
    AC_MSG_RESULT(no)
    if test "$XML_CONFIG" = "no" ; then
      echo "*** The xml-config script installed by libxml could not be found"
      echo "*** If libxml was installed in PREFIX, make sure PREFIX/bin is in"
      echo "*** your path, or set the XML_CONFIG environment variable to the"
      echo "*** full path to xml-config."
    else
      if test -f conf.xmltest ; then
        :
      else
        echo "*** Could not run libxml test program, checking why..."
        CFLAGS="$CFLAGS $XML_CFLAGS"
        LIBS="$LIBS $XML_LIBS"
        dnl FIXME: AC_TRY_LINK
      fi
    fi

    XML_CFLAGS=""
    XML_LIBS=""
    ifelse([$3], , :, [$3])
  fi
  AC_SUBST(XML_CFLAGS)
  AC_SUBST(XML_LIBS)
  rm -f conf.xmltest
])
