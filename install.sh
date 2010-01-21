#! /bin/sh

PREFIX=$1
MAKE=${2-make}

. $PREFIX/System/Library/Makefiles/GNUstep.sh
sh configure --with-installation-domain=SYSTEM
$MAKE GNUSTEP_INSTALLATION_DOMAIN=SYSTEM install

exit 0
