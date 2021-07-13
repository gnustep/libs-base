#! /usr/bin/env sh

set -ex

echo "Running unit tests"
. $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh;
make check || (cat Tests/tests.log && false);

