dnl AC_SYS_PROCFS
dnl This macro defines HAVE_PROCFS if either it finds a mounted /proc
dnl or the user explicitly enables it for cross-compiles.
AC_DEFUN(AC_SYS_PROCFS,
[ AC_ARG_WITH(enable_procfs,
    [  --enable-procfs               Use /proc filesystem (default)],
    enable_procfs="$enableval", if test "$cross_compiling" = yes; then enable_procfs=cross; else enable_procfs=yes; fi;)

  AC_CACHE_CHECK([kernel support for /proc filesystem], ac_cv_sys_procfs,
  [if test "$enable_procfs" = yes; then
    dnl Check whether /proc is mounted and readable by checking the entry
    dnl for process number 1, which every system should have.
    if test -d /proc/1; then
      ac_cv_sys_procfs=yes
    else
      ac_cv_sys_procfs=no
    fi
  elif test "$enable_procfs" = cross; then
    AC_MSG_WARN(Pass --enable-procfs argument to enable use of /proc filesystem.)
  fi])

  if test $ac_cv_sys_procfs = yes; then
    AC_DEFINE(HAVE_PROCFS, 1, [Define if system supports the /proc filesystem])
  fi
]
)
