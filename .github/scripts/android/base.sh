#!/bin/bash
#
# Cross-install tools-make, then build libs-base, its tools, the per-directory
# test helpers and the test bundles, all for Android.
#
set -eu

: "${ANDROID_NDK_HOME:?}"
: "${GS_PREFIX:?}"
: "${GS_BASE:?}"                     # the libs-base checkout
: "${GS_API:=31}"
: "${GS_TRIPLE:=x86_64-linux-android}"
GS_SRC="${GS_SRC:-$HOME/gs-src}"
GS_DISPATCH_PREFIX="${GS_DISPATCH_PREFIX:-$GS_PREFIX/../dispatch-prefix}"
GS_DISPATCH_PREFIX=$(cd "$GS_DISPATCH_PREFIX" && pwd)
GSROOT="$GS_PREFIX/gnustep"

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
CCPREFIX="$TOOLCHAIN/bin/${GS_TRIPLE}${GS_API}"
JOBS=$(nproc)
say() { echo "== $*"; }

# ------------------------------------------------------------- tools-make
find_gnustep_sh() { find "$GSROOT" -name GNUstep.sh -path '*Makefiles*' 2>/dev/null | head -1; }

if [ -z "$(find_gnustep_sh)" ]; then
  say "tools-make (cross)"
  [ -d "$GS_SRC/tools-make" ] || git clone -q --depth 1 \
    https://github.com/gnustep/tools-make.git "$GS_SRC/tools-make"
  cd "$GS_SRC/tools-make"
  ./configure --prefix="$GSROOT" \
    --host="$GS_TRIPLE" --target="$GS_TRIPLE" \
    --with-library-combo=ng-gnu-gnu \
    CC="$CCPREFIX-clang" \
    CPPFLAGS="-I$GS_PREFIX/include" \
    LDFLAGS="-L$GS_PREFIX/lib -fuse-ld=lld" \
    LIBS="-lobjc" > "$GS_SRC/tools-make-configure.log" 2>&1 || {
      echo "tools-make configure failed"
      tail -25 "$GS_SRC/tools-make-configure.log"; exit 1; }
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

GSMAKE_SH=$(find_gnustep_sh)
if [ -z "$GSMAKE_SH" ]; then
  echo "tools-make installed no GNUstep.sh under $GSROOT; it contains:"
  find "$GSROOT" -maxdepth 4 -type d | head -40
  exit 1
fi
echo "   GNUstep.sh: $GSMAKE_SH"

# ------------------------------------------------------- host tool wrappers
# plmerge and friends run on the BUILD machine, but sourcing the Android
# GNUstep.sh points LD_LIBRARY_PATH at Android libraries and the host binaries
# then exit 127.  Wrap them so they keep the host's own library path.
HOSTTOOLS="$GS_SRC/hosttools"
mkdir -p "$HOSTTOOLS"
for t in plmerge pl2link defaults; do
  real=$(command -v "$t" || true)
  [ -n "$real" ] || { echo "missing host tool: $t"; exit 1; }
  rm -f "$HOSTTOOLS/$t"
  printf '#!/bin/sh\nexec env -u LD_LIBRARY_PATH %s "$@"\n' "$real" > "$HOSTTOOLS/$t"
  chmod +x "$HOSTTOOLS/$t"
done

# ------------------------------------------------------- cross answers file
# configure runs 23 AC_RUN_IFELSE tests it cannot run when cross compiling.
# The shipped cross.config holds conservative placeholders that are wrong for
# libobjc2 on Android, so ship the measured answers with the workflow.
CROSS="${GS_CROSS_CONFIG:-$GS_BASE/.github/scripts/android/android.cross.config}"
[ -f "$CROSS" ] || { echo "missing cross config: $CROSS"; exit 1; }

# ---------------------------------------------------------------- libs-base
say "libs-base configure"
cd "$GS_BASE"
# GNUstep.sh reads variables that are not set, which `set -u` treats as fatal.
set +u
# shellcheck disable=SC1091
. "$GSMAKE_SH"
set -u
export PATH="$HOSTTOOLS:$PATH"
export CC="$CCPREFIX-clang" CXX="$CCPREFIX-clang++"
export PKG_CONFIG_PATH="$GS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$GS_PREFIX/lib/pkgconfig"
GNUTLS_LIBS=$(pkg-config --static --libs gnutls)
# libobjc2's Block.h must win over libdispatch's, so its include comes first.
export CPPFLAGS="-I$GS_PREFIX/include -I$GS_DISPATCH_PREFIX/include"
export LDFLAGS="-L$GS_PREFIX/lib -L$GS_DISPATCH_PREFIX/lib -fuse-ld=lld"
export LIBS="-liconv $GNUTLS_LIBS"
export XML2_CONFIG="$GS_PREFIX/bin/xml2-config"

