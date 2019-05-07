#!/bin/bash -e
#
# Usage
#   git-tar REPO TREE-ISH ALL_OTHER_GIT_ARCHIVE_OPTIONS
#
# Simulate 'git archive --format=tar' for those remote-repos not
# supporting it.
#
repo="$1"
if [ -z "${repo}" ] ; then
  >&2 echo "Usage:"
  >&2 echo "  git-tar REPO TREE-ISH ALL_OTHER_GIT_ARCHIVE_OPTIONS... >TAR"
  exit 1
fi
shift

tag="$1"
if [ -z "${tag}" ] ; then
  tag="master"
else
  shift
fi

tmp="${TMP:-/tmp}"/$(whoami).git-tar.tmp-$$
rm -rf "${tmp}"

die() {
  [ -n "$1" ] && >&2 echo "$@"
  rm -rf "${tmp}"
  exit 1
}

git clone --bare --depth=1 --branch "${tag}" --single-branch \
    "${repo}" "${tmp}" || die

git --git-dir="${tmp}" archive HEAD "$@" || die
