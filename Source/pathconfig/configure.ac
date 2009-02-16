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
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02111 USA

AC_INIT

AC_CONFIG_SRCDIR([pathconfig.h.in])

# If GNUSTEP_MAKEFILES is undefined, try to use gnustep-config to determine it.
if test -z "$GNUSTEP_MAKEFILES"; then
  GNUSTEP_MAKEFILES=`gnustep-config --variable=GNUSTEP_MAKEFILES 2>&5`
fi

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must have the gnustep-make package installed and set up the GNUSTEP_MAKEFILES environment variable to contain the path to the makefiles directory before configuring!])
fi

# We shouldn't be loading GNUstep.sh here.  It would load in a lot of
# variables which might get confused with the ones that will be used
# at runtime.  We will load it later once we have determined (and
# saved) the runtime configuration.

# This variable might get temporarily overwritten with the
# GNUSTEP_MAKEFILES of the runtime configuration, make sure we keep
# track of the original one.  CURRENT_GNUSTEP_MAKEFILES is the one
# that we use to locate the actual gnustep-make installation that 
# will build the software.
CURRENT_GNUSTEP_MAKEFILES="$GNUSTEP_MAKEFILES"

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR($CURRENT_GNUSTEP_MAKEFILES)

#--------------------------------------------------------------------
# Use a .h file with #define's, instead of -D command-line switches
#--------------------------------------------------------------------
AC_CONFIG_HEADER(pathconfig.h)

#--------------------------------------------------------------------
# Determine the host, build, and target systems
#--------------------------------------------------------------------
AC_CANONICAL_TARGET([])

#---------------------------------------------------------------------
# Location of the GNUstep.conf config file (--with-config-file)
#---------------------------------------------------------------------
AC_MSG_CHECKING([for GNUstep configuration file to use at runtime])
GNUSTEP_CONFIG_FILE=""

# This requires gnustep-make > 1.13.0 to work.  For gnustep-make =
# 1.13.0 we would have to parse
# $CURRENT_GNUSTEP_MAKEFILES/$obj_dir/config.make, but $obj_dir is not defined
# yet at this stage in config, not sure if it's worth trying to make
# it work.  For gnustep-make < 1.13.0 we would have to parse
# $CURRENT_GNUSTEP_MAKEFILES/config.make.
GNUSTEP_MAKE_CONFIG=`(grep '^GNUSTEP_CONFIG_FILE *=' $CURRENT_GNUSTEP_MAKEFILES/config-noarch.make | sed -e 's/GNUSTEP_CONFIG_FILE *= *\(.*\)/\1/') 2>&5`

# So, for backwards compatiblity, we try the plain config.make too.
# This should work with gnustep-make < 1.13.0, and with 1.13.0 too if
# they haven't deleted the file.
if test "$GNUSTEP_MAKE_CONFIG"  = ""; then
  GNUSTEP_MAKE_CONFIG=`(grep '^GNUSTEP_CONFIG_FILE *=' $CURRENT_GNUSTEP_MAKEFILES/config.make | sed -e 's/GNUSTEP_CONFIG_FILE *= *\(.*\)/\1/') 2>&5`
fi

AC_ARG_WITH(config-file,
[  --with-config-file=PATH       Specify path to the GNUstep config file.
				This is the location to be used by the base
				library to locate path information at
				application or tool runtime.
				This file might not even exist now; it is
				not read at configure time.  The base library
				will only read it at runtime.
				If unspecified, this uses the same value as
				the GNUstep make package on unix-like systems,
				but uses ./GNUstep.conf on mingw so that
				it is relative to the location of the
				base library DLL.
				If a leading './' is specified, the path
				is taken to be relative to the base library
				linked runtime, not all operating systems
				can support this, so on some platforms you
				may need to specify the location of the
				config file using the GNUSTEP_CONFIG_FILE
				environment variable at runtime.
				If a trailing '/' is specified, the path is
				used for locating domains but no GNUstep
				config file is read at runtime.], 
  result="$withval",
  result="no"
)
if test "$result" != "no"
then
  GNUSTEP_CONFIG_FILE="$result"
fi
if test "$GNUSTEP_CONFIG_FILE" = ""; then
  case "$target_os" in
    mingw*)
      GNUSTEP_CONFIG_FILE=./GNUstep.conf ;;
    *)
      GNUSTEP_CONFIG_FILE="$GNUSTEP_MAKE_CONFIG" ;;
  esac
fi
AC_MSG_RESULT($GNUSTEP_CONFIG_FILE)

#-----------------------------------------------------------------
# Whether the GNUstep.conf file path can be set in the environment
# By default this is enabled on unix, but disabled on mswindows
# since the normal setup on mswindows is to have the config file
# located with the base library dll for runtime configuration and
# use the environment variable to control the developer config file
# location (used by gnustep-make when building).
#-----------------------------------------------------------------
case "$target_os" in
    mingw*)	enable_env_config=no;;
    *)		enable_env_config=yes;;
esac
AC_MSG_CHECKING([whether the GNUstep.conf file path can be set in the environment])
AC_ARG_ENABLE(environment-config-file, 
[  --disable-environment-config-file
                                Disables the use of the GNUSTEP_CONFIG_FILE
				environment variable to specify/override
				the location of the GNUstep config file
				at runtime.  This option is occasionally
				useful to disable the environment variable
				for sites which wish to 'lock down' users
				to always work with a specific system-wide
				configuration.  On unix-like systems the
				default is for this option to be enabled.
				It is disabled by default on windows systems
				so that the base library will not use a
				config file intended for the gnustep-make
				system (and containing unix-style paths
				which cannot be used by widnows apps).
				Normally this should be left at its default
				setting.], 
  ac_cv_environment_config_file=$enableval,
  ac_cv_environment_config_file=$enable_env_config)
if test "$ac_cv_environment_config_file" = "yes"; then
  AC_DEFINE(OPTION_NO_ENVIRONMENT, 0,
    [Enable GNUSTEP_CONFIG_FILE environment variable])
  AC_MSG_RESULT([yes])
