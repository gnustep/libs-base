dnl AC_PROG_NEXTCC
dnl Check for NeXT compiler.
AC_DEFUN(AC_PROG_NEXTCC,
[ AC_CACHE_CHECK(whether we are using the NeXT compiler, ac_prog_nextcc,
    [AC_EGREP_CPP(yes,
[#if defined(NeXT)
  #if defined(_NEXT_SOURCE)
    no
  #else
    yes
  #endif
#else
  no
#endif], ac_prog_nextcc=yes, ac_prog_nextcc=no)])

  if test "$ac_prog_nextcc" = yes; then
    NeXTCC=yes
  fi
])
