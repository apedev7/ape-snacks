#!/bin/sh -e
#
# Add all packages needed to build 'rtty' for Alpine-Linux from the
# distro's minimal rootfs.
#
# This works for bwrap-based (https://github.com/projectatomic/bubblewrap)
# sudo-emulation ('--unshare-user --uid 0 --gid 0 --cap-add CAP_SYS_CHROOT').
#
add_sysroot() {
  major="3.9"
  minor=".3"
  arch="x86_64"
  site="http://dl-cdn.alpinelinux.org/alpine"
  home="v${major}/releases/${arch}"
  base="alpine-minirootfs-${major}${minor}-${arch}.tar.gz"

  here=`dirname $0`
  here=`readlink -f ${here}`
  dest="${here}/sysroot"

  if [ ! -d "${dest}/src" ] ; then
    mkdir -p "${dest}/src"
  fi

  cp "${here}"/*.sh "${dest}/src"
  rsync -a "${here}"/patches "${dest}/src"
  (set -x; curl -L "${site}/${home}/${base}" | tar zxf - -C "${dest}")
}

add_packages() {
  apk --no-cache add openssl
  exec apk --no-cache add --virtual "$1" \
       autoconf \
       automake \
       gcc \
       make \
       cmake \
       git \
       file \
       libtool \
       libc-dev \
       openssl-dev
}

case ":$1" in
  :sysroot)
    add_sysroot
    ;;
  :add)
    add_packages builder
    ;;
  :del)
    apk --no-cache del builder
    ;;
esac
