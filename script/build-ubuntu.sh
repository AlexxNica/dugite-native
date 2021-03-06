#!/bin/bash
#
# Compiling Git for Linux and bundling Git LFS from upstream.
#

SOURCE=$1
DESTINATION=$2

# i want to centralize this function but everything is terrible
# go read https://github.com/desktop/dugite-native/issues/38
computeChecksum() {
   if [ -z "$1" ] ; then
     # no parameter provided, fail hard
     exit 1
   fi

  path_to_sha256sum=$(which sha256sum)
  if [ -x "$path_to_sha256sum" ] ; then
    echo $(sha256sum $1 | awk '{print $1;}')
  else
    echo $(shasum -a 256 $1 | awk '{print $1;}')
  fi
}

echo " -- Building git at $SOURCE to $DESTINATION"

cd $SOURCE
make clean
DESTDIR="$DESTINATION" make install prefix=/ \
    NO_PERL=1 \
    NO_TCLTK=1 \
    NO_GETTEXT=1 \
    NO_OPENSSL=1 \
    NO_INSTALL_HARDLINKS=1 \
    CC='gcc' \
    CFLAGS='-Wall -g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -U_FORTIFY_SOURCE' \
    LDFLAGS='-Wl,-Bsymbolic-functions -Wl,-z,relro'
cd - > /dev/null

echo "-- Bundling Git LFS"
GIT_LFS_FILE=git-lfs.tar.gz
curl -sL -o $GIT_LFS_FILE $GIT_LFS_URL
shasum -a 256 $GIT_LFS_FILE | awk '{print $1;}'
COMPUTED_SHA256=$(computeChecksum $GIT_LFS_FILE)
if [ "$COMPUTED_SHA256" = "$GIT_LFS_CHECKSUM" ]; then
  echo "Git LFS: checksums match"
  SUBFOLDER="$DESTINATION/libexec/git-core"
  tar -xf $GIT_LFS_FILE -C $SUBFOLDER --exclude='*.sh' --exclude="*.md" --strip-components=1
else
  echo "Git LFS: expected checksum $GIT_LFS_CHECKSUM but got $COMPUTED_SHA256"
  echo "aborting..."
  exit 1
fi

# download CA bundle and write straight to temp folder
# for more information: https://curl.haxx.se/docs/caextract.html
echo "-- Adding CA bundle"
cd $DESTINATION
mkdir -p ssl
curl -sL -o ssl/cacert.pem https://curl.haxx.se/ca/cacert.pem
cd - > /dev/null
