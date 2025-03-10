#!/bin/bash

set -eu

set -x

cd orioledb
if [ $COMPILER = "clang" ]; then
	llvm-cov-$LLVM_VER gcov src/*.c src/*/*.c include/*.h include/*/*.h -r -p -l
	# find . -type f -name '*.gcno' -exec llvm-cov-$LLVM_VER gcov -r -l -pb {} +
else
	find . -type f -name "*.gcno"
	find . -type f -name "*.gcda"
	gcov src/*.c src/*/*.c -r -p -l
	# bash -c 'find . -type f -name '\''*.gcno'\''  -not -path '\''./bower_components/**'\'' -not -path '\''./node_modules/**'\'' -not -path '\''./vendor/**'\'' -exec gcov -pb  {} +'
fi
cd ..