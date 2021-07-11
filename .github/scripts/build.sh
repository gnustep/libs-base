#! /usr/bin/env sh

set -ex

echo "Building..."

sudo apt-get -qq update
sudo apt-get install -y cmake pkg-config libgnutls28-dev libgmp-dev libffi-dev \
     libicu-dev libxml2-dev libxslt1-dev libssl-dev libavahi-client-dev zlib1g-dev \
     libcurl-dev gnutls-dev

if [ $LIBRARY_COMBO = 'gnu-gnu-gnu' ];
then
  if [ $CC = 'gcc' ];
  then
    sudo apt-get install -y gobjc;
  fi;
  #  sudo apt-get install -y libobjc-4.8-dev libblocksruntime-dev;
  sudo apt-get install -y libobjc-8-dev libblocksruntime-dev;
  else
    curl -s -o - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -;
    sudo apt-add-repository "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-9 main" && \
	sudo apt-get update -qq;
    sudo apt-get install -y clang-9 libkqueue-dev libpthread-workqueue-dev;
    sudo update-alternatives   --install /usr/bin/clang   clang   /usr/bin/clang-9   10 \
                               --slave   /usr/bin/clang++ clang++ /usr/bin/clang++-9;
    export PATH=$(echo "$PATH" | sed -e 's/:\/usr\/local\/clang-7.0.0\/bin//');
    if [ "$RUNTIME_VERSION" = "gnustep-2.0" ];
    then
      sudo update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.gold" 10;
    fi;
fi;

# Install dependencies
./.github/scripts/dependencies.sh

# before script
export LIBRARY_PATH=$HOME/staging/lib:$HOME/staging/lib64:$LIBRARY_PATH;
export LD_LIBRARY_PATH=$HOME/staging/lib:$HOME/staging/lib64:$LD_LIBRARY_PATH;
if [ $LIBRARY_COMBO = 'ng-gnu-gnu' ];
then
  export CPATH=$HOME/staging/include;
else
  export CPATH=/usr/lib/gcc/x86_64-linux-gnu/4.8/include;
fi;
export PATH=$HOME/staging/bin:$PATH;
export GNUSTEP_MAKEFILES=$HOME/staging/share/GNUstep/Makefiles;
. $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh;

# script
./configure $BASE_ABI || (cat config.log && false);
make && make install && make check || (cat Tests/tests.log && false);
