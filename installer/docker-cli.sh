#!/bin/sh
#
set -e

a_rel=18.06.1-ce

a_path=~/bin
app=$a_path/docker

a_site="https://download.docker.com/linux/static/stable/x86_64"
a_url="$a_site/docker-$a_rel.tgz"

echo "Install $app from $a_url ... "
curl -SL "$a_url" \
  | tar -zxf - docker/docker --to-stdout >$app.tmp

strip $app.tmp
chmod +x $app.tmp
mv $app.tmp $app
