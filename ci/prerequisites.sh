#!/bin/bash

set -eu

# print the hostname to be able to identify runner by logs
echo "HOSTNAME=`hostname`"
TIMESTAMP=$(date +%s)
echo "TIMESTAMP=$TIMESTAMP" >> $GITHUB_ENV
echo "TIMESTAMP=$TIMESTAMP"

sudo apt-get -y install -qq wget ca-certificates

sudo apt-get update -qq

apt_packages="build-essential flex bison pkg-config libreadline-dev make gdb libipc-run-perl libicu-dev python3 python3-dev python3-pip python3-setuptools python3-testresources libzstd1 libzstd-dev libcurl4-openssl-dev libssl-dev daemontools"
if [ $GITHUB_JOB = "run-benchmark" ]; then
	pip_packages="psycopg2-binary six testgres==1.8.9 python-telegram-bot matplotlib"
elif [ $GITHUB_JOB = "pgindent" ]; then
	pip_packages="psycopg2 six testgres==1.8.9 moto[s3] flask flask_cors boto3 pyOpenSSL yapf"
else
	pip_packages="psycopg2 six testgres==1.8.9 moto[s3] flask flask_cors boto3 pyOpenSSL"
fi

if [ $COMPILER = "clang" ]; then
	apt_packages="$apt_packages llvm-$LLVM_VER clang-$LLVM_VER clang-tools-$LLVM_VER"
fi

if [ $CHECK_TYPE = "static" ] || [ $COMPILER = "gcc" ]; then
	apt_packages="$apt_packages cppcheck"
fi

if [ $CHECK_TYPE = "valgrind_1" ] || [ $CHECK_TYPE = "valgrind_2" ]; then
	apt_packages="$apt_packages valgrind"
fi

# install required packages
sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y install -qq $apt_packages
sudo env "PATH=$PATH" pip3 install --upgrade $pip_packages

# install wal-g for postgres
wget https://github.com/wal-g/wal-g/releases/download/v3.0.0/wal-g-pg-ubuntu-20.04-amd64.tar.gz
tar -zxvf wal-g-pg-ubuntu-20.04-amd64.tar.gz
sudo mv wal-g-pg-ubuntu-20.04-amd64 /usr/local/bin/wal-g
rm wal-g-pg-ubuntu-20.04-amd64.tar.gz

# install minio
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# install minio client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
