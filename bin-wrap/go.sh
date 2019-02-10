#!/bin/sh
#
set -e

REL=1.11.5
DIR=/opt/$(whoami)/golang-$REL

export GOROOT=$DIR/go
export GOBIN=$DIR/gopath/bin
export GOPATH=$GOPATH${GOPATH:+:}$DIR/gopath
export GOCACHE=$DIR/gocache
export TMPDIR=$DIR/tmp

go=$GOROOT/bin/go

mkdir_if() {
  for d in "$@" ; do
    [ -d "$d" ] || mkdir -p "$d"
  done
}

install_go() {
  mkdir_if "$GOBIN" "$TMPDIR"

  local os=linux
  local arch=amd64
  local url="https://dl.google.com/go/go$REL.$os-$arch.tar.gz"

  echo "Installing to $DIR"
  echo "  from $url ..."
  curl -SL "$url" | tar -zxf - -C $DIR
}

[ -x "$go" ] || install_go

# Custom verb: build-static
if [ ":$1" = ":build-static" ] ; then
  shift
  export CGO_ENABLED=0
  go="$go build -ldflags -extldflags=-static"
fi

# Launch
PATH="$GOROOT/bin:$PATH" exec $go "$@"
