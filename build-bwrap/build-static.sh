#!/bin/sh
#
set -e

REL=0.3.1

BLD=$(dirname $(readlink -e $0))/bld

get_src() {
  [ -x "$BLD/configure" ] && return 0

  [ -d "$BLD" ] || mkdir "$BLD"

  local site="https://github.com/projectatomic/bubblewrap"
  local path="v$REL/bubblewrap-$REL.tar.xz"
  local url="$site/releases/download/$path"

  echo "Fetching $url ..."
  curl -SL "$url" | tar -Jxvf - -C $BLD --strip 1
}

get_src
cd $BLD
CFLAGS='-static' ./configure
make
strip ./bwrap

echo "Done.  Copy following to your PATH"
echo " $(readlink -e ./bwrap)"
