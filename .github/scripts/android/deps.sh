#!/bin/bash
#
# Cross-build everything libs-base needs on Android, into $GS_PREFIX.
#
# Every component is skipped if its output is already present, so a restored
# cache short-circuits the whole script.  Versions are pinned: a CI that
# follows upstream releases fails for reasons unrelated to libs-base.
#
set -eu

: "${ANDROID_NDK_HOME:?}"
: "${GS_PREFIX:?}"
: "${GS_API:=31}"
: "${GS_ABI:=x86_64}"
: "${GS_TRIPLE:=x86_64-linux-android}"
GS_SRC="${GS_SRC:-$HOME/gs-src}"
GS_DISPATCH_PREFIX="${GS_DISPATCH_PREFIX:-$GS_PREFIX/../dispatch-prefix}"

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
CCPREFIX="$TOOLCHAIN/bin/${GS_TRIPLE}${GS_API}"
export PATH="$TOOLCHAIN/bin:$PATH"
mkdir -p "$GS_SRC" "$GS_PREFIX" "$GS_DISPATCH_PREFIX"
GS_DISPATCH_PREFIX=$(cd "$GS_DISPATCH_PREFIX" && pwd)

JOBS=$(nproc)
say() { echo "== $*"; }

fetch() {   # url -> echoes the unpacked directory
  local url=$1 f d attempt
  f=$(basename "$url")
  cd "$GS_SRC"
  for attempt in 1 2 3; do
    if [ ! -s "$f" ] || ! tar tf "$f" >/dev/null 2>&1; then
      rm -f "$f"
      # -f so an HTTP error is a failure rather than an error page saved as
      # the tarball, which only shows up later as "does not look like a tar
      # archive".
      curl -fsSL --retry 3 --retry-delay 5 -o "$f" "$url" || true
    fi
    tar tf "$f" >/dev/null 2>&1 && break
    echo "   download of $f was not a readable archive, retrying"
    rm -f "$f"
    sleep 5
  done
  tar tf "$f" >/dev/null 2>&1 || { echo "cannot download $url"; exit 1; }
  d=$(tar tf "$f" | sed -n '1s|/.*||p')
  [ -d "$d" ] || tar xf "$f"
  echo "$GS_SRC/$d"
}

# ---------------------------------------------------------------- libobjc2
if [ ! -f "$GS_PREFIX/lib/libobjc.so" ]; then
  say "libobjc2"
  [ -d "$GS_SRC/libobjc2" ] || git clone -q --depth 1 --recurse-submodules \
    https://github.com/gnustep/libobjc2.git "$GS_SRC/libobjc2"
  cmake -B "$GS_SRC/libobjc2/build" -S "$GS_SRC/libobjc2" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$GS_ABI" -DANDROID_PLATFORM="android-$GS_API" \
    -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$GS_PREFIX" \
    -DGNUSTEP_INSTALL_TYPE=NONE \
    -DTESTS=OFF -DCMAKE_FIND_USE_CMAKE_PATH=false \
    -DCMAKE_C_COMPILER="$CCPREFIX-clang" \
    -DCMAKE_CXX_COMPILER="$CCPREFIX-clang++" \
    -DCMAKE_OBJC_COMPILER="$CCPREFIX-clang" \
    -DCMAKE_OBJCXX_COMPILER="$CCPREFIX-clang++" >/dev/null
  cmake --build "$GS_SRC/libobjc2/build" -j "$JOBS" >/dev/null
  cmake --install "$GS_SRC/libobjc2/build" >/dev/null
fi

