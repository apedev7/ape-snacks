#!/bin/bash -e
#
# Automate the build, including all external dependencies
#
[ ":$1" = ":-static" ] && static_rtty=1

HERE=$(readlink -f $(dirname $0))
PDIR=$HERE/patches
BDIR=$HERE/scratch
IDIR=$BDIR/usr/local
LDIR=$IDIR/lib

# Component GIT-hash
#
libev_rel="dcd252e"
libuwsc_rel="5fe21b1"
rtty_rel="13f0ff3"

# Need abs-path in bwrap
export LIBTOOL=$(which libtool)
export CC=$(which gcc)

# Common setting to run cmake-generated aMakefiles
export VERBOSE=1

# Go into build dir
[ -d $BDIR ] || mkdir -p $BDIR
cd $BDIR

# Display then invoke the command
run() {
  (set -x && "$@")
}

# Invoke cmake in a controlled manner. See also
#  http://manpages.org/cmakevars/1
do_cmake() {
  local tools
  tools+=" -DCMAKE_FIND_ROOT_PATH=${BDIR}"
  tools+=" -DCMAKE_INSTALL_PREFIX=${IDIR}"
  tools+=" -DCMAKE_MAKE_PROGRAM=$(which make)"
  tools+=" -DCMAKE_C_COMPILER=${HERE}/cmake-cc.sh"
  tools+=" -DCMAKE_AR=$(which ar)"

  #local debug="--trace --trace-expand --debug-output"
  run $(which cmake) ${debug} "$@" ${tools}
}

# Build libev
build_libev() {
  local url="https://github.com/kindy/libev.git"
  local tag="${libev_rel}"
  local src="$BDIR/libev"
  local obj_d="${src}.obj-d"
  local obj_s="${src}.obj-s"
  local ac_s="${src}/src"
  local ac="${ac_s}/configure"

  # Fetch source
  if [ ! -d $src ] ; then
    cd $(dirname $src)
    run git clone $url $(basename $src)
    cd $src
    run git checkout -b locked $tag
  fi

  # Invoke automake in $src
  if [ ! -x $ac ] ; then
    cd $(dirname $ac)
    chmod +x ./autogen.sh  
    run ${ac_s}/autogen.sh
  fi

  # Invoke autoconf in $obj.
  # Have to build both .so and .a to satisfy libuwsc, whose 'install'
  # insists on building .so
  if [ ! -r $obj_d/Makefile ] ; then
    [ -d $obj_d ] || mkdir -p $obj_d
    cd $obj_d
    run $ac --prefix=$IDIR
  fi

  if [ ! -r $obj_s/Makefile ] ; then
    [ -d $obj_s ] || mkdir -p $obj_s
    cd $obj_s
    CFLAGS='-static' run $ac --prefix=$IDIR
  fi

  # Build in $obj
  run make -C $obj_d install
  run make -C $obj_s install
}

# Build libuwsc
build_libuwsc() {
  local url="https://github.com/zhaojh329/libuwsc.git"
  local tag="${libuwsc_rel}"
  local src="$BDIR/libuwsc"
  local obj="${src}.obj"

  # Fetch source
  if [ ! -d $src ] ; then
    cd $(dirname $src)
    run git clone --recursive $url $(basename $src)
    cd $src
    run git checkout -b locked $tag
  fi

  # Invoke cmake to prepare $obj
  if [ ! -r $obj/Makefile ] ; then
    [ -d $obj ] || mkdir -p $obj
    cd $src
    do_cmake . -B$obj -L
    do_cmake . -B$obj -LH
  fi

  # Build in $obj
  run make -C $obj uwsc_s uwsc
  run make -C $obj install

  # Hack: need to better way to find dep. libs
  local deps="-lssl -lcrypto"

  run cp $LDIR/libev.la $LDIR/libuwsc.la
  run sed -i $LDIR/libuwsc.la \
      -e "s/libev/libuwsc/g" \
      -e "/dependency_libs=/s/=.*$/=' ${deps}'/"
}

# Build rtty
build_rtty() {
  local url="https://github.com/zhaojh329/rtty.git"
  local tag="${rtty_rel}"
  local pch="${PDIR}/rtty-${tag}"
  local src="${BDIR}/rtty"
  local obj="${src}.obj"

  # Fetch source
  if [ ! -d $src ] ; then
    cd $(dirname $src)
    run git clone $url $(basename $src)
    cd $src
    run git checkout -b locked $tag
    if [ -d "${pch}" ] ; then
      run git am $(find ${pch} -type f | sort)
    fi
  fi

  # Remove '*.so' so the dep libraries are always static-linked into rtty.
  # No, -DCMAKE_FIND_LIBRARY_SUFFIXES=.a does not work!
  find $BDIR/usr -name '*.so*' | xargs rm

  # Invoke cmake to prepare $obj
  local extra
  if [ -n "${static_rtty}" ] ; then
    extra="-DCMAKE_EXE_LINKER_FLAGS=-static"
  fi

  if [ ! -r $obj/Makefile ] ; then
    [ -d $obj ] || mkdir -p $obj
    cd $src
    do_cmake . -B$obj ${extra}
  fi

  # Build in $obj
  run make -C $obj install
}

# Build the libraries needed by rtty
build_libev
build_libuwsc

# Build rtty
build_rtty
