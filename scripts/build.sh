#!/bin/bash
set -e

TARBALL_LIST=node_versions.list
CONFIGURE_OPTS="--dest-cpu=x64"
BUILDSCRIPT_ROOT_DIR=`pwd`
INSTALL_PFX=`pwd`/multi-nodejs/usr/local
LINK_PFX=`pwd`/multi-nodejs/usr/bin
PKG_NAME=multi-nodejs
INSTALL_LIST=

mkdir -p downloads 
mkdir -p build 
mkdir -p $INSTALL_PFX 
mkdir -p $LINK_PFX 

while read line
do
  PKG_VERSION=`echo $line | grep -oE 'node-v[0-9]*\.[0-9]*\.[0-9]*'`
  PKG_URL=`echo $line | cut -s -d'|' -f1`
  PKG_SHASUM=`echo $line | cut -s -d'|' -f2`
  echo "downloading $PKG_VERSION ..."
  curl $PKG_URL --output downloads/$PKG_VERSION.tar.gz ||
    { echo "failed to download $PKG_VERSION, please check $TARBALL_LIST"; exit 1; }
  echo "verifying $PKG_VERSION..."
  shasum -a1 downloads/$PKG_VERSION.tar.gz | grep $PKG_SHASUM >/dev/null ||
    { echo "sha1sum check for $PKG_VERSION failed, please check $TARBALL_LIST"; exit 1; }
  echo "extracting $PKG_VERSION ..."
  tar xf downloads/$PKG_VERSION.tar.gz -C build ||
    { echo "failed to extract $PKG_VERSION"; exit 1; }
  echo "configuring $PKG_VERSION ..."
  cd build/$PKG_VERSION
  ./configure --prefix=$INSTALL_PFX/$PKG_VERSION $CONFIGURE_OPTS ||
    { echo "failed to configure $PKG_VERSION"; exit 1; }
  echo "building $PKG_VERSION ..."
  make ||
    { echo "failed to build $PKG_VERSION"; exit 1; }
  echo "installing $PKG_VERSION in $INSTALL_PFX/$PKG_VERSION ..."
  make install || sudo make install ||
    { echo "could not install $PKG_VERSION"; exit 1; }
  cd $BUILDSCRIPT_ROOT_DIR
  echo "linking binaries to /usr/bin/$PKG_VERSION ..."
  for bin in `ls $INSTALL_PFX/$PKG_VERSION/bin/*`
  do
    ln -s /usr/local/$PKG_VERSION/bin/`basename $bin` $LINK_PFX/$PKG_VERSION-`basename $bin` ||
      { echo "failed to link $bin"; exit 1; }
  done
  echo "successfully built $PKG_VERSION"
  INSTALL_LIST="$INSTALL_LIST $INSTALL_PFX/$PKG_VERSION /usr/bin/$PKG_VERSION-*"
done < $TARBALL_LIST

echo "installed $INSTALL_LIST, packaging ... "
rm -rf $PKG_NAME/*.tar.gz
dpkg-deb --build $PKG_NAME
echo done.
