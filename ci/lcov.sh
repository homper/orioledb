#!/bin/bash

set -eu

cd orioledb
if [ $COMPILER = "clang" ]; then
    lcov --gcov-tool "$PWD/ci/llvm-gcov.sh" --capture --directory . --output-file coverage.info
else
	lcov --capture --directory . --output-file coverage.info
fi
cd ..