# configure.ac hardcodes CURL_CONFIG and ignores the environment variable, so
# --with-curl is the only way to keep the host's curl-config out.
./configure --host="$GS_TRIPLE" --prefix="$GSROOT" \
  --with-cross-compilation-info="$CROSS" \
  --with-xml-prefix="$GS_PREFIX" --with-curl="$GS_PREFIX" \
  --with-dispatch-include="$GS_DISPATCH_PREFIX/include" \
  --with-dispatch-library="$GS_DISPATCH_PREFIX/lib" \
  > "$GS_BASE/android-configure.log" 2>&1 || {
    echo "configure failed"; tail -40 "$GS_BASE/android-configure.log"; exit 1; }

grep -E "^(HAVE_LIBXML|HAVE_LIBXSLT|HAVE_LIBCURL|HAVE_GNUTLS|HAVE_LIBDISPATCH|HAVE_LIBDISPATCH_RUNLOOP|GS_HAVE_NSURLSESSION|GS_USE_ICU)=" \
  config.log | sort -u | sed 's/^/    /'

say "libs-base build"
make -j"$JOBS" > "$GS_BASE/android-build.log" 2>&1 || {
  echo "build failed"; grep -E "error:" "$GS_BASE/android-build.log" | head -20; exit 1; }
ls -l Source/obj/libgnustep-base.so.* | sed 's/^/    /'

# Install into the cross prefix. The test run deploys that tree to the device,
# and base looks there for NSTimeZones, Languages, the DTDs and its own library
# bundle. Without this the device can name its time zone through ICU and then
# fail to build it.
say "libs-base install"
make install > "$GS_BASE/android-install.log" 2>&1 || {
  echo "install failed"; tail -25 "$GS_BASE/android-install.log"; exit 1; }
z=$(find "$GSROOT" -type d -name NSTimeZones | head -1)
[ -n "$z" ] || { echo "no NSTimeZones in $GSROOT after install"; exit 1; }
echo "    zones: $(find "$z/zones" -type f 2>/dev/null | wc -l) files, Etc/UTC $([ -f "$z/zones/Etc/UTC" ] && echo present || echo MISSING)"

# ------------------------------------------------------- helpers and bundles
# These MUST be rebuilt with the tree.  Carrying prebuilt copies over silently
# tests the wrong code: an out of date SimpleWebServer, for instance, does not
# read back the port the system assigned and every request goes to port 0.
export ADDITIONAL_OBJCFLAGS="-fobjc-runtime=gnustep-2.2 -fblocks -I$GS_BASE/Headers -I$GS_PREFIX/include -I$GS_DISPATCH_PREFIX/include"
export ADDITIONAL_LDFLAGS="-fuse-ld=lld -L$GS_BASE/Source/obj -L$GS_PREFIX/lib -L$GS_DISPATCH_PREFIX/lib -lgnustep-base -lobjc -ldispatch"
export LIBRARIES_DEPEND_UPON="-lgnustep-base -lobjc -ldispatch"

say "test helpers"
for H in "$GS_BASE"/Tests/base/*/Helpers; do
  [ -f "$H/GNUmakefile" ] || continue
  d=$(basename "$(dirname "$H")")
  make -C "$H" clean >/dev/null 2>&1 || true
  if make -C "$H" > "/tmp/helpers-$d.log" 2>&1; then
    echo "    $d"
  else
    echo "    $d FAILED"; grep -m3 -E "error:" "/tmp/helpers-$d.log" | sed 's/^/      /'; exit 1
  fi
done

say "test bundles and frameworks"
for R in "$GS_BASE"/Tests/base/*/Resources; do
  [ -f "$R/GNUmakefile" ] || continue
  d=$(basename "$(dirname "$R")")
  make -C "$R" clean >/dev/null 2>&1 || true
  if make -C "$R" > "/tmp/bundles-$d.log" 2>&1; then
    echo "    $d"
  else
    echo "    $d FAILED"; grep -m3 -E "error:|Error " "/tmp/bundles-$d.log" | sed 's/^/      /'; exit 1
  fi
done

# tools-make#76: check the framework soname is a library name and not a stray
# argument off the link line, since a bad one only shows up as a load failure
# on device.  Either the versionless or the versioned name is a library name;
# which one the rule records is tools-make's to decide.
for fw in "$GS_BASE"/Tests/base/*/Resources/*.framework; do
  [ -d "$fw" ] || continue
  so=$(find "$fw" -name 'lib*.so.*.*' -type f | head -1)
  [ -n "$so" ] || continue
  sn=$("$TOOLCHAIN/bin/llvm-readelf" -d "$so" | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p')
  echo "    $(basename "$fw") SONAME $sn"
  case "$sn" in lib*.so|lib*.so.*) ;; *) echo "unexpected SONAME: $sn"; exit 1 ;; esac
done

say "base tools"
ls "$GS_BASE/Tools/obj" 2>/dev/null | grep -v '\.obj$' | tr '\n' ' ' | sed 's/^/    /'
echo
