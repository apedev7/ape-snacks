#!/bin/bash -e
#

kit_rel=v0.6
k8s_rel=7622bd4

a_path=/opt/$(whoami)/moby-k8s_g$k8s_rel
kit_app=$a_path/linuxkit
ssh_key=$a_path/admin_ssh_key

bld_dir=/scratch/$(whoami)/build-moby-k8s_g$k8s_rel
bld_src=$bld_dir/k8s_src
bld_tmp=$bld_dir/tmp

die() {
  echo >&2 "$@"
  exit 1
}

mkdir_if() {
  for d in "$@" ; do
    [ -d "$d" ] || mkdir -p "$d"
  done
}

rel_dir() {
  [ -d "$1" ] || die "$1: Not a directory!"
  [ -d "$2" ] || die "$2: Not a directory!"

  local twd="$(readlink -e $1)"
  local cwd="$(readlink -e $2)"

  python -c "import os.path, sys; print os.path.relpath('$twd', '$cwd')"
}

install_kit_app() {
  [ -x "$kit_app" ] && return 0

  mkdir_if "$a_path"

  # Local wrapper scripts
  local here="$(dirname $(readlink -e $0))"
  for s in \
    boot-qemu.sh \
    test-whalesay.yml \
  ; do
    cp -p "$here/$s" "$a_path/$s"
  done

  # External prebuilt
  local a_site="https://github.com/linuxkit/linuxkit"
  local a_rel="$kit_rel/linuxkit-linux-amd64"
  local a_url="$a_site/releases/download/$a_rel"

  # Use 'strip' to validate file as ELF
  echo >&2 "Installing $a_url ..."
  curl -SL "$a_url" -o "$kit_app.tmp"
  strip "$kit_app.tmp" || die "** Failed!"

  chmod +x "$kit_app.tmp"
  mv "$kit_app.tmp" "$kit_app"
}

install_k8s_src() {
  [ -d "$bld_src/.git" ] && return 0

  local repo="https://github.com/linuxkit/kubernetes.git"

  git clone --no-checkout "$repo" "$bld_src"
  (cd "$bld_src" && git checkout -b tagged $k8s_rel)
}

install_ssh_key() {
  if [ ! -r "$ssh_key" ] ; then
    ssh-keygen -t rsa -b 4096 -C 'admin@linuxkit' -N '' -f "$ssh_key"
  fi
  chmod 0600 "$ssh_key"

  # Patch build-yaml to use the key.  The patching may need adjusted
  # base on particular release
  local y=yml/kube.yml
  local k="$(rel_dir $a_path $bld_src)/$(basename $ssh_key).pub"

  echo $k
  (cd $bld_src && git checkout $y)
  sed -i "$bld_src/$y" -e 's:~/[.]ssh/id_rsa[.]pub:'"$k:"
}

build_k8s_iso() {
  # Must be able to reach a running docker engine
  [ -z "$DOCKER_HOST" ] && die "DOCKER_HOST: env undefined!"

  # Probe the API port using curl (instead of nc; http is good enough)
  curl -sS http:${DOCKER_HOST#tcp:} >/dev/null \
    || die "DOCKER_HOST: unresponsive at $DOCKER_HOST!"

  # Moby builder (linuxkit) puts scrap in $HOME/.moby (unconfigurable;
  # see src/cmd/linuxkit/moby/util.go::defaultMobyConfigDir()).
  #
  # So, change $HOME to this build's TMP
  mkdir_if "$bld_tmp"
  export TMP="$bld_tmp"
  export TMPDIR="$bld_tmp"

  HOME=$bld_tmp PATH="$a_path:$PATH" make -C $bld_src all

  # Copy artifacts to 'dist'
  for a in \
    boot.sh \
      ssh_into_kubelet.sh \
      kube-master.iso \
      kube-node.iso \
  ; do
    cp -p $bld_src/$a $a_path
  done

  return 0
}

install_kit_app
install_k8s_src
install_ssh_key
build_k8s_iso
