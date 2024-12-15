#!/usr/bin/env bash

set -x

WIRESHARK_BRANCH="release-4.4"

# Strict mode.
set -e -u -o pipefail

check_dependencies() {
  if ! command -v git &>/dev/null; then
    echo "git is not installed"
    exit 1
  fi

  if ! command -v cmake &>/dev/null; then
    echo "cmake is not installed"
    exit 1
  fi

  if ! command -v make &>/dev/null; then
    echo "make is not installed"
    exit 1
  fi
}

build_libs() {
  if [ -d wireshark ]; then
      cd wireshark
      branch_exists="$(git branch | grep -q "$WIRESHARK_BRANCH" ; echo $?)"
      cd ..

      if [ "$branch_exists" -ne 0 ]; then
          echo "Branch $WIRESHARK_BRANCH does not exist, removing wireshark directory."
          rm -rf wireshark
      fi
  fi

  if [ ! -d wireshark ]; then
      git clone --depth 1 -b "$WIRESHARK_BRANCH" https://gitlab.com/wireshark/wireshark.git
  fi
  cd wireshark

  if [ -d build ]; then
      rm -rf build
  fi
  mkdir build

  cd build

  cmake -DENABLE_APPLICATION_BUNDLE=OFF -DBUILD_androiddump=OFF -DBUILD_ciscodump=OFF -DBUILD_mmdbresolve=OFF -DBUILD_randpkt=OFF -DBUILD_randpktdump=OFF -DBUILD_sharkd=OFF -DBUILD_sshdump=OFF -DBUILD_wifidump=OFF -DBUILD_wireshark=OFF -DBUILD_tshark=OFF ..

  make -j$(nproc) epan
}

check_dependencies
build_libs
