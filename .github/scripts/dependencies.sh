#! /usr/bin/env sh

set -ex

# NetBSD and the other BSDs ship a non-GNU make as /usr/bin/make, so allow the
# caller to point us at GNU make. Defaults to plain "make" everywhere else.
MAKE=${MAKE:-make}

install_gnustep_make() {
    echo "::group::GNUstep Make"
    cd $DEPS_PATH
    git clone -q -b ${TOOLS_MAKE_BRANCH:-master} https://github.com/gnustep/tools-make.git
    cd tools-make
    MAKE_OPTS=
    if [ -n "$HOST" ]; then
      MAKE_OPTS="$MAKE_OPTS --host=$HOST"
    fi
    if [ -n "$RUNTIME_VERSION" ]; then
      MAKE_OPTS="$MAKE_OPTS --with-runtime-abi=$RUNTIME_VERSION"
    fi
    ./configure --prefix=$INSTALL_PATH --with-library-combo=$LIBRARY_COMBO --with-libdir=$LIBDIR $MAKE_OPTS || cat config.log
    $MAKE install

    echo Objective-C build flags:
    $INSTALL_PATH/bin/gnustep-config --objc-flags
    echo "::endgroup::"
}

install_libobjc2() {
    echo "::group::libobjc2"
    cd $DEPS_PATH
    git clone -q https://github.com/gnustep/libobjc2.git
    cd libobjc2
    git submodule sync
    git submodule update --init
    mkdir build
    cd build
    cmake \
      -DTESTS=off \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DGNUSTEP_INSTALL_TYPE=NONE \
      -DCMAKE_INSTALL_PREFIX:PATH=$INSTALL_PATH \
      -DEMBEDDED_BLOCKS_RUNTIME=ON \
      ../
    $MAKE install
    echo "::endgroup::"
}

install_libdispatch() {
    echo "::group::libdispatch"
    cd $DEPS_PATH
    git clone -q https://github.com/swiftlang/swift-corelibs-libdispatch libdispatch
    mkdir libdispatch/build
    cd libdispatch/build
    cmake \
      -DBUILD_TESTING=off \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX:PATH=$INSTALL_PATH \
      -DINSTALL_PRIVATE_HEADERS=1 \
      ../
    $MAKE install
    echo "::endgroup::"
}

mkdir -p $DEPS_PATH

# Allow the packages we install locally to have their pkg-config info found.
# NB. windows uses a semicolon rather than a colon as a path separator.
if [ x"$PKG_CONFIG_PATH" = x ]; then
  PKG_CONFIG_PATH=$INSTALL_PATH/lib/pkgconfig
else
  if [ "$IS_WINDOWS_MSVC" != "true" -a "$IS_WINDOWS_MINGW" != "true" ]; then
    PKG_PATH_SEP=":"
  else
    PKG_PATH_SEP=";"
  fi
  PKG_CONFIG_PATH=$INSTALL_PATH/lib/pkgconfig$PKG_PATH_SEP$PKG_CONFIG_PATH
fi

# Windows MSVC toolchain uses tools-windows-msvc scripts to install non-GNUstep dependencies;
# the MSYS2 toolchain uses Pacman to install non-GNUstep dependencies.
if [ "$LIBRARY_COMBO" = "ng-gnu-gnu" -a "$IS_WINDOWS_MSVC" != "true" -a "$IS_WINDOWS_MINGW" != "true" ]; then
    install_libobjc2
    # libdispatch is optional for gnustep-base and does not support every
    # platform we build on, so allow a workflow to opt out of it.
    if [ "$INSTALL_LIBDISPATCH" != "false" ]; then
        install_libdispatch
    fi
fi

install_gnustep_make
