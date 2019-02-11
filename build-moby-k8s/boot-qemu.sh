#!/bin/bash
#
set -e

# Use libvirt's 'default' network
br_name=virbr0

# Use boot.sh convention
if [ $# -eq 0 ] ; then
  vm_name=master
else
  vm_name=node-$1
fi

a_path=$(readlink -e $(dirname $0))

a_data=$a_path/kube-$vm_name-state
a_mac=$a_data/mac-addr
a_port=6443

# My extension
a_ip=$a_data/ip-addr
a_kc=$a_data/admin.conf
a_bl=$a_data/boot.log

# Execute a command inside the 'kubelet' container
kube_cmd() {
  local ia="$1"; shift
  local id=ssh-$(hostname)-$$

  local ns=services.linuxkit
  local cn=kubelet

  ssh \
    -o LogLevel=FATAL \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o IdentitiesOnly=yes \
    -i $a_path/admin_ssh_key \
    root@$ia \
      ctr --namespace $ns tasks exec --exec-id $id $cn "$@"
}

log() {
  echo "$(date +'%F %T.%3N') [$$]" "$@"
}

log_sleep() {
  local tag="$1"

  if [ ":$tag" != ":$log_sleep_tag" ] ; then
    log_sleep_tag="$tag"
    log_sleep_cnt=0
  fi

  [ "$((log_sleep_cnt % 5))" = "0" ] && log "$@"
  sleep 0.2

  log_sleep_cnt="$((log_sleep_cnt + 1))"
  return 0
}

# Extract ip-addr into file $a_ip
get_ip_addr() {
  rm -f $a_ip

  while [ ! -r "$a_mac" ] ; do
    log_sleep "Waiting for $a_mac"
  done
  local ma="$(cat $a_mac)"

  local ia
  while true ; do
    local a=( $(/bin/ip neigh show dev $br_name | grep "\s$ma\s") )
    if [ ":${a[2]}" = ":$ma" ] ; then
      ia="${a[0]}"
      /bin/ping -nr -c 1 -w 1 -W 1 $ia && break
    fi
    log_sleep "Waiting for IP of $br_name $ma"
  done

  echo "$ia" > $a_ip
}

# Extract admin's kube-config into file $a_kc
get_admin_conf() {
  rm -f $a_kc

  local ia="$(cat $a_ip)"
  local ep="$ia:$a_port"

  # Probe the API port, using simple http because there is no real data xfer
  while ! curl -sS "http://$ep" ; do
    log_sleep "Waiting for API-server at https://$ep"
  done
  
  kube_cmd "$ia" cat /etc/kubernetes/admin.conf > $a_kc.tmp
  mv $a_kc.tmp $a_kc
}

# Extract VM runtime config
get_master_conf() {
  local fn=${FUNCNAME[0]}

  rm -f $a_bl $a_ip $a_kc
  touch $a_bl
  log >>$a_bl "$fn: Start"

  get_ip_addr    >>$a_bl 2>&1
  get_admin_conf >>$a_bl 2>&1

  log >>$a_bl "$fn: Done"
  return 0
}

get_worker_conf() {
  local fn=${FUNCNAME[0]}

  rm -f $a_bl $a_ip
  touch $a_bl
  log >>$a_bl "$fn: Start"

  get_ip_addr    >>$a_bl 2>&1

  log >>$a_bl "$fn: Done"
  return 0
}

# Extract kube-node bootstrap token from master
get_join_token() {
  kube_cmd "$1" kubeadm token list \
    | awk '$0~/system:bootstrappers/ { print $1; }'
}

# Boot master VM
boot_kube_master() {
  [ -d "$a_data" ] || mkdir -p "$a_data"

  # Spawn background to extract running config from inside the VM
  get_master_conf &

  # Start VM with console attached
  export KUBE_MASTER_AUTOINIT=y
  export KUBE_NETWORKING=bridge,$br_name
  export PATH="$a_path:$PATH"
  exec $a_path/boot.sh "$@"
}

# Boot worker VM
boot_kube_worker() {
  local node_nr="$1" ; shift

  [ -d "$a_data" ] || mkdir -p "$a_data"

  local master_ip="$(cat $a_path/kube-master-state/ip-addr)"
  local jt="$(get_join_token $master_ip)"

  # Spawn background to extract running config from inside the VM
  get_worker_conf &

  # Start VM with console attached
  export KUBE_NETWORKING=bridge,$br_name
  export PATH="$a_path:$PATH"
  exec $a_path/boot.sh \
       "$node_nr" \
       --token $jt \
       --discovery-token-unsafe-skip-ca-verification \
       "$@" \
       $master_ip:$a_port
}

# Start VM with console attached
if [ "$vm_name" = "master" ] ; then
  boot_kube_master
else
  boot_kube_worker "$@"
fi
