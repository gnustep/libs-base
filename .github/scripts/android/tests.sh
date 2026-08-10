#!/bin/bash
#
# Deploy libs-base and its test suite to a connected Android device and run it.
#
# The deployment rules are the substance here.  base finds its resources
# relative to the EXECUTABLE, tests launch helper tools and load bundles by
# path, several read their own source back, and a leftover helper from a killed
# run holds the port.  Getting any of that wrong loses coverage silently rather
# than failing, so the summary reports files that produced no result at all.
#
set -eu
trap 'rc=$?; echo "runner stopped: rc=$rc at: $BASH_COMMAND" >&2' EXIT
PS4='+ [${LINENO}] '
set -x

: "${ANDROID_NDK_HOME:?}"
: "${GS_PREFIX:?}"
: "${GS_BASE:?}"
: "${GS_API:=31}"
: "${GS_TRIPLE:=x86_64-linux-android}"
GS_DISPATCH_PREFIX="${GS_DISPATCH_PREFIX:-$GS_PREFIX/../dispatch-prefix}"
GS_DISPATCH_PREFIX=$(cd "$GS_DISPATCH_PREFIX" && pwd)
GS_TIMEOUT="${GS_TIMEOUT:-120}"
ONLY="${1:-}"

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
CCPREFIX="$TOOLCHAIN/bin/${GS_TRIPLE}${GS_API}"
TFH=$(find "$GS_PREFIX/gnustep" -name Testing.h -path '*TestFramework*' 2>/dev/null | head -1)
[ -n "$TFH" ] || { echo "no TestFramework headers under $GS_PREFIX/gnustep"; exit 1; }
TF=$(dirname "$TFH")
[ -d "$TF" ] || { echo "no TestFramework headers under $GS_PREFIX/gnustep"; exit 1; }
W="${GS_WORK:-$HOME/gs-run}"
# Everything lives under /data/local/tests, not /data/local/tmp.  SELinux does
# not let the shell domain create a socket in /data/local/tmp: that is
# shell_data_file, whose rules cover directories, files and symlinks and name
# sock_file nowhere.  Two things need one: gdnc binds an NSMessagePort whose
# path comes from NSTemporaryDirectory(), and NSStream's socket_cs binds the
# relative path "test-socket" in its working directory.  /data/local/tests is
# shell_test_data_file, which policy allows to create a socket and which is
# otherwise a superset of shell_data_file, execute included.  A directory made
# under it inherits the label.
DEV=/data/local/tests/gsbase
# Bracketed so pkill -f does not match the command line it arrives on
DEVPAT='/data/local/tests/[g]sbase/'
ROOT=/data/local/tests/gsroot
CONF="$ROOT/etc/GNUstep/GNUstep.conf"
UHOME=/data/local/tests/gshome
TMP=/data/local/tests/gstmp
EXPECTED="${GS_EXPECTED:-$GS_BASE/.github/scripts/android/expected-failures.txt}"

rm -rf "$W"; mkdir -p "$W"
adb wait-for-device
# No `adb root`: restarting adbd takes the device offline under the emulator
# action. /data/local/tests is writable without it.
adb shell 'echo device ready; id' </dev/null

INC="-I$GS_BASE/Headers -I$TF -I$GS_PREFIX/include -I$GS_BASE/Tests/base \
 -I$GS_BASE/Tests/base/GenericTests -I$GS_DISPATCH_PREFIX/include"
LIBS="-L$GS_BASE/Source/obj -lgnustep-base -L$GS_PREFIX/lib -lobjc -lxml2 -lffi \
 -licuuc -licui18n -licudata -liconv -L$GS_DISPATCH_PREFIX/lib -ldispatch"
FLAGS="-fobjc-runtime=gnustep-2.2 -fblocks -fexceptions -DGNUSTEP \
 -DGNUSTEP_BASE_LIBRARY=1 -Wno-deprecated-declarations"

