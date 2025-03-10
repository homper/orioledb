#!/bin/bash

set -eu

set -x

cd orioledb
if [ $COMPILER = "clang" ]; then
	# llvm-cov-$LLVM_VER gcov src/*.c src/*/*.c include/*.h include/*/*.h -r -p -l
	bash -c 'find . -type f -name '\''*.gcno'\'' -exec llvm-cov-$LLVM_VER gcov -r -p -l -b {} +'
else
	# gcov src/*.c src/*/*.c -r -p -l
	bash -c 'find . -type f -name '\''*.gcno'\'' -exec gcov -r -p -l -b {} +'
fi
cd ..