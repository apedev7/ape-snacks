#!/bin/sh
#
# Use bubblewrap (https://github.com/projectatomic/bubblewrap)
# for any user without CAP_SYS_CHROOT to create a chroot-like
# environment.
#
# Other than filesystem, all other namespaces are shared.
#
# If $0 is 'bwrap-sudo', UID/GID are unshared to simulate sudo
# without using sudo at all!
#
set -e

THIS_="$(basename $0)"
ROOT_DIR="$1"
EXEC_BIN="$2"

BWRAP_BIN=$HOME/bin/bwrap

die() {
  echo "Died: $1"
  exit 1
}

# Validate $1: root-dir
if [ -z "$ROOT_DIR" ] ; then
  ROOT_DIR=$(pwd)
else
  shift
  ROOT_DIR=$(readlink -e $ROOT_DIR)
  [ -d "$ROOT_DIR" ] || die "$ROOT_DIR: Not a directory!"
fi

# Validate $2: exec-bin
test_bin() {
  local exec="$ROOT_DIR/$1"
  local path="$(readlink -e $exec)"

  [ -x "$path" ] && return 0

  # Don't die if probe
  [ -n "$2" ] && return 1

  # Show cause of death
  [ -e "$path" ] || die "$exec: Path does not exist!"
  [ -f "$path" ] || die "$exec: Not a file!"
  die "$exec: Not executable!"
}

if [ -n "$EXEC_BIN" ] ; then
  shift
  test_bin "$EXEC_BIN"
else
  for x in bash ash sh csh zsh null ; do
    [ "$x" = "null" ] && die "$ROOT_DIR/bin: No shell!"
    if test_bin "/bin/$x" probe ; then
      EXEC_BIN="/bin/$x"
      break
    fi
  done
fi

if [ "$THIS_" = "bwrap-sudo" ] ; then
  # Also need CAP_SYS_CHROOT in new UID space to support package manager
  # such as alpine 'apk'
  SUDO='--unshare-user --uid 0 --gid 0 --cap-add CAP_SYS_CHROOT'
fi

robind_etc() {
  echo '--dir /etc'
  for n in \
      hostname \
      resolv.conf \
      hosts \
      networks \
      services \
      protocols \
      timezone \
  ; do
    p=/etc/$n
    [ -r "$p" ] && echo "--ro-bind $p $p"
  done
}

exec $BWRAP_BIN \
	$SUDO \
	--setenv PS1 "$THIS_"':\w \$ ' \
	--unsetenv PATH \
	--bind "$ROOT_DIR" / \
	--dir "$HOME" \
	--dir /proc --proc /proc     \
	--dir /dev  --dev  /dev      \
	--dir /sys  --bind /sys /sys \
	--dir /tmp  --bind /tmp /tmp \
        $(robind_etc) \
	$EXEC_BIN "$@"

