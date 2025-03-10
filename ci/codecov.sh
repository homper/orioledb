#!/bin/bash

set -eu

cd orioledb
if [ $COMPILER = "clang" ]; then
	bash -x <(curl -s https://codecov.io/bash) -x "llvm-cov-$LLVM_VER gcov"
else
	bash -x <(curl -s https://codecov.io/bash) -X gcov -v
fi
cd ..
