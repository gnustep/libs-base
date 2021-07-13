#! /usr/bin/env sh

set -ex

Echo "Running unit tests"
make check || (cat Tests/tests.log && false);