else
  AC_DEFINE(OPTION_NO_ENVIRONMENT, 1,
    [Disable GNUSTEP_CONFIG_FILE environment variable])
  AC_MSG_RESULT([no: disabled from the command-line])
fi

#--------------------------------------------------------------------
# We are not trying to determine the default GNUstep paths to be
# used at runtime.  So all GNUSTEP_xxx variables from now on are to be
# considered as 'runtime' ones.  They refer to paths that might not
# make any sense now, but might make sense once gnustep-base is
# installed in its final location.
#---------------------------------------------------------------------

#
# Set 'standard' defaults for values from configuration file.
#
case "$target_os" in
  *)
    GNUSTEP_SYSTEM_ROOT=/usr/GNUstep/System
    GNUSTEP_LOCAL_ROOT=/usr/GNUstep/Local
    GNUSTEP_NETWORK_ROOT=/usr/GNUstep/Local
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
# turn it off.
AC_MSG_CHECKING([if we should import an existing configuration file now])
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
[  --with-default-config=PATH   Specify path to a GNUstep config file to be
				imported at configure time (now) and used to
				provide default values for the base library
				to use at runtime if no GNUstep config file
				is found at runtime.  If this is not specified
				then the path from --with-config-file or from
				the gnustep-make package is used.],
    result="$withval",
    result="no"
  )
  if test "$result" != "no"
  then
    GNUSTEP_DEFAULT_CONFIG="$result"
  fi
  if test "$GNUSTEP_DEFAULT_CONFIG" = ""; then
    # No file to import has been specified.  We need to read the paths
    # from somewhere though!  GNUstep.sh might not have been sourced,
    # so at this stage we have no knowledge of what the paths must be.
    # The only place that we can read them from is the gnustep-make
    # GNUstep.conf file.
    # So we fall back to useing the make settings for the built-in ones.
    # However, on mingw these will be msys style paths, and we don't
    # want that ... so later on we convert these to portable relative
    # paths based on the directory in which the base library will be
    # installed.
    GNUSTEP_DEFAULT_CONFIG="$GNUSTEP_MAKE_CONFIG"
  fi
  AC_MSG_RESULT($GNUSTEP_DEFAULT_CONFIG)

  #
  # Only try importing if the default config file has been specified.
  #
  if test "$GNUSTEP_DEFAULT_CONFIG" != ""; then
    #
    # Use the default config file to override standard values.
    #
    if test ! -f "$GNUSTEP_DEFAULT_CONFIG"; then
      AC_MSG_RESULT([fail: file "$GNUSTEP_DEFAULT_CONFIG" does not exist])

      # Ohoh ... things are not going well.  We are asked to import
      # a config file that doesn't exist.  So all paths might be unset
      # and who knows what we'll end up hardcoding into gnustep-base.
      # It looks like we need to make sure the user knows what they
      # are doing, as there is a high chance they don't and might end
      # up with a confused/non-working system.  As far as we know, the
      # system might be already screwed.  If they don't want to import 
      # a config file (eg, they don't have one and they don't care about 
      # the hardcoded paths) they should just say so. ;-)
      AC_MSG_ERROR([Please run configure again with the --disable-importing-config-file option or specifying an alternative file using the --with-default-config= option])

    else
      AC_MSG_RESULT([trying to import "$GNUSTEP_DEFAULT_CONFIG"])
      AC_MSG_NOTICE([If this fails, please run configure again with the --disable-importing-config-file option or specifying an alternative file using the --with-default-config= option])
      . "$GNUSTEP_DEFAULT_CONFIG"
    fi
  fi
fi

# Now we have the problem of what to do if some of the paths were not
# set by GNUstep.conf (eg, old gnustep-make), or if no config file was
# read, or if the config file was corrupt.  We decide that the most
# likely case is an old gnustep-make, so by default we configure the
# other paths basing on GNUSTEP_*_ROOT.

# TODO/FIXME: We should really have better checks once the situation
# has stabilized.  This is a reasonable hack for now.

if test x"$GNUSTEP_MAKEFILES" = x""; then GNUSTEP_MAKEFILES=$GNUSTEP_SYSTEM_ROOT/Library/Makefiles; fi

if test x"$GNUSTEP_SYSTEM_USERS_DIR" = x""; then GNUSTEP_SYSTEM_USERS_DIR=/home; fi
if test x"$GNUSTEP_NETWORK_USERS_DIR" = x""; then GNUSTEP_NETWORK_USERS_DIR=/home; fi
if test x"$GNUSTEP_LOCAL_USERS_DIR" = x""; then GNUSTEP_LOCAL_USERS_DIR=/home; fi

if test x"$GNUSTEP_SYSTEM_APPS" = x""; then GNUSTEP_SYSTEM_APPS=$GNUSTEP_SYSTEM_ROOT/Applications; fi
if test x"$GNUSTEP_SYSTEM_ADMIN_APPS" = x""; then GNUSTEP_SYSTEM_ADMIN_APPS=$GNUSTEP_SYSTEM_ROOT/Applications/Admin; fi
if test x"$GNUSTEP_SYSTEM_WEB_APPS" = x""; then GNUSTEP_SYSTEM_WEB_APPS=$GNUSTEP_SYSTEM_ROOT/WebApplications; fi
if test x"$GNUSTEP_SYSTEM_TOOLS" = x""; then GNUSTEP_SYSTEM_TOOLS=$GNUSTEP_SYSTEM_ROOT/Tools; fi
if test x"$GNUSTEP_SYSTEM_ADMIN_TOOLS" = x""; then GNUSTEP_SYSTEM_ADMIN_TOOLS=$GNUSTEP_SYSTEM_ROOT/Tools/Admin; fi
if test x"$GNUSTEP_SYSTEM_LIBRARY" = x""; then GNUSTEP_SYSTEM_LIBRARY=$GNUSTEP_SYSTEM_ROOT/Library; fi
if test x"$GNUSTEP_SYSTEM_LIBRARIES" = x""; then GNUSTEP_SYSTEM_LIBRARIES=$GNUSTEP_SYSTEM_LIBRARY/Libraries; fi
if test x"$GNUSTEP_SYSTEM_HEADERS" = x""; then GNUSTEP_SYSTEM_HEADERS=$GNUSTEP_SYSTEM_LIBRARY/Headers; fi
if test x"$GNUSTEP_SYSTEM_DOC" = x""; then GNUSTEP_SYSTEM_DOC=$GNUSTEP_SYSTEM_LIBRARY/Documentation; fi
if test x"$GNUSTEP_SYSTEM_DOC_MAN" = x""; then GNUSTEP_SYSTEM_DOC_MAN=$GNUSTEP_SYSTEM_LIBRARY/Documentation/man; fi
if test x"$GNUSTEP_SYSTEM_DOC_INFO" = x""; then GNUSTEP_SYSTEM_DOC_INFO=$GNUSTEP_SYSTEM_LIBRARY/Documentation/info; fi