# ------------------------------------------------------------ shared payload
adb shell "rm -rf $DEV $ROOT $UHOME $TMP" >/dev/null 2>&1 </dev/null
adb shell "mkdir -p $DEV $UHOME/GNUstep/Defaults $TMP" >/dev/null 2>&1 </dev/null
adb shell "ls -Zd $TMP" </dev/null | tr -d '\r' | sed 's/^/  tmpdir: /'
cp "$GS_BASE"/Source/obj/libgnustep-base.so.* "$W/" 2>/dev/null || true
cp "$GS_PREFIX/lib/libobjc.so" "$W/"
cp "$TOOLCHAIN/sysroot/usr/lib/$GS_TRIPLE/libc++_shared.so" "$W/"
cp "$GS_PREFIX"/lib/libicu*.so* "$W/" 2>/dev/null || true
cp "$GS_PREFIX"/lib/libiconv*.so* "$W/" 2>/dev/null || true
cp "$GS_DISPATCH_PREFIX/lib/libdispatch.so" "$W/"
mkdir -p "$W/Tools"
find "$GS_BASE/Tools/obj" -maxdepth 1 -type f ! -name '*.obj' -exec cp {} "$W/Tools/" \; 2>/dev/null || true
# base's TLS tests generate the server certificate by launching certtool
[ -f "$GS_PREFIX/bin/certtool" ] && cp "$GS_PREFIX/bin/certtool" "$W/Tools/"
adb push "$W"/. $DEV >/dev/null 2>&1 </dev/null
SO=$(basename "$(ls "$GS_BASE"/Source/obj/libgnustep-base.so.*.* | head -1)")
adb shell "cd $DEV && ln -sf $SO libgnustep-base.so && ln -sf $SO ${SO%.*}" >/dev/null 2>&1 </dev/null

# A real GNUstep tree, so +bundleForLibrary: and the plist DTD resolve.
GT="$W/gsroot"; cp -rL "$GS_PREFIX/gnustep" "$GT"
sed "s|$GS_PREFIX/gnustep|$ROOT|g" "$GS_PREFIX/gnustep/etc/GNUstep/GNUstep.conf" \
  > "$GT/etc/GNUstep/GNUstep.conf"
adb shell "mkdir -p $ROOT" >/dev/null 2>&1 </dev/null
adb push "$GT"/. $ROOT >/dev/null 2>&1 </dev/null
# base discards a config file that is group or world writable, and adb push
# creates 0666.
adb shell "chmod 644 $CONF" >/dev/null 2>&1 </dev/null
# adb push does not preserve the executable bit, and base launches gdnc from
# the installed tree by absolute path.
adb shell "chmod -R 755 $ROOT/bin $ROOT/Tools 2>/dev/null; true" >/dev/null 2>&1 </dev/null || true
adb shell "find $ROOT -name gdnc -exec chmod 755 {} + 2>/dev/null; true" >/dev/null 2>&1 </dev/null || true
g=$(adb shell "ls -l \$(find $ROOT -name gdnc | head -1) 2>/dev/null" </dev/null | tr -d '\r')
echo "  gdnc on device: ${g:-NOT FOUND}"
echo "  gdnc, run directly:"
adb shell "cd $DEV && LD_LIBRARY_PATH=$DEV TMPDIR=$TMP GNUSTEP_CONFIG_FILE=$CONF $ROOT/bin/gdnc --help 2>&1 | head -8; echo rc=\$?" \
  </dev/null | tr -d '\r' | sed 's/^/    /'

# Start gdnc before any test runs. It has to see the same TMPDIR as the tests,
# because NSMessagePortNameServer builds its socket path from
# NSTemporaryDirectory(): a daemon with a different one is unreachable.
GDNC=$(adb shell "find $ROOT -name gdnc -type f 2>/dev/null | head -1" </dev/null | tr -d '\r')
if [ -n "$GDNC" ]; then
  adb shell "chmod 755 '$GDNC' 2>/dev/null; true" </dev/null >/dev/null 2>&1 || true
  adb shell "cd $DEV && LD_LIBRARY_PATH=$DEV TMPDIR=$TMP \
    GNUSTEP_CONFIG_FILE=$CONF '$GDNC' 2>$TMP/gdnc.err" </dev/null >/dev/null 2>&1 || true
  sleep 3
  echo "  gdnc: $GDNC"
  adb shell "ps -A -o USER,PID,NAME 2>/dev/null | grep gdnc || echo '    (no gdnc process)'; \
    head -4 $TMP/gdnc.err 2>/dev/null" </dev/null | tr -d '\r' | sed 's/^/    /'
else
  echo "  gdnc: NOT FOUND in $ROOT"
fi

TP=0; TF_=0; TH=0; TS=0; TC=0; NB=0; NR=0; DIRS=0
: > "$W/all.txt"; : > "$W/nobuild.txt"; : > "$W/noresult.txt"; : > "$W/failed.txt"

