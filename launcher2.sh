#!/usr/bin/env bash

SAVED_ARGV=("$@")
DIRNAME=$(dirname "$0")
BINDIR="${DIRNAME}"
download_binary() {
  echo "downloading launcher2..."
  package="${BINDIR}/launcher2.tar.gz"
  package_md5="${BINDIR}/launcher2.tar.gz.md5"

  arch=none
  case $(uname -m) in
    aarch64 | arm64)
      arch=arm64
      ;;
    x86_64)
      arch=amd64
      ;;
    *)
      echo "ERROR: unsupported arch detected."
      exit 1
      ;;
  esac

  os=none
  case $(uname -o) in
    Darwin)
      os=darwin
      ;;
    GNU/Linux)
      os=linux
      ;;
    *)
      echo "ERROR: unsupported os detected."
      exit 1
      ;;
  esac

  curl -s -o ${package} -L https://github.com/discourse/discourse_docker/releases/download/latest/launcher2-latest-${os}-${arch}.tar.gz
  curl -s -o ${package_md5} -L https://github.com/discourse/discourse_docker/releases/download/latest/launcher2-latest-${os}-${arch}.tar.gz.md5

  echo "$(cat ${package_md5}) ${package}" | md5sum --status -c || (echo 'checksum failed' && exit 1)

  tar -zxf ${package} -C ${BINDIR}
  rm ${package} ${package_md5}
}

if [ ! -f "${BINDIR}/launcher2" ]; then
  download_binary
  echo "Launcher downloaded"
fi
exec "${BINDIR}/launcher2" "${SAVED_ARGV[@]}"
