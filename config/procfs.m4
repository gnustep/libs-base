dnl AC_SYS_PROCFS
dnl This macro defines HAVE_PROCFS if either it finds a mounted /proc
dnl or the user explicitly enables it for cross-compiles.
AC_DEFUN(AC_SYS_PROCFS,
[ AC_ARG_ENABLE(procfs,
    [  --enable-procfs               Use /proc filesystem (default)],
    enable_procfs="$enableval", if test "$cross_compiling" = yes; then enable_procfs=cross; else enable_procfs=yes; fi;)

  AC_CACHE_CHECK([kernel support for /proc filesystem], ac_cv_sys_procfs,
  [if test "$enable_procfs" = yes; then
  # Suggested change for the following line was 
  #  if test -d /proc/0; then
  # but it doesn't work on my linux - /proc/0 does not exist, but /proc
  # works fine
    if (grep proc /etc/fstab >/dev/null 2>/dev/null); then 
      ac_cv_sys_procfs=yes
	# Solaris has proc, but for some reason the dir is not readable
	# 	elif (grep proc /etc/vfstab >/dev/null 2>/dev/null); then 
	# ac_cv_sys_procfs=yes
    else
      ac_cv_sys_procfs=no
    fi
  elif test "$enable_procfs" = cross; then
    AC_MSG_WARN(Pass --enable-procfs argument to enable use of /proc filesystem.)
  else
    ac_cv_sys_procfs=no
  fi])

  if test $ac_cv_sys_procfs = yes; then
    AC_DEFINE(HAVE_PROCFS, 1, [Define if system supports the /proc filesystem])
  fi
]
)
