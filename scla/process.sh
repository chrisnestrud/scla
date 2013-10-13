#!/bin/sh
# Usage: process port base
# Example: process 8300 20050323
echo "Processing $1 with base $2"
mkdir -p ~/servers/$1/logs
if [ -f ~/servers/$1/server.log ]; then
mv ~/servers/$1/server.log ~/servers/$1/logs/$2.log
kill -HUP `cat ~/servers/$1/server.pid`
cat ~/servers/$1/starts ~/servers/$1/logs/$2.log > $1.tmp
rm ~/servers/$1/starts
perl slog.pl new.db $1.tmp fast.streammadness.com $1
rm $1.tmp
grep "starting stream" ~/servers/$1/logs/$2.log > ~/servers/$1/starts
bzip2 -9 ~/servers/$1/logs/$2.log
fi

