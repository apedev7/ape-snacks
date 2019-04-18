#!/bin/sh
#
set -e

a_rel=1.12.1
a_root=/opt/$(whoami)/golang-$a_rel
a_path=$a_root/go/bin
app=$a_path/go

export GOROOT=$a_root/go
export GOBIN=$a_root/gopath/bin
export GOCACHE=$a_root/gocache
export GOTMPDIR=$a_root/tmp
export TMPDIR=$GOTMPDIR

export GOPATH=$GOPATH${GOPATH:+:}$a_root/gopath

# Add current to GOPATH if 'src' subdir exists
[ -d "${PWD}/src" ] && GOPATH="${PWD}:${GOPATH}"

mkdir_if() {
  for d in "$@" ; do
    [ -d "$d" ] || mkdir -p "$d"
  done
}

install_app() {
  mkdir_if "$GOBIN" "$GOTMPDIR"

  local os=linux
  local arch=amd64
  local url="https://dl.google.com/go/go$a_rel.$os-$arch.tar.gz"

  echo "Installing to $a_root"
  echo "  from $url ..."
  curl -SL "$url" | tar -zxf - -C $a_root
}

[ -x "$app" ] || install_app

# Custom verb: build-static
if [ ":$1" = ":build-static" ] ; then
  shift
  export CGO_ENABLED=0
  app="$app build -ldflags -extldflags=-static"
fi

# Launch
PATH="$a_path:$PATH" exec $app "$@"
