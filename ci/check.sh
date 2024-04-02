#!/bin/bash

set -eux
export PATH="$GITHUB_WORKSPACE/pgsql/bin:$PATH"

# unsets limit for coredumps size
ulimit -c unlimited -S
# sets a coredump file pattern
mkdir -p /tmp/cores-$GITHUB_SHA-$TIMESTAMP
sudo sh -c "echo \"/tmp/cores-$GITHUB_SHA-$TIMESTAMP/%t_%p.core\" > /proc/sys/kernel/core_pattern"

# remember number of oom-killer visits in syslog before test
[ -f /var/log/system.log ] && syslogfile=/var/log/system.log || syslogfile=/var/log/syslog
[ -f $syslogfile ] && cat $syslogfile | grep oom-kill | wc -l > ./ooms.tmp \
					|| { echo "Syslog file not found"; status=1; }

mkdir ~/minio
minio server ~/minio --address :9000 --console-address :9001 &

while ! nc -z localhost 9000; do
  sleep 0.1
done

mc alias set 'local' 'http://127.0.0.1:9000' 'minioadmin' 'minioadmin'
# create bucket
mc mb local/test

saved_umask=$(umask)
umask u=rwx,g=rx,o=
sudo mkdir -p /etc/wal-g.d/env
echo 'DEVEL' | sudo tee /etc/wal-g.d/env/WALG_LOG_LEVEL > /dev/null

echo 'minioadmin' | sudo tee /etc/wal-g.d/env/AWS_SECRET_ACCESS_KEY > /dev/null
echo 'minioadmin' | sudo tee /etc/wal-g.d/env/AWS_ACCESS_KEY_ID > /dev/null
echo 's3://test' | sudo tee /etc/wal-g.d/env/WALG_S3_PREFIX > /dev/null
echo 'http://127.0.0.1:9000' | sudo tee /etc/wal-g.d/env/AWS_ENDPOINT > /dev/null
echo 'true' | sudo tee /etc/wal-g.d/env/AWS_S3_FORCE_PATH_STYLE > /dev/null
echo 'us-east-1' | sudo tee /etc/wal-g.d/env/AWS_REGION > /dev/null

echo 'localhost' | sudo tee /etc/wal-g.d/env/PGHOST > /dev/null
echo '5432' | sudo tee /etc/wal-g.d/env/PGPORT > /dev/null
echo "$USER" | sudo tee /etc/wal-g.d/env/PGUSER > /dev/null
echo "postgres" | sudo tee /etc/wal-g.d/env/PGDATABASE > /dev/null
# on real server you should use
# sudo chown -R root:postgres /etc/wal-g.d
# but for tests i'm using
sudo chown -R root:$USER /etc/wal-g.d
umask $saved_umask

initdb --no-locale -D ~/pgdata

echo "archive_mode = yes" >> ~/pgdata/postgresql.conf
echo "archive_command = 'envdir /etc/wal-g.d/env /usr/local/bin/wal-g wal-push %p'" >> ~/pgdata/postgresql.conf
echo "archive_timeout = 60" >> ~/pgdata/postgresql.conf
echo "restore_command = '/usr/bin/envdir /etc/wal-g.d/env /usr/local/bin/wal-g wal-fetch \"%f\" \"%p\" >> /tmp/wal.log 2>&1'" >> ~/pgdata/postgresql.conf
echo "shared_preload_libraries = 'orioledb'" >> ~/pgdata/postgresql.conf
echo "orioledb.main_buffers = 512MB" >> ~/pgdata/postgresql.conf
echo "orioledb.undo_buffers = 256MB" >> ~/pgdata/postgresql.conf
echo "max_wal_size = 8GB" >> ~/pgdata/postgresql.conf

# start server
pg_ctl -D ~/pgdata -l ~/logfile start

# check server
psql -d postgres -c "CREATE TABLE test(a int); INSERT INTO test VALUES (1), (5), (2);"
psql -d postgres -c "TABLE test;"

psql -d postgres -c "CREATE EXTENSION orioledb;"
psql -d postgres -c "CREATE TABLE o_test(a int) USING orioledb; INSERT INTO o_test VALUES (1), (5), (2);"
psql -d postgres -c "TABLE o_test;"

