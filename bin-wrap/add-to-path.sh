#!/bin/bash -e
#
DEST=~/bin

HERE=$(dirname $(readlink -e $0))

die() {
  echo >&2 "$@"
  exit 1
}

add() {
  local t=$DEST/$1
  local w=$HERE/$2

  [ -z "$2" ] && w=$HERE/$1.sh

  [ -x "$w" ] || die "$w: Not an executable!"

  if [ -e "$t" ] ; then
    [ -L "$t" ] || die "$t: existing non-symlink!"

    rm "$t"
  fi

  ln -s "$w" "$t"
}

add bwrap-chroot
add bwrap-sudo bwrap-chroot.sh
add go go.sh
