#!/usr/bin/env bash
set -euo pipefail
# Keep the test filesystem independent of the builder's userspace.
mkdir -p /testroot/{usr,proc,dev,tmp,run/pizza,etc,relocated}
ln -s /relocated/runtime/lib /testroot/usr/lib
ln -s /relocated/runtime/share /testroot/usr/share
ln -s /relocated/runtime/bin /testroot/bin
ln -s /relocated/runtime/bin /testroot/sbin
ln -s /relocated/runtime/bin /testroot/usr/bin
ln -s /relocated/runtime/bin /testroot/usr/sbin
ln -s /relocated/runtime/lib /testroot/lib
ln -s /relocated/runtime/lib /testroot/lib64
cp -a /build/pizza-runtime /testroot/relocated/runtime
cp -a /build/pizza-runtime/etc/. /testroot/etc/
cp /src/scripts/test.sh /testroot/test.sh
