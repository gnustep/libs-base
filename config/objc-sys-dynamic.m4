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
	      AC_DEFINE(HAVE_DLADDR,, [Define if you have dladdr]))
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
