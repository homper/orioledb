#!/bin/bash

set -eu
export PATH="$GITHUB_WORKSPACE/pgsql/bin:$GITHUB_WORKSPACE/python3-venv/bin:$PATH"

cd orioledb
coveralls --gcov-options '\-lp'
cd ..
