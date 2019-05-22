#!/bin/sh -e
#
# Bind cmake compiler to libtool so that .la can be used
#
# For Alpine-Linux rootfs inside project-atomic bwrap, both
# gcc and libtool must be invoked with abs-path.
#
cc="$(which cc)"

# Use 'gcc' (and not 'libtool') unless '.a' is/are given
#
no_a() {
  test ":0" = ":$(echo $@ | tr ' ' '\n' | grep '[.]a$' | wc -l)"
}

to_la() {
  echo "$@" | tr ' ' '\n' | sed 's/[.]a$/.la/'
}

if no_a "$@" ; then
  set -x
  exec ${cc} $static "$@"
fi

# libtool has to use '-all-static' instead of '-static'
if [ "-$1" = "--static" ] ; then
  shift
  static="-all-static"
fi
  
args="$(to_la $@)"
cc="$(which libtool) --tag=CC --mode=link ${cc}"

set -x
exec ${cc} $static $args
