#!/bin/bash
ip="$(minikube ip)"
key="$(minikube ssh-key)"
cnf="$(dirname ${key})/config.ssh"

cnf_file() {
  cat <<EOF
GatewayPorts yes
ForwardAgent no
ForwardX11 no
ForwardX11Trusted no
KeepAlive yes
NoHostAuthenticationForLocalhost yes
StrictHostKeyChecking no
UserKnownHostsFile /dev/null

Host minikube
  User docker
  HostName ${ip}
  IdentityFile ${key}
EOF
}

cnf_refresh() {
  # Check for freshness of current config.
  # Fake with /dev/null if no config at all.
  local c_src=${cnf}
  [ -r "${c_src}" ] || c_src="/dev/null"

  local c_ip="$(sed -n 's/^\s*HostName\s\s*//p' ${c_src})"
  local c_key="$(sed -n 's/^\s*IdentityFile\s\s*//p' ${c_src})"

  # Remain good if both match
  [ ":${c_ip}" = ":${ip}" -a ":${c_key}" = ":${key}" ] && return 0

  # Now create one
  c_src=${cnf}.$$

  # Move it in place. No race with concurrent one because the
  # file will be the same freshness
  cnf_file > ${c_src} && mv ${c_src} ${cnf} && return 0

  # Bad
  return 1
}

# Refresh the ssh-config file and run scp
cnf_refresh || exit 1

[ -n "${DEBUG_MINIKUBE_SSH}" ] && cat ${cnf} && set -x
exec scp -F ${cnf} "$@"
