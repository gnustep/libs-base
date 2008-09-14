#/bin/sh

PREFIX=$1
MAKE=$2

. $PREFIX/System/Library/Makefiles/GNUstep.sh
$MAKE install

exit 0