for d in "$GS_BASE"/Tests/base/*/; do
  n=$(basename "$d")
  [ -n "$ONLY" ] && [ "$n" != "$ONLY" ] && continue
  ls "$d"*.m >/dev/null 2>&1 || continue
  DIRS=$((DIRS+1))
  mkdir -p "$W/$n"
  # every plain file, INCLUDING the .m sources: some tests read their own
  # source back through a file URL
  find "$d" -maxdepth 1 -type f -exec cp {} "$W/$n/" \; 2>/dev/null || true
  # gnustep-tests instantiates GNUmakefile.in into the working directory before
  # running a set, and two tests read whatever GNUmakefile they find there:
  # GSXML/basic.m resolves it as an external entity and looks for the string
  # MAKEFILES in the result, and NSTask's testcat helper cats it.  Instantiate
  # the same template so the directory looks the way a normal run leaves it.
  sed -e 's/@TESTNAMES@//; s^@TESTOPTS@^^; s/@TESTRULES@//' \
    "$TF/GNUmakefile.in" > "$W/$n/GNUmakefile"
  # data subdirectories, such as NSXMLParser's ParseData
  for sub in "$d"*/; do
    [ -d "$sub" ] || continue
    case "$(basename "$sub")" in obj|Helpers|Resources|derived_src) continue ;; esac
    cp -rL "$sub" "$W/$n/" 2>/dev/null || true
  done
  # -L: adb push cannot create symlinks as the shell user
  [ -d "$d/Resources" ] && cp -rL "$d/Resources" "$W/$n/" 2>/dev/null || true
  if [ -d "$d/Helpers" ]; then
    mkdir -p "$W/$n/Helpers"
    find "$d/Helpers" -maxdepth 1 -type f ! -name '*.m' ! -name '*.h' \
      -exec cp {} "$W/$n/Helpers/" \; 2>/dev/null || true
    [ -d "$d/Helpers/obj" ] && mkdir -p "$W/$n/Helpers/obj" && \
      find "$d/Helpers/obj" -maxdepth 1 -type f ! -name '*.obj' \
        -exec cp {} "$W/$n/Helpers/obj/" \; 2>/dev/null || true
    for b in "$d"Helpers/*.bundle; do
      [ -d "$b" ] && cp -rL "$b" "$W/$n/Helpers/" 2>/dev/null || true
    done
  fi

  # a framework built by the directory has to be on the link line
  XLIB=""; XRPATH=""
  for fw in "$d"Resources/*.framework; do
    [ -d "$fw" ] || continue
    fwn=$(basename "$fw" .framework)
    so=$(find "$fw" -name "lib$fwn.so.*" -type f 2>/dev/null | head -1)
    [ -n "$so" ] || continue
    rel=${so%/*}; rel=${rel#$d}
    XLIB="-Wl,--as-needed -L${so%/*} -l$fwn -Wl,--no-as-needed"
    XRPATH="-Wl,-rpath,\$ORIGIN/$rel"
  done

  built=""
  for f in "$d"*.m; do
    b=$(basename "$f" .m)
    # GenericTests is a gnustep-make subproject: without it -testForString and
    # -testEquals: do not exist and every PASS using them raises
    EXTRA=""
    grep -q '"generic\.h"' "$f" && EXTRA="$GS_BASE/Tests/base/GenericTests/generic.m"
    if $CCPREFIX-clang $FLAGS $INC -I"$d" -o "$W/$n/$b" "$f" $EXTRA $LIBS $XLIB \
         -fuse-ld=lld -Wl,-rpath,'$ORIGIN/..' $XRPATH > "$W/$n/$b.clog" 2>&1; then
      built="$built $b"
    else
      NB=$((NB+1))
      echo "$n/$b: $(grep -m1 -oE 'error: .{0,70}' "$W/$n/$b.clog")" >> "$W/nobuild.txt"
    fi
  done
  [ -z "$built" ] && continue

  adb shell "mkdir -p $DEV/$n" >/dev/null 2>&1 </dev/null
  if ! adb push "$W/$n"/. $DEV/$n >/tmp/push.log 2>&1 </dev/null; then
    echo "adb push failed for $n:"
    tail -20 /tmp/push.log | sed 's/^/    /'
    echo "  contents:"
    find "$W/$n" -maxdepth 2 | head -30 | sed 's/^/    /'
    echo "  symlinks:"
    find "$W/$n" -type l | head -20 | sed 's/^/    /'
    exit 1
  fi
  adb shell "chmod -R 755 $DEV/$n" >/dev/null 2>&1 </dev/null
  # a helper left over from an earlier directory still holds its port
  adb shell "pkill -f '$DEVPAT' 2>/dev/null; true" >/dev/null 2>&1 </dev/null || true

  if [ -z "${HELPER_CHECKED:-}" ] && [ -d "$d/Helpers/obj" ]; then
    HELPER_CHECKED=1
    h=$(adb shell "ls $DEV/$n/Helpers/obj 2>/dev/null | head -1" </dev/null | tr -d '\r')
    if [ -n "$h" ]; then
      echo "  helper check: $n/Helpers/obj/$h"
      adb shell "cd $DEV/$n && ls -l Helpers/obj/$h; LD_LIBRARY_PATH=$DEV ./Helpers/obj/$h --help 2>&1 | head -5; echo rc=\$?" \
        </dev/null | tr -d '\r' | sed 's/^/    /'
    fi
  fi

  dp=0; df=0; dh=0; ds=0
  for b in $built; do
    out=$(adb shell "cd $DEV/$n && LD_LIBRARY_PATH=$DEV PATH=$DEV/Tools:\$PATH TMPDIR=$TMP \
      GNUSTEP_CONFIG_FILE=$CONF timeout -s KILL $GS_TIMEOUT ./$b 2>&1; echo RC=\$?" \
      </dev/null | tr -d '\r')
    rc=$(echo "$out" | sed -n 's/^RC=//p' | tail -1)
    fp=$(echo "$out" | grep -c "^Passed test") || true
    ff=$(echo "$out" | grep -c "^Failed test") || true
    fh=$(echo "$out" | grep -c "^Dashed hope") || true
    fs=$(echo "$out" | grep -c "^Skipped set") || true
    dp=$((dp+fp)); df=$((df+ff)); dh=$((dh+fh)); ds=$((ds+fs))
    echo "$out" | grep "^Failed test" | sed -E "s|.*/Tests/base/||" >> "$W/failed.txt" || true
    [ "${rc:-0}" -ge 128 ] 2>/dev/null && TC=$((TC+1))
    # A file that reports nothing looks like a pass while testing nothing.
    if [ $((fp+ff+fh+fs)) -eq 0 ]; then
      NR=$((NR+1)); echo "$n/$b (rc=$rc)" >> "$W/noresult.txt"
    fi
    { echo "### $n/$b rc=$rc"; echo "$out"; } >> "$W/all.txt"
  done
  printf "  %-28s %5s passed %4s failed %3s hopes %3s skipped\n" "$n" "$dp" "$df" "$dh" "$ds"
  TP=$((TP+dp)); TF_=$((TF_+df)); TH=$((TH+dh)); TS=$((TS+ds))