if test x"$GNUSTEP_NETWORK_APPS" = x""; then GNUSTEP_NETWORK_APPS=$GNUSTEP_NETWORK_ROOT/Applications; fi
if test x"$GNUSTEP_NETWORK_ADMIN_APPS" = x""; then GNUSTEP_NETWORK_ADMIN_APPS=$GNUSTEP_NETWORK_ROOT/Applications/Admin; fi
if test x"$GNUSTEP_NETWORK_WEB_APPS" = x""; then GNUSTEP_NETWORK_APPS=$GNUSTEP_NETWORK_ROOT/WebApplications; fi
if test x"$GNUSTEP_NETWORK_TOOLS" = x""; then GNUSTEP_NETWORK_TOOLS=$GNUSTEP_NETWORK_ROOT/Tools; fi
if test x"$GNUSTEP_NETWORK_ADMIN_TOOLS" = x""; then GNUSTEP_NETWORK_ADMIN_TOOLS=$GNUSTEP_NETWORK_ROOT/Tools/Admin; fi
if test x"$GNUSTEP_NETWORK_LIBRARY" = x""; then GNUSTEP_NETWORK_LIBRARY=$GNUSTEP_NETWORK_ROOT/Library; fi
if test x"$GNUSTEP_NETWORK_LIBRARIES" = x""; then GNUSTEP_NETWORK_LIBRARIES=$GNUSTEP_NETWORK_LIBRARY/Libraries; fi
if test x"$GNUSTEP_NETWORK_HEADERS" = x""; then GNUSTEP_NETWORK_HEADERS=$GNUSTEP_NETWORK_LIBRARY/Headers; fi
if test x"$GNUSTEP_NETWORK_DOC" = x""; then GNUSTEP_NETWORK_DOC=$GNUSTEP_NETWORK_LIBRARY/Documentation; fi
if test x"$GNUSTEP_NETWORK_DOC_MAN" = x""; then GNUSTEP_NETWORK_DOC_MAN=$GNUSTEP_NETWORK_LIBRARY/Documentation/man; fi
if test x"$GNUSTEP_NETWORK_DOC_INFO" = x""; then GNUSTEP_NETWORK_DOC_INFO=$GNUSTEP_NETWORK_LIBRARY/Documentation/info; fi

if test x"$GNUSTEP_LOCAL_APPS" = x""; then GNUSTEP_LOCAL_APPS=$GNUSTEP_LOCAL_ROOT/Applications; fi
if test x"$GNUSTEP_LOCAL_ADMIN_APPS" = x""; then GNUSTEP_LOCAL_ADMIN_APPS=$GNUSTEP_LOCAL_ROOT/Applications/Admin; fi
if test x"$GNUSTEP_LOCAL_WEB_APPS" = x""; then GNUSTEP_LOCAL_APPS=$GNUSTEP_LOCAL_ROOT/WebApplications; fi
if test x"$GNUSTEP_LOCAL_TOOLS" = x""; then GNUSTEP_LOCAL_TOOLS=$GNUSTEP_LOCAL_ROOT/Tools; fi
if test x"$GNUSTEP_LOCAL_ADMIN_TOOLS" = x""; then GNUSTEP_LOCAL_ADMIN_TOOLS=$GNUSTEP_LOCAL_ROOT/Tools/Admin; fi
if test x"$GNUSTEP_LOCAL_LIBRARY" = x""; then GNUSTEP_LOCAL_LIBRARY=$GNUSTEP_LOCAL_ROOT/Library; fi
if test x"$GNUSTEP_LOCAL_LIBRARIES" = x""; then GNUSTEP_LOCAL_LIBRARIES=$GNUSTEP_LOCAL_LIBRARY/Libraries; fi
if test x"$GNUSTEP_LOCAL_HEADERS" = x""; then GNUSTEP_LOCAL_HEADERS=$GNUSTEP_LOCAL_LIBRARY/Headers; fi
if test x"$GNUSTEP_LOCAL_DOC" = x""; then GNUSTEP_LOCAL_DOC=$GNUSTEP_LOCAL_LIBRARY/Documentation; fi
if test x"$GNUSTEP_LOCAL_DOC_MAN" = x""; then GNUSTEP_LOCAL_DOC_MAN=$GNUSTEP_LOCAL_LIBRARY/Documentation/man; fi
if test x"$GNUSTEP_LOCAL_DOC_INFO" = x""; then GNUSTEP_LOCAL_DOC_INFO=$GNUSTEP_LOCAL_LIBRARY/Documentation/info; fi

