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

# NB: This is used as follows: in Source/Makefile.postamble we copy
# $(DYNAMIC_LINKER)-load.h into dynamic-load.h
AC_MSG_CHECKING([for dynamic linker type])
AC_MSG_RESULT([$DYNAMIC_LINKER])

if test $DYNAMIC_LINKER = simple; then
  AC_MSG_CHECKING([checking if dladdr() is available])
  old_LDFLAGS="$LDFLAGS"
  case "$target_os" in
    linux-gnu*) LDFLAGS="$old_LDFLAGS -ldl";;
    solaris*) LDFLAGS="$old_LDFLAGS -ldl";;
    sysv4.2*) LDFLAGS="$old_LDFLAGS -ldl";;
  esac
  AC_TRY_LINK([#include <dlfcn.h>], dladdr(0,0);, 
	      AC_DEFINE(HAVE_DLADDR,1, [Define if you have dladdr])
	      AC_MSG_RESULT([yes]),
	      AC_MSG_RESULT([no]))
  LDFLAGS="$old_LDFLAGS"
fi

AC_SUBST(DYNAMIC_LINKER)dnl
])
