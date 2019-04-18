#!/bin/sh
#
# Tips
# -- Use 'docker-machine ssh NAME' to enter the machine.
# -- Use 'sudo -i' to become root once inside the machine.
#
# Known issues
# -- https://github.com/docker/machine/pull/4034
#    'libmachine/provision/boot2docker.go::AttemptIPContact()" emits
#    the "This machine has been allocated an IP address ..." warning
#    because the code should have called provision.Driver.GetURL().
#
#    It is harmless and can be ignored.
#
set -e

core_rel=0.16.1
drvr_rel=bab75de

a_root=/scratch/$(whoami)/docker-machine-v$core_rel-qemu-g$drvr_rel
a_path=$a_root/bin
a_data=$a_root/var
a_home=$HOME/.docker/machine

app=$a_path/docker-machine

a_qemu=qemu-system-x86_64


die() {
  echo >&2 "$@"
  exit 1
}

mkdir_if() {
  for d in "$@" ; do
    [ -d "$d" ] || mkdir -p "$d"
  done
}

slink_if() {
  local t="$1"
  local h="$2"

  local p="$(readlink -e $h)"
  [ ":$p" = ":$t" ] && return 0

  # Relink only if exists as a symlink
  if [ -e "$h" ] ; then
    [ -h "$h" ] || die "$h: Exists as non-symlink!"
    rm "$h"
  fi

  mkdir_if "$(dirname $h)"
  ln -s "$t" "$h"
}
  
has_kvm() {
  local p="/dev/kvm"

  [ -w $p ] && return 0
  [ -e $p ] || die "$p: Does not exist!"

  local u="user $(whoami)"
  local g="$(stat --format=%G $p)"
  [ -z "$(id -nG | grep $g)" ] || die "$p: non-writable by $u"

  die "$p: $u is not in kvm group '$g'!"
}

has_qemu() {
  local q=$qemu
  local p="$(which $q)"

  [ -z "$p" ] && die "$q: Not in your PATH!"
  [ -x "$p" ] || die "$p: Not executable!"

  qemu=$p
  return 0
}

wrap_qemu_system() {
  # Inject a wrapper for qemu-system to add additional host-port redirects
  # for user-mode network.
  local qi=qemu-wrapper
  local qx="$a_path/$qi"
  cat <<'EOF' | sed "s:bin=:bin=$qemu:" > "$qx.tmp"
#!/bin/sh
# Workaround for missing
#  https://github.com/ipatch/docker-machine-driver-qemu/commit/1d6b42f
set -e

bin=

[ ":$1" = ":resize" ] && exec $bin "$1" "$2" "${3%MB}M"
exec $bin "$@"
EOF
  chmod +x "$qx.tmp"
  mv "$qx.tmp" "$qx"
}

wrap_qemu_img() {
  # Need to inject a wrapper for qemu-img to work around the driver bug
  # (https://github.com/ipatch/docker-machine-driver-qemu/commit/1d6b42f)
  # not fixed in the downloaded prebuilt.
  local qi=qemu-img
  local qx="$a_path/$qi"
  cat <<'EOF' | sed "s:bin=:bin=$(which $qi):" > "$qx.tmp"
#!/bin/sh
# Workaround for missing
#  https://github.com/ipatch/docker-machine-driver-qemu/commit/1d6b42f
set -e

bin=

[ ":$1" = ":resize" ] && exec $bin "$1" "$2" "${3%MB}M"
exec $bin "$@"
EOF
  chmod +x "$qx.tmp"
  mv "$qx.tmp" "$qx"
}

install_app() {
  [ -x "$app" ] && return 0

  echo "Installing to $a_root ..."
  mkdir_if $a_path

  local a_site="https://github.com/docker/machine"
  local a_rel="v$core_rel/docker-machine-$(uname -s)-$(uname -m)"
  local a_url="$a_site/releases/download/$a_rel"

  # Updated pre-built QEMU driver only available from its maintainer
  local q_name="docker-machine-driver-qemu"
  local q_site="https://github.com/afbjorklund/$q_name"
  local q_rel="$drvr_rel/$q_name-$drvr_rel.linux-amd64.tar.gz"
  local q_url="$q_site/releases/download/$q_rel"

  # Fetch driver first
  echo "Fetching $q_url ..."
  curl -SL "$q_url" | tar -zxf - -C "$a_root"

  echo "Fetching $a_url ..."
  curl -SL "$a_url" -o "$app.tmp"
  chmod +x "$app.tmp"
  mv "$app.tmp" "$app"
}

install_app
mkdir_if $a_data
slink_if $a_data $a_home

cmd="$1"
if [ -n "$cmd" ] ; then
  shift
  case "$cmd" in
    create)
      has_kvm
      cmd="$cmd --driver qemu"
      ;;
  esac
fi

PATH="$a_path:$PATH" exec $app $cmd "$@"