if test x"$GNUSTEP_USER_DIR_APPS" = x""; then GNUSTEP_USER_DIR_APPS=$GNUSTEP_USER_DIR/Applications; fi
if test x"$GNUSTEP_USER_DIR_ADMIN_APPS" = x""; then GNUSTEP_USER_DIR_ADMIN_APPS=$GNUSTEP_USER_DIR/Applications/Admin; fi
if test x"$GNUSTEP_USER_DIR_WEB_APPS" = x""; then GNUSTEP_USER_DIR_APPS=$GNUSTEP_USER_DIR/WebApplications; fi
if test x"$GNUSTEP_USER_DIR_TOOLS" = x""; then GNUSTEP_USER_DIR_TOOLS=$GNUSTEP_USER_DIR/Tools; fi
if test x"$GNUSTEP_USER_DIR_ADMIN_TOOLS" = x""; then GNUSTEP_USER_DIR_ADMIN_TOOLS=$GNUSTEP_USER_DIR/Tools/Admin; fi
if test x"$GNUSTEP_USER_DIR_LIBRARY" = x""; then GNUSTEP_USER_DIR_LIBRARY=$GNUSTEP_USER_DIR/Library; fi
if test x"$GNUSTEP_USER_DIR_LIBRARIES" = x""; then GNUSTEP_USER_DIR_LIBRARIES=$GNUSTEP_USER_DIR/Libraries; fi
if test x"$GNUSTEP_USER_DIR_HEADERS" = x""; then GNUSTEP_USER_DIR_HEADERS=$GNUSTEP_USER_DIR/Headers; fi
if test x"$GNUSTEP_USER_DIR_DOC" = x""; then GNUSTEP_USER_DIR_DOC=$GNUSTEP_USER_DIR/Documentation; fi
if test x"$GNUSTEP_USER_DIR_DOC_MAN" = x""; then GNUSTEP_USER_DIR_DOC_MAN=$GNUSTEP_USER_DIR/Documentation/man; fi
if test x"$GNUSTEP_USER_DIR_DOC_INFO" = x""; then GNUSTEP_USER_DIR_DOC_INFO=$GNUSTEP_USER_DIR/Documentation/info; fi

AC_MSG_CHECKING([for GNUstep-base installation domain])
AC_ARG_WITH(installation-domain,
[  --with-installation-domain=DOMAIN
				Specify the domain (SYSTEM, LOCAL,
				NETWORK or USER) into which
				gnustep-base will be installed.
				Whenever relative paths are hardcoded
				into gnustep-base (at the moment, this
				happens only on MinGW) this option
				must be used and must match the domain
				where you will be installing
				gnustep-base.
				If this is not specified, the output of
				gnustep-config --installation-domain-for=gnustep-base
				(which should normally be LOCAL) is used.],
  result="$withval",
  result="no"
)
if test "$result" = "no"
then
  # Check if gnustep-config supports the option
  # --installation-domain-for, and use it if available.  That option
  # will automatically use the shell variable GNUSTEP_INSTALLATION_DOMAIN or
  # the installation-domains.conf files (or the LOCAL default) as appropriate.
  # Otherwise, if that option is not available just fall back to
  # using GNUSTEP_INSTALLATION_DOMAIN or (if that was not defiend) LOCAL.
  if (gnustep-config --help | grep installation-domain) >&5 2>&5
  then
    result=`gnustep-config --installation-domain-for=gnustep-base 2>&5`
  else
    AC_MSG_WARN([The 'gnustep-config' script was not found or out of date.])
    result=$GNUSTEP_INSTALLATION_DOMAIN
    if test "$result" = ""
    then
      # This case was added on December 2008 and is only for backwards
      # compatibility with older versions of gnustep-make.
      result=LOCAL
    fi
  fi
fi
case "$result" in
  SYSTEM)
    AC_MSG_RESULT([SYSTEM])
    GNUSTEP_BASE_PATH="$GNUSTEP_SYSTEM_TOOLS";;
  LOCAL)
    AC_MSG_RESULT([LOCAL])
    GNUSTEP_BASE_PATH="$GNUSTEP_LOCAL_TOOLS";;
  NETWORK)
    AC_MSG_RESULT([NETWORK])
    GNUSTEP_BASE_PATH="$GNUSTEP_NETWORK_TOOLS";;
  USER)
    AC_MSG_RESULT([USER])
    GNUSTEP_BASE_PATH="$GNUSTEP_USER_TOOLS";;
  *)
    AC_MSG_ERROR([Unknown installation domain '$result' (it should be SYSTEM, LOCAL, NETWORK or USER).  Please run configure again with the option --with-installation-domain=LOCAL (or whatever domain you want to install into).])
    exit 1;;
esac
# We store GNUSTEP_BASE_DOMAIN in config.mak so that we can check
# at runtime and make sure it is consistent with the
# GNUSTEP_INSTALLATION_DOMAIN that is used at runtime.
GNUSTEP_BASE_DOMAIN=$result
AC_SUBST(GNUSTEP_BASE_DOMAIN)