done

echo
echo "======== libs-base on Android $GS_TRIPLE API $GS_API ========"
printf "  directories %5d\n  passed      %5d\n  failed      %5d\n" "$DIRS" "$TP" "$TF_"
printf "  hopes       %5d\n  skipped     %5d\n  crashed     %5d\n" "$TH" "$TS" "$TC"
printf "  no result   %5d\n  did not build %3d\n" "$NR" "$NB"
[ -s "$W/nobuild.txt" ] && { echo; echo "  did not build:"; sed 's/^/    /' "$W/nobuild.txt"; }
[ -s "$W/noresult.txt" ] && { echo; echo "  produced no result at all:"; sed 's/^/    /' "$W/noresult.txt"; }

# ------------------------------------------------------------------ verdict
rc=0
[ "$NB" -gt 0 ] && { echo; echo "FAIL: $NB test files did not build"; rc=1; }
if [ -s "$W/failed.txt" ]; then
  echo; echo "  failures:"; sed 's/^/    /' "$W/failed.txt"
  if [ -f "$EXPECTED" ]; then
    # A failure is tolerated only if its "dir:file.m:line" prefix is listed.
    while read -r line; do
      key=$(echo "$line" | cut -d' ' -f1)
      grep -qF "$key" "$EXPECTED" || { echo "  UNEXPECTED: $line"; rc=1; }
    done < <(sed 's/^Failed test: *//' "$W/failed.txt" | sed 's/^ *//')
    [ "$rc" = 0 ] && echo "  (all listed in $(basename "$EXPECTED"))"
  else
    rc=1
  fi
fi
exit $rc
