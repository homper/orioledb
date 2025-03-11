#!/bin/bash

set -eu

set -x

cd orioledb
if [ $COMPILER = "clang" ]; then
	# llvm-cov-$LLVM_VER gcov src/*.c src/*/*.c include/*.h include/*/*.h -r -p -l
	bash -c 'find . -type f -name '\''*.gcno'\'' -exec llvm-cov-$LLVM_VER gcov -p -b {} +'
else
	# gcov src/*.c src/*/*.c -r -p -l
	bash -c 'find . -type f -name '\''*.gcno'\'' -exec gcov -p -b {} +'
fi
bash -c 'find . \( -type f -name '\''*.gov'\'' \) -and -not \( -name '\''src#*'\'' -o -name '\''include#*'\'' \)'
bash -c 'find . \( -type f -name '\''*.gov'\'' \) -and -not \( -name '\''src#*'\'' -o -name '\''include#*'\'' \) -exec rm {} +'
cd ..