#
# If we are on mingw, we now want to convert the paths to relative
# paths (relative to libgnustep-base.dll).
#
case "$target_os" in
  mingw*)
    # TODO: Improve this hack.
    # According to Wikipedia, this is the default for Windows 2000,
    # Windows XP and Windows Server 2003.  For Windows Vista this will
    # change to C:\Users.  The directory name needs to be localized though
    # (and the disk may need changing as well ?).
    GNUSTEP_SYSTEM_USERS_DIR="C:\Documents and Settings"
    GNUSTEP_NETWORK_USERS_DIR="C:\Documents and Settings"
    GNUSTEP_LOCAL_USERS_DIR="C:\Documents and Settings"

    # TODO: It would be nice to use the 'short' output of
    # relative_path.sh, but older versions of relative_path.sh
    # did not support specifying the type of output and
    # would abort if they were given more than 2 parameters,
    # so we can not use the 'short' option if we want gnustep-base
    # to work with older versions of gnustep-make.
    # Once everyone has upgraded to gnustep-make >= 2.0.5 (I'd say
    # two years after it has been released ?), we could switch to the 
    # 'short' output though.
    GNUSTEP_SYSTEM_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_APPS`
    GNUSTEP_SYSTEM_ADMIN_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_ADMIN_APPS`
    GNUSTEP_SYSTEM_WEB_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_WEB_APPS`
    GNUSTEP_SYSTEM_TOOLS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_TOOLS`
    GNUSTEP_SYSTEM_ADMIN_TOOLS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_ADMIN_TOOLS`
    GNUSTEP_SYSTEM_LIBRARY=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_LIBRARY`
    GNUSTEP_SYSTEM_LIBRARIES=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_LIBRARIES`
    GNUSTEP_SYSTEM_HEADERS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_HEADERS`
    GNUSTEP_SYSTEM_DOC=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_DOC`
    GNUSTEP_SYSTEM_DOC_MAN=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_DOC_MAN`
    GNUSTEP_SYSTEM_DOC_INFO=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_SYSTEM_DOC_INFO`

    GNUSTEP_NETWORK_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_APPS`
    GNUSTEP_NETWORK_ADMIN_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_ADMIN_APPS`
    GNUSTEP_NETWORK_WEB_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_WEB_APPS`
    GNUSTEP_NETWORK_TOOLS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_TOOLS`
    GNUSTEP_NETWORK_ADMIN_TOOLS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_ADMIN_TOOLS`
    GNUSTEP_NETWORK_LIBRARY=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_LIBRARY`
    GNUSTEP_NETWORK_LIBRARIES=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_LIBRARIES`
    GNUSTEP_NETWORK_HEADERS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_HEADERS`
    GNUSTEP_NETWORK_DOC=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_DOC`
    GNUSTEP_NETWORK_DOC_MAN=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_DOC_MAN`
    GNUSTEP_NETWORK_DOC_INFO=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_NETWORK_DOC_INFO`

    GNUSTEP_LOCAL_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_APPS`
    GNUSTEP_LOCAL_ADMIN_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_ADMIN_APPS`
    GNUSTEP_LOCAL_WEB_APPS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_WEB_APPS`
    GNUSTEP_LOCAL_TOOLS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_TOOLS`
    GNUSTEP_LOCAL_ADMIN_TOOLS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_ADMIN_TOOLS`
    GNUSTEP_LOCAL_LIBRARY=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_LIBRARY`
    GNUSTEP_LOCAL_LIBRARIES=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_LIBRARIES`
    GNUSTEP_LOCAL_HEADERS=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_HEADERS`
    GNUSTEP_LOCAL_DOC=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_DOC`
    GNUSTEP_LOCAL_DOC_MAN=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_DOC_MAN`
    GNUSTEP_LOCAL_DOC_INFO=`$GNUSTEP_MAKEFILES/relative_path.sh $GNUSTEP_BASE_PATH $GNUSTEP_LOCAL_DOC_INFO`
# It would be nice to now store this stuff into a ./GNUstep.conf file
# installed with gnustep-base.dll.  This would clarify.
    ;;
esac

GNUSTEP_BASE_RELATIVE_PATHS=no

# Now, check if any of the paths is a relative path.
for path in \
 "$GNUSTEP_SYSTEM_APPS" "$GNUSTEP_SYSTEM_ADMIN_APPS" "$GNUSTEP_SYSTEM_WEB_APPS" \
 "$GNUSTEP_SYSTEM_TOOLS" "$GNUSTEP_SYSTEM_ADMIN_TOOLS" \
 "$GNUSTEP_SYSTEM_LIBRARY" "$GNUSTEP_SYSTEM_LIBRARIES" "$GNUSTEP_SYSTEM_HEADERS" \
 "$GNUSTEP_SYSTEM_DOC" "$GNUSTEP_SYSTEM_DOC_MAN" "$GNUSTEP_SYSTEM_DOC_INFO" \
 "$GNUSTEP_NETWORK_APPS" "$GNUSTEP_NETWORK_ADMIN_APPS" "$GNUSTEP_NETWORK_WEB_APPS" \
 "$GNUSTEP_NETWORK_TOOLS" "$GNUSTEP_NETWORK_ADMIN_TOOLS" \
 "$GNUSTEP_NETWORK_LIBRARY" "$GNUSTEP_NETWORK_LIBRARIES" "$GNUSTEP_NETWORK_HEADERS" \
 "$GNUSTEP_NETWORK_DOC" "$GNUSTEP_NETWORK_DOC_MAN" "$GNUSTEP_NETWORK_DOC_INFO" \
 "$GNUSTEP_LOCAL_APPS" "$GNUSTEP_LOCAL_ADMIN_APPS" "$GNUSTEP_LOCAL_WEB_APPS" \
 "$GNUSTEP_LOCAL_TOOLS" "$GNUSTEP_LOCAL_ADMIN_TOOLS" \
 "$GNUSTEP_LOCAL_LIBRARY" "$GNUSTEP_LOCAL_LIBRARIES" "$GNUSTEP_LOCAL_HEADERS" \
 "$GNUSTEP_LOCAL_DOC" "$GNUSTEP_LOCAL_DOC_MAN" "$GNUSTEP_LOCAL_DOC_INFO"; do
