#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/units
fpc -Mdelphi -Sh -gl -Ci -Cr -Co -Fusrc -FUbuild/units -FEbuild -olabel-demo labelDemo.lpr
fpc -Mdelphi -Sh -gl -Ci -Cr -Co -Fusrc -FUbuild/units -FEbuild -olabel-tests tests/labelTests.dpr
./build/label-tests
for columns in 3 5 6; do
  ./build/label-demo "examples/labels-$columns.lay" examples/sample-data.ini "output/columns-$columns" 203 2
done
