#!/usr/grads/bin/bash

# Apply a patch and automatically RCS check-in the changed files if
# the patch succeeds.

# Usage: patch.sh -p1 < ~/Mail/inbox/120

cd /u/mccallum/collection/libobjects
touch .patch.timestamp
if patch --batch $*; then
  find . -name '*.orig' -exec mv -f {} ../origs \;
  rm -f .patched.files
  find . -name RCS -prune -o \
    \( -newer .patch.timestamp -type f -print \) \
    | grep -v .patched.files > .patched.files
  echo PATCH SUCCEEDED!
  echo Patched files:
  cat .patched.files
  ci -u -m"Patched from mail.  See ChangeLog" \
    -t-"Patched from mail.  See ChangeLog" \
    `cat .patched.files`
else
  echo PATCH FAILED!
  echo patch.sh: patch failed - reject files are:
  find . -newer .patch.timestamp -name '*.rej' -print
  exit 1
fi