# to send more wal files
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "SELECT COUNT(*) FROM o_test;"
psql -d postgres -c "SELECT pg_switch_wal();"

echo ::group::Create your first physical backup
envdir /etc/wal-g.d/env /usr/local/bin/wal-g backup-push $HOME/pgdata
echo ::endgroup::

echo ::group::create replica
LAST_BACKUP=$(envdir /etc/wal-g.d/env /usr/local/bin/wal-g backup-list 2>/dev/null | tail -1 | cut -f1 -d' ')
envdir /etc/wal-g.d/env /usr/local/bin/wal-g backup-fetch ~/pgdata_backup $LAST_BACKUP
touch ~/pgdata_backup/standby.signal
echo "port=5433" >> ~/pgdata_backup/postgresql.conf
echo "recovery_target = 'immediate'" >> ~/pgdata_backup/postgresql.conf
echo ::endgroup::

pg_ctl -D ~/pgdata_backup -l ~backup_logfile start
psql -p 5433 -d postgres -c "SELECT COUNT(*) FROM o_test;"

# Stop replica
pg_ctl -D ~/pgdata_backup -l ~backup_logfile stop

# to send more wal files
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "SELECT COUNT(*) FROM o_test;"
psql -d postgres -c "SELECT pg_switch_wal();"

lsn_to_int () {
	echo $1 | awk --non-decimal-data 'BEGIN {OFS = FS} {split($0,a,"/"); high=lshift(sprintf("%d", "0x" a[1]), 32); low=sprintf("%d", "0x" a[2]); print high+low}'
}

# Get replica LSN (for example using pg_controldata command)
REPLICA_LSN=$(pg_controldata ~/pgdata_backup/ | grep "REDO location" | sed 's/.*: *//')
REPLICA_LSN_AS_NUM=$(lsn_to_int $REPLICA_LSN)

echo ::group::Start uploading incremental backup on master
envdir /etc/wal-g.d/env /usr/local/bin/wal-g catchup-push ~/pgdata --from-lsn $REPLICA_LSN_AS_NUM
echo ::endgroup::

echo ::group::accept catchup incremental backup
# To accept catchup incremental backup created by catchup-push, the user should pass the path to the replica Postgres directory and name of the backup.
LAST_CATCHUP=$(envdir /etc/wal-g.d/env /usr/local/bin/wal-g catchup-list 2>/dev/null | tail -1 | cut -f1 -d' ')
envdir /etc/wal-g.d/env /usr/local/bin/wal-g catchup-fetch ~/pgdata_backup $LAST_CATCHUP
echo ::endgroup::

# check
pg_ctl -D ~/pgdata_backup -l backup_logfile start
psql -p 5433 -d postgres -c "SELECT COUNT(*) FROM o_test;"

# to send more wal files
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "INSERT INTO o_test SELECT generate_series(1, 10000);"
psql -d postgres -c "SELECT COUNT(*) FROM o_test;"
psql -d postgres -c "SELECT pg_switch_wal();"

psql -p 5433 -d postgres -c "SELECT COUNT(*) FROM o_test;"

pg_ctl -D ~/pgdata_backup -l ~/backup_logfile stop
echo "recovery_target = ''" >> ~/pgdata_backup/postgresql.conf
pg_ctl -D ~/pgdata_backup -l ~/backup_logfile start

WAIT_LSN=$(lsn_to_int $(psql -d postgres -t -c "select pg_catalog.pg_current_wal_lsn()::text;" | head -1))
REPLICA_LSN=$(lsn_to_int $(psql -p 5433 -d postgres -t -c "SELECT pg_catalog.pg_last_wal_replay_lsn();" | head -1))
while [ $WAIT_LSN -gt $REPLICA_LSN ]; do
	REPLICA_LSN=$(lsn_to_int $(psql -p 5433 -d postgres -t -c "SELECT pg_catalog.pg_last_wal_replay_lsn();" | head -1))
  	sleep 0.1
done

psql -p 5433 -d postgres -c "SELECT COUNT(*) FROM o_test;"

echo ::group::primary log
cat ~/logfile
echo ::endgroup::

echo ::group::replica log
cat ~/backup_logfile
echo ::endgroup::

echo ::group::/tmp/wal.log
cat /tmp/wal.log
echo ::endgroup::
