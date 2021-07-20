#! /usr/bin/env sh

set -ex

install_gnustep_make() {
    cd $DEP_SRC
    git clone https://github.com/gnustep/tools-make.git
    cd tools-make
    if [ -n "$RUNTIME_VERSION" ]
    then
        WITH_RUNTIME_ABI="--with-runtime-abi=${RUNTIME_VERSION}"
    else
        WITH_RUNTIME_ABI=""
    fi
    ./configure --prefix=$DEP_ROOT --with-library-combo=$LIBRARY_COMBO $WITH_RUNTIME_ABI
    make install

    echo Objective-C build flags:
    $DEP_ROOT/bin/gnustep-config --objc-flags
}

install_ng_runtime() {
    cd $DEP_SRC
    git clone https://github.com/gnustep/libobjc2.git
    cd libobjc2
    git submodule sync
    git submodule update --init
    mkdir build
    cd build
    cmake \
      -DTESTS=off \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DGNUSTEP_INSTALL_TYPE=NONE \
      -DCMAKE_INSTALL_PREFIX:PATH=$DEP_ROOT \
      ../
    make install
}

install_libdispatch() {
    cd $DEP_SRC
    # will reference upstream after https://github.com/apple/swift-corelibs-libdispatch/pull/534 is merged
    git clone -b system-blocksruntime https://github.com/ngrewe/swift-corelibs-libdispatch.git libdispatch
    mkdir libdispatch/build
    cd libdispatch/build
    # -Wno-error=void-pointer-to-int-cast to work around build error in queue.c due to -Werror
    cmake \
      -DBUILD_TESTING=off \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX:PATH=$DEP_ROOT \
      -DCMAKE_C_FLAGS="-Wno-error=void-pointer-to-int-cast" \
      -DINSTALL_PRIVATE_HEADERS=1 \
      -DBlocksRuntime_INCLUDE_DIR=$DEP_ROOT/include \
      -DBlocksRuntime_LIBRARIES=$DEP_ROOT/lib/libobjc.so \
      ../
    make install
}

mkdir -p $DEP_SRC

if [ "$LIBRARY_COMBO" = 'ng-gnu-gnu' ]
then
    install_ng_runtime
    install_libdispatch
fi

install_gnustep_make
