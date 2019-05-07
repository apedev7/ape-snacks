#!/bin/sh -e
#
# From:
#  https://stackoverflow.com/questions/17558221
#
commit="$1"
if [ -z "${commit}" ] ; then
  commit=HEAD
else
  shift
fi
exec git difftool "${commit}~1" "${commit}" "$@"