# ------------------------------------------------------------------ libffi
if [ ! -f "$GS_PREFIX/lib/libffi.a" ] && [ ! -f "$GS_PREFIX/lib64/libffi.a" ]; then
  say "libffi"
  d=$(fetch https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ----------------------------------------------------------------- libxml2
if [ ! -f "$GS_PREFIX/lib/libxml2.a" ]; then
  say "libxml2"
  d=$(fetch https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --without-python --without-icu --without-lzma --without-zlib \
    --disable-shared --enable-static --with-pic \
    CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ---------------------------------------------------------------- libiconv
# bionic's iconv is in libc but thin: 16 encodings against glibc's 68.
if [ ! -f "$GS_PREFIX/lib/libiconv.so" ]; then
  say "GNU libiconv"
  d=$(fetch https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-pic CC="$CCPREFIX-clang" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# --------------------------------------------------------------------- ICU
# The cross build runs the host's own data tools, so a native build first.
if [ ! -f "$GS_PREFIX/lib/libicuuc.so" ]; then
  say "ICU (native, for the cross build's tools)"
  d=$(fetch https://github.com/unicode-org/icu/releases/download/release-74-2/icu4c-74_2-src.tgz)
  ICUSRC="$d/source"
  if [ ! -d "$GS_SRC/icu-native" ]; then
    mkdir -p "$GS_SRC/icu-native"
    cd "$GS_SRC/icu-native" && "$ICUSRC/runConfigureICU" Linux >/dev/null
    make -j"$JOBS" >/dev/null
  fi
  say "ICU (cross)"
  mkdir -p "$GS_SRC/icu-android"
  cd "$GS_SRC/icu-android"
  "$ICUSRC/configure" --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-cross-build="$GS_SRC/icu-native" \
    --disable-tests --disable-samples --disable-extras \
    CC="$CCPREFIX-clang" CXX="$CCPREFIX-clang++" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ----------------------------------------------------------------- libcurl
# NSURLSession is gated on libcurl.  Its tests use a local http server, so no
# TLS is needed here.
if [ ! -f "$GS_PREFIX/lib/libcurl.a" ]; then
  say "libcurl"
  d=$(fetch https://curl.se/download/curl-8.11.1.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-pic --disable-shared --enable-static \
    --without-ssl --without-libpsl --without-brotli --without-zstd \
    --without-nghttp2 --without-libidn2 --disable-ldap --disable-ldaps \
    CC="$CCPREFIX-clang" AR="$TOOLCHAIN/bin/llvm-ar" \
    RANLIB="$TOOLCHAIN/bin/llvm-ranlib" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ------------------------------------------------- GMP, nettle, tasn1, TLS
export CFLAGS="-fPIC -O2"
export CPPFLAGS="-I$GS_PREFIX/include"
export LDFLAGS="-L$GS_PREFIX/lib"
export PKG_CONFIG_PATH="$GS_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$GS_PREFIX/lib/pkgconfig"
export CC="$CCPREFIX-clang" CXX="$CCPREFIX-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
       NM="$TOOLCHAIN/bin/llvm-nm"

if [ ! -f "$GS_PREFIX/lib/libgmp.a" ]; then
  say "GMP"
  d=$(fetch https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi
if [ ! -f "$GS_PREFIX/lib/libhogweed.a" ]; then
  say "nettle"
  d=$(fetch https://ftp.gnu.org/gnu/nettle/nettle-3.10.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --disable-openssl --disable-documentation \
    --with-include-path="$GS_PREFIX/include" --with-lib-path="$GS_PREFIX/lib" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi
if [ ! -f "$GS_PREFIX/lib/libtasn1.a" ]; then
  say "libtasn1"
  d=$(fetch https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic --disable-doc >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi
if [ ! -f "$GS_PREFIX/lib/libgnutls.a" ]; then
  # 3.8.13 or newer: bionic declares timezone_t but gates mktime_z and friends
  # on API 35, and older gnulib copies get that wrong either way round.
  # The tools are built too: base's TLS tests generate a certificate by
  # launching certtool on the device.
  say "GnuTLS"
  d=$(fetch https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --disable-shared --enable-static --with-pic \
    --with-included-unistring --without-p11-kit --without-idn \
    --without-tpm --without-tpm2 --disable-doc --disable-cxx \
    --disable-tests --disable-guile --disable-libdane --disable-nls \
    --with-default-trust-store-dir=/system/etc/security/cacerts/ >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# ---------------------------------------------------------------- libxslt
if [ ! -f "$GS_PREFIX/lib/libxslt.a" ]; then
  say "libxslt"
  d=$(fetch https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.43.tar.xz)
  cd "$d" && ./configure --host="$GS_TRIPLE" --prefix="$GS_PREFIX" \
    --with-libxml-prefix="$GS_PREFIX" --without-python --without-crypto \
    --without-debug --disable-shared --enable-static --with-pic >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null
fi

# -------------------------------------------------------------- libdispatch
# Its own prefix: it installs a Block.h that collides with libobjc2's.
if [ ! -f "$GS_DISPATCH_PREFIX/lib/libdispatch.so" ]; then
  say "libdispatch"
  [ -d "$GS_SRC/libdispatch" ] || git clone -q --depth 1 \
    https://github.com/swiftlang/swift-corelibs-libdispatch.git "$GS_SRC/libdispatch"
  cmake -B "$GS_SRC/libdispatch/build" -S "$GS_SRC/libdispatch" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$GS_ABI" -DANDROID_PLATFORM="android-$GS_API" \
    -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$GS_DISPATCH_PREFIX" \
    -DBUILD_SHARED_LIBS=YES -DENABLE_SWIFT=NO -DBUILD_TESTING=NO \
    -DINSTALL_PRIVATE_HEADERS=YES -DCMAKE_FIND_USE_CMAKE_PATH=false >/dev/null
  cmake --build "$GS_SRC/libdispatch/build" -j "$JOBS" >/dev/null
  cmake --install "$GS_SRC/libdispatch/build" >/dev/null
  # It leaves _Block_copy and friends undefined but still links its own
  # BlocksRuntime, which duplicates libobjc2's.  Point it at libobjc2 instead.
  patchelf --replace-needed libBlocksRuntime.so libobjc.so \
    "$GS_DISPATCH_PREFIX/lib/libdispatch.so"
fi

say "dependency prefix ready"
ls "$GS_PREFIX/lib" | sed 's/^/    /' | head -40
