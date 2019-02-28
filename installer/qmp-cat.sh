#!/bin/bash -e
#
# Combine dependencies into a single Python script
#
a_path=~/bin
a_qmp=$a_path/qmp-cat
a_hmp=$a_path/hmp-cat

header() {
  cat <<'EOF'
#!/usr/bin/python
#
# Usage examples:
#   qmp-cat --path=QEMU_MONITOR_SOCKET human-monitor-command --command-line="info usernet"
#   qmp-cat --path=QEMU_MONITOR_SOCKET human-monitor-command --command-line="help hostfwd_add"
#   qmp-cat --path=QEMU_MONITOR_SOCKET human-monitor-command --command-line="help hostfwd_remove"
#
EOF
}

qemu_scripts() {
  local site='https://github.com/qemu/qemu/raw/stable-2.12/scripts/qmp'
  local lib="$site/qmp.py"
  local cmd="$site/qmp"

  curl -L "$lib"
  printf "\n"
  curl -L "$cmd" | sed '/import QEMUMonitorProtocol/d'
}

install_qmp() {
  local tmp=${a_qmp}.tmp
  header >$tmp
  qemu_scripts >>$tmp
  chmod +x $tmp
  mv $tmp $a_qmp
}

install_hmp() {
  local tmp=${a_hmp}.tmp
  cat >$tmp <<'EOF'
#!/bin/sh
#
# Usage:
#   hmp-cat QEMU_MONITOR_SOCKET "hmp command"
#
here=$(readlink -f $(dirname $0))
sock="${1}"

die() {
  echo >&2 "$@"

  cat >&2 <<USAGE
Usage:
  hmp-cat QEMU_MONITOR_SOCKET HMP_COMMAND [HMP_ARGS ...]
USAGE
  exit 1
}

[ -z "$sock" ] && die "QEMU_MONITOR_SOCKET missing"
[ -S "$sock" ] && die "$sock: Not a unix socket"

shift
exec $here/qmp-cat --path="${1}" human-monitor-command --command-line='${@}'
EOF
  chmod +x $tmp
  mv $tmp $a_hmp
}

install_qmp
install_hmp