case "$path" in
  ./*)  GNUSTEP_BASE_RELATIVE_PATHS=yes ;;
  ../*) GNUSTEP_BASE_RELATIVE_PATHS=yes ;;
esac
done

AC_MSG_CHECKING([if we are hardcoding any relative paths in gnustep-base])
AC_MSG_RESULT($GNUSTEP_BASE_RELATIVE_PATHS)
AC_SUBST(GNUSTEP_BASE_RELATIVE_PATHS)

#
# Now, we want to print out the paths that we're going to hardcode
# into gnustep-base.  This is to help users in finding
# misconfigurations.
#
AC_MSG_NOTICE([We store the following filesystem layout into gnustep-base, to be used when no config file is found])
AC_MSG_CHECKING([for Makefiles directory])
AC_MSG_RESULT($GNUSTEP_MAKEFILES)
AC_MSG_CHECKING([for user defaults directory])
AC_MSG_RESULT($GNUSTEP_USER_DEFAULTS_DIR)
AC_MSG_CHECKING([for user config file])
AC_MSG_RESULT($GNUSTEP_USER_CONFIG_FILE)

AC_MSG_CHECKING([for System Applications directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_APPS)
AC_MSG_CHECKING([for System Admin Applications directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_ADMIN_APPS)
AC_MSG_CHECKING([for System Web Applications directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_WEB_APPS)
AC_MSG_CHECKING([for System Tools directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_TOOLS)
AC_MSG_CHECKING([for System Admin Tools directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_ADMIN_TOOLS)
AC_MSG_CHECKING([for System Library directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_LIBRARY)
AC_MSG_CHECKING([for System Libraries directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_LIBRARIES)
AC_MSG_CHECKING([for System Headers directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_HEADERS)
AC_MSG_CHECKING([for System Documentation directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_DOC)
AC_MSG_CHECKING([for System Info Documentation directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_DOC_INFO)
AC_MSG_CHECKING([for System Man Documentation directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_DOC_MAN)

AC_MSG_CHECKING([for Network Applications directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_APPS)
AC_MSG_CHECKING([for Network Admin Applications directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_ADMIN_APPS)
AC_MSG_CHECKING([for Network Web Applications directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_WEB_APPS)
AC_MSG_CHECKING([for Network Tools directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_TOOLS)
AC_MSG_CHECKING([for Network Admin Tools directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_ADMIN_TOOLS)
AC_MSG_CHECKING([for Network Library directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_LIBRARY)
AC_MSG_CHECKING([for Network Libraries directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_LIBRARIES)
AC_MSG_CHECKING([for Network Headers directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_HEADERS)
AC_MSG_CHECKING([for Network Documentation directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_DOC)
AC_MSG_CHECKING([for Network Info Documentation directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_DOC_INFO)
AC_MSG_CHECKING([for Network Man Documentation directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_DOC_MAN)

AC_MSG_CHECKING([for Local Applications directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_APPS)
AC_MSG_CHECKING([for Local Admin Applications directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_ADMIN_APPS)
AC_MSG_CHECKING([for Local Web Applications directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_WEB_APPS)
AC_MSG_CHECKING([for Local Tools directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_TOOLS)
AC_MSG_CHECKING([for Local Admin Tools directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_ADMIN_TOOLS)
AC_MSG_CHECKING([for Local Library directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_LIBRARY)
AC_MSG_CHECKING([for Local Libraries directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_LIBRARIES)
AC_MSG_CHECKING([for Local Headers directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_HEADERS)
AC_MSG_CHECKING([for Local Documentation directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_DOC)
AC_MSG_CHECKING([for Local Info Documentation directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_DOC_INFO)
AC_MSG_CHECKING([for Local Man Documentation directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_DOC_MAN)

AC_MSG_CHECKING([for User Applications directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_APPS)
AC_MSG_CHECKING([for User Admin Applications directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_ADMIN_APPS)
AC_MSG_CHECKING([for User Web Applications directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_WEB_APPS)
AC_MSG_CHECKING([for User Tools directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_TOOLS)
AC_MSG_CHECKING([for User Admin Tools directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_ADMIN_TOOLS)
AC_MSG_CHECKING([for User Library directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_LIBRARY)
AC_MSG_CHECKING([for User Libraries directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_LIBRARIES)
AC_MSG_CHECKING([for User Headers directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_HEADERS)
AC_MSG_CHECKING([for User Documentation directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_DOC)
AC_MSG_CHECKING([for User Info Documentation directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_DOC_INFO)
AC_MSG_CHECKING([for User Man Documentation directory])
AC_MSG_RESULT($GNUSTEP_USER_DIR_DOC_MAN)

AC_MSG_CHECKING([for System User directory])
AC_MSG_RESULT($GNUSTEP_SYSTEM_USERS_DIR)
AC_MSG_CHECKING([for Network User directory])
AC_MSG_RESULT($GNUSTEP_NETWORK_USERS_DIR)
AC_MSG_CHECKING([for Local User directory])
AC_MSG_RESULT($GNUSTEP_LOCAL_USERS_DIR)

#
# Set the default configuration file values in pathconfig.h to be hard-coded
# into NSPathUtilities.m
#
GNUSTEP_MAKEFILES=`echo $GNUSTEP_MAKEFILES|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_MAKEFILES,
  "$GNUSTEP_MAKEFILES",
  [Built in default value for GNUstep Makefiles])
GNUSTEP_USER_DEFAULTS_DIR=`echo $GNUSTEP_USER_DEFAULTS_DIR|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DEFAULTS_DIR,
  "$GNUSTEP_USER_DEFAULTS_DIR",
  [Built in default value for GNUstep user defaults directory])
GNUSTEP_USER_CONFIG_FILE=`echo $GNUSTEP_USER_CONFIG_FILE|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_CONFIG_FILE,
  "$GNUSTEP_USER_CONFIG_FILE",
  [Built in default value for GNUstep user config file])
GNUSTEP_CONFIG_FILE=`echo $GNUSTEP_CONFIG_FILE|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_CONFIG_FILE,
  "$GNUSTEP_CONFIG_FILE",
  [Built in default value for GNUstep config file])

#
# SYSTEM domain paths
#
GNUSTEP_SYSTEM_APPS=`echo $GNUSTEP_SYSTEM_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_APPS,
  "$GNUSTEP_SYSTEM_APPS",
  [Built in default value for GNUstep system apps])

GNUSTEP_SYSTEM_ADMIN_APPS=`echo $GNUSTEP_SYSTEM_ADMIN_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_ADMIN_APPS,
  "$GNUSTEP_SYSTEM_ADMIN_APPS",
  [Built in default value for GNUstep system apps])

GNUSTEP_SYSTEM_WEB_APPS=`echo $GNUSTEP_SYSTEM_WEB_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_WEB_APPS,
  "$GNUSTEP_SYSTEM_WEB_APPS",
  [Built in default value for GNUstep web apps])

GNUSTEP_SYSTEM_TOOLS=`echo $GNUSTEP_SYSTEM_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_TOOLS,
  "$GNUSTEP_SYSTEM_TOOLS",
  [Built in default value for GNUstep system tools])

GNUSTEP_SYSTEM_ADMIN_TOOLS=`echo $GNUSTEP_SYSTEM_ADMIN_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_ADMIN_TOOLS,
  "$GNUSTEP_SYSTEM_ADMIN_TOOLS",
  [Built in default value for GNUstep system tools])

GNUSTEP_SYSTEM_LIBRARY=`echo $GNUSTEP_SYSTEM_LIBRARY|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_LIBRARY,
  "$GNUSTEP_SYSTEM_LIBRARY",
  [Built in default value for GNUstep system library])

GNUSTEP_SYSTEM_LIBRARIES=`echo $GNUSTEP_SYSTEM_LIBRARIES|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_LIBRARIES,
  "$GNUSTEP_SYSTEM_LIBRARIES",
  [Built in default value for GNUstep system libraries])

GNUSTEP_SYSTEM_HEADERS=`echo $GNUSTEP_SYSTEM_HEADERS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_HEADERS,
  "$GNUSTEP_SYSTEM_HEADERS",
  [Built in default value for GNUstep system headers])

GNUSTEP_SYSTEM_DOC=`echo $GNUSTEP_SYSTEM_DOC|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_DOC,
  "$GNUSTEP_SYSTEM_DOC",
  [Built in default value for GNUstep system documentation])

GNUSTEP_SYSTEM_DOC_MAN=`echo $GNUSTEP_SYSTEM_DOC_MAN|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_DOC_MAN,
  "$GNUSTEP_SYSTEM_DOC_MAN",
  [Built in default value for GNUstep system manpages documentation])

GNUSTEP_SYSTEM_DOC_INFO=`echo $GNUSTEP_SYSTEM_DOC_INFO|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_DOC_INFO,
  "$GNUSTEP_SYSTEM_DOC_INFO",
  [Built in default value for GNUstep system info documentation])

#
# NETWORK domain paths
#
GNUSTEP_NETWORK_APPS=`echo $GNUSTEP_NETWORK_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_APPS,
  "$GNUSTEP_NETWORK_APPS",
  [Built in default value for GNUstep network apps])

GNUSTEP_NETWORK_ADMIN_APPS=`echo $GNUSTEP_NETWORK_ADMIN_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_ADMIN_APPS,
  "$GNUSTEP_NETWORK_ADMIN_APPS",
  [Built in default value for GNUstep network apps])

GNUSTEP_NETWORK_WEB_APPS=`echo $GNUSTEP_NETWORK_WEB_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_WEB_APPS,
  "$GNUSTEP_NETWORK_WEB_APPS",
  [Built in default value for GNUstep network web apps])

GNUSTEP_NETWORK_TOOLS=`echo $GNUSTEP_NETWORK_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_TOOLS,
  "$GNUSTEP_NETWORK_TOOLS",
  [Built in default value for GNUstep network tools])

GNUSTEP_NETWORK_ADMIN_TOOLS=`echo $GNUSTEP_NETWORK_ADMIN_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_ADMIN_TOOLS,
  "$GNUSTEP_NETWORK_ADMIN_TOOLS",
  [Built in default value for GNUstep system tools])

GNUSTEP_NETWORK_LIBRARY=`echo $GNUSTEP_NETWORK_LIBRARY|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_LIBRARY,
  "$GNUSTEP_NETWORK_LIBRARY",
  [Built in default value for GNUstep network library])

GNUSTEP_NETWORK_LIBRARIES=`echo $GNUSTEP_NETWORK_LIBRARIES|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_LIBRARIES,
  "$GNUSTEP_NETWORK_LIBRARIES",
  [Built in default value for GNUstep network libraries])

GNUSTEP_NETWORK_HEADERS=`echo $GNUSTEP_NETWORK_HEADERS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_HEADERS,
  "$GNUSTEP_NETWORK_HEADERS",
  [Built in default value for GNUstep network headers])

GNUSTEP_NETWORK_DOC=`echo $GNUSTEP_NETWORK_DOC|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_DOC,
  "$GNUSTEP_NETWORK_DOC",
  [Built in default value for GNUstep network documentation])

GNUSTEP_NETWORK_DOC_MAN=`echo $GNUSTEP_NETWORK_DOC_MAN|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_DOC_MAN,
  "$GNUSTEP_NETWORK_DOC_MAN",
  [Built in default value for GNUstep network manpages documentation])

GNUSTEP_NETWORK_DOC_INFO=`echo $GNUSTEP_NETWORK_DOC_INFO|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_DOC_INFO,
  "$GNUSTEP_NETWORK_DOC_INFO",
  [Built in default value for GNUstep network info documentation])

#
# LOCAL domain paths
#
GNUSTEP_LOCAL_APPS=`echo $GNUSTEP_LOCAL_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_APPS,
  "$GNUSTEP_LOCAL_APPS",
  [Built in default value for GNUstep local apps])

GNUSTEP_LOCAL_ADMIN_APPS=`echo $GNUSTEP_LOCAL_ADMIN_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_ADMIN_APPS,
  "$GNUSTEP_LOCAL_ADMIN_APPS",
  [Built in default value for GNUstep local apps])

GNUSTEP_LOCAL_WEB_APPS=`echo $GNUSTEP_LOCAL_WEB_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_WEB_APPS,
  "$GNUSTEP_LOCAL_WEB_APPS",
  [Built in default value for GNUstep local web apps])

GNUSTEP_LOCAL_TOOLS=`echo $GNUSTEP_LOCAL_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_TOOLS,
  "$GNUSTEP_LOCAL_TOOLS",
  [Built in default value for GNUstep local tools])

GNUSTEP_LOCAL_ADMIN_TOOLS=`echo $GNUSTEP_LOCAL_ADMIN_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_ADMIN_TOOLS,
  "$GNUSTEP_LOCAL_ADMIN_TOOLS",
  [Built in default value for GNUstep local tools])

GNUSTEP_LOCAL_LIBRARY=`echo $GNUSTEP_LOCAL_LIBRARY|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_LIBRARY,
  "$GNUSTEP_LOCAL_LIBRARY",
  [Built in default value for GNUstep local library])

GNUSTEP_LOCAL_LIBRARIES=`echo $GNUSTEP_LOCAL_LIBRARIES|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_LIBRARIES,
  "$GNUSTEP_LOCAL_LIBRARIES",
  [Built in default value for GNUstep local libraries])

GNUSTEP_LOCAL_HEADERS=`echo $GNUSTEP_LOCAL_HEADERS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_HEADERS,
  "$GNUSTEP_LOCAL_HEADERS",
  [Built in default value for GNUstep local headers])

GNUSTEP_LOCAL_DOC=`echo $GNUSTEP_LOCAL_DOC|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_DOC,
  "$GNUSTEP_LOCAL_DOC",
  [Built in default value for GNUstep local documentation])

GNUSTEP_LOCAL_DOC_MAN=`echo $GNUSTEP_LOCAL_DOC_MAN|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_DOC_MAN,
  "$GNUSTEP_LOCAL_DOC_MAN",
  [Built in default value for GNUstep local manpages documentation])

GNUSTEP_LOCAL_DOC_INFO=`echo $GNUSTEP_LOCAL_DOC_INFO|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_DOC_INFO,
  "$GNUSTEP_LOCAL_DOC_INFO",
  [Built in default value for GNUstep local info documentation])

#
# USER_DIR domain paths
#
GNUSTEP_USER_DIR_APPS=`echo $GNUSTEP_USER_DIR_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_APPS,
  "$GNUSTEP_USER_DIR_APPS",
  [Built in default value for GNUstep user_dir apps])

GNUSTEP_USER_DIR_ADMIN_APPS=`echo $GNUSTEP_USER_DIR_ADMIN_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_ADMIN_APPS,
  "$GNUSTEP_USER_DIR_ADMIN_APPS",
  [Built in default value for GNUstep user_dir admin apps])

GNUSTEP_USER_DIR_WEB_APPS=`echo $GNUSTEP_USER_DIR_WEB_APPS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_WEB_APPS,
  "$GNUSTEP_USER_DIR_WEB_APPS",
  [Built in default value for GNUstep user_dir web apps])

GNUSTEP_USER_DIR_TOOLS=`echo $GNUSTEP_USER_DIR_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_TOOLS,
  "$GNUSTEP_USER_DIR_TOOLS",
  [Built in default value for GNUstep user_dir tools])

GNUSTEP_USER_DIR_ADMIN_TOOLS=`echo $GNUSTEP_USER_DIR_ADMIN_TOOLS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_ADMIN_TOOLS,
  "$GNUSTEP_USER_DIR_ADMIN_TOOLS",
  [Built in default value for GNUstep user_dir tools])

GNUSTEP_USER_DIR_LIBRARY=`echo $GNUSTEP_USER_DIR_LIBRARY|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_LIBRARY,
  "$GNUSTEP_USER_DIR_LIBRARY",
  [Built in default value for GNUstep user_dir library])

GNUSTEP_USER_DIR_LIBRARIES=`echo $GNUSTEP_USER_DIR_LIBRARIES|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_LIBRARIES,
  "$GNUSTEP_USER_DIR_LIBRARIES",
  [Built in default value for GNUstep user_dir libraries])

GNUSTEP_USER_DIR_HEADERS=`echo $GNUSTEP_USER_DIR_HEADERS|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_HEADERS,
  "$GNUSTEP_USER_DIR_HEADERS",
  [Built in default value for GNUstep user_dir headers])

GNUSTEP_USER_DIR_DOC=`echo $GNUSTEP_USER_DIR_DOC|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_DOC,
  "$GNUSTEP_USER_DIR_DOC",
  [Built in default value for GNUstep user_dir documentation])

GNUSTEP_USER_DIR_DOC_MAN=`echo $GNUSTEP_USER_DIR_DOC_MAN|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_DOC_MAN,
  "$GNUSTEP_USER_DIR_DOC_MAN",
  [Built in default value for GNUstep user_dir manpages documentation])

GNUSTEP_USER_DIR_DOC_INFO=`echo $GNUSTEP_USER_DIR_DOC_INFO|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_USER_DIR_DOC_INFO,
  "$GNUSTEP_USER_DIR_DOC_INFO",
  [Built in default value for GNUstep user_dir info documentation])

GNUSTEP_TARGET_SYSTEM_USERS_DIR=`echo $GNUSTEP_TARGET_SYSTEM_USERS_DIR|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_SYSTEM_USERS_DIR,
  "$GNUSTEP_TARGET_SYSTEM_USERS_DIR",
  [Built in default value for GNUstep System Users directory])
GNUSTEP_TARGET_NETWORK_USERS_DIR=`echo $GNUSTEP_TARGET_NETWORK_USERS_DIR|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_NETWORK_USERS_DIR,
  "$GNUSTEP_TARGET_NETWORK_USERS_DIR",
  [Built in default value for GNUstep Network Users directory])
GNUSTEP_TARGET_LOCAL_USERS_DIR=`echo $GNUSTEP_TARGET_LOCAL_USERS_DIR|sed -e 's/\\\\/\\\\\\\\/g'`
AC_DEFINE_UNQUOTED(GNUSTEP_TARGET_LOCAL_USERS_DIR,
  "$GNUSTEP_TARGET_LOCAL_USERS_DIR",
  [Built in default value for GNUstep Local Users directory])


AC_CONFIG_FILES([pathconfig.mak])
AC_OUTPUT
