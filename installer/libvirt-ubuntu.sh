#!/bin/bash -e
#
# Automate Ubuntu installation of a usable libvirt+qemu+kvm environment
#
# May need to either:
# a) Modify user=$SUDO_USER and group=kvm in /etc/libvirt/qemu.conf
# b) chmod o+rx for all components in the path to all images
#

# Function invoked as EDITOR for 'virsh net-edit default', because
# 'virsh net-update modify' does not support the changes to DHCP
# configurations for guests.
#
net_edit() {
  local _xml="$2"

  # Customize the IP address range of NAT'ed guests
  local _dhcp_start="172.16.100.1"
  local _dhcp_end="172.16.199.254"
  local _dhcp_server="172.16.255.254"
  local _dhcp_netmask="255.255.0.0"

  sed -i "$_xml" \
      -e "/<ip /s/ address=[^ ]*/ address='$_dhcp_server'/" \
      -e "/<ip /s/ netmask=[^/>]*/ netmask='$_dhcp_netmask'/" \
      -e "/<range /s/ start=[^ ]*/ start='$_dhcp_start'/" \
      -e "/<range /s/ end=[^/>]*/ end='$_dhcp_end'/" \
  || exit 1
  exit 0
}

[ ":$1" = ":--net-edit" ] && net_edit "$@"

if [ ":$(id -u)" != ":0" ] ; then
  echo >&2 "Error: this must run as root (or sudo)!"
  exit 1
fi

# Install the packages
LIBVIRT_BIN="libvirt-daemon-system libvirt-clients"
[ "1" = "$(echo $(lsb_release -rs) '< 18.10' | bc)" ] \
  && LIBVIRT_BIN=libvirt-bin

apt-get update
apt-get install \
    qemu-utils qemu-system-x86 \
    $LIBVIRT_BIN virt-manager \
    dnsmasq-utils

# Modify the libvirt DHCP setting, by recursion into this script again
# as the EDITOR.
virsh net-destroy default
EDITOR="$0 --net-edit" virsh net-edit default
virsh net-autostart default
virsh net-start default

# Put 'real-user' into the required groups
if [ -n "$SUDO_USER" ] ; then
  for g in \
    fuse \
    libvirtd libvirt \
    kvm \
  ; do
    getent group $g && adduser $SUDO_USER $g
  done
fi

# Make libvirt's 'default' network accessible to standalone 'qemu'
qb_cdir=/etc/qemu
qb_conf=$qb_cdir/bridge.conf
if [ ! -e $qb_conf ] ; then
  [ -d $qb_cdir ] || mkdir -p $qb_cdir 
  touch $qb_conf
fi
if ! grep -q 'allow\s\s*virbr0' $qb_conf 2>/dev/null ; then
  echo 'allow virbr0' >> $qb_conf
fi
chmod u+s /usr/lib/qemu/qemu-bridge-helper

# Disable bridging from using iptables.  This one is tricky to be persistent,
# See http://wiki.libvirt.org/page/Net.bridge-nf-call_and_sysctl.conf
modprobe bridge
if [ -d /proc/sys/net/bridge/ ] ; then
  sysctl net.bridge.bridge-nf-call-iptables=0
  sysctl net.bridge.bridge-nf-call-ip6tables=0
else
  echo "If br_netfilter module is loaded"
fi

cat <<EOF
You must manually make the following sysctl entries persistent
   net.bridge.bridge-nf-call-iptables=0
   net.bridge.bridge-nf-call-ip6tables=0
See also:
   http://wiki.libvirt.org/page/Net.bridge-nf-call_and_sysctl.conf
   http://unix.stackexchange.com/questions/136918/why-does-my-firewall-iptables-interfere-in-my-bridge-brctl
EOF
