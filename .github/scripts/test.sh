#! /usr/bin/env sh

set -ex

echo "Running unit tests"
make check || (cat Tests/tests.log && false);
