#!/usr/bin/env bash

GLIB_LIBRARY=$(echo "$CMAKE_LIBRARY_PATH" | tr ':' '\n' | grep glib | head -n 1)
GLIB_INCLUDE=$(echo "$CMAKE_INCLUDE_PATH" | tr ':' '\n' | grep glib | head -n 1)

clang -Wno-unused-command-line-argument -Xclang -ast-dump=json -fsyntax-only -fparse-all-comments \
  -I wireshark -I wireshark/include -I wireshark/epan -I wireshark/wsutil -I wireshark/build-"$(uname)" \
  -I "$GLIB_LIBRARY/glib-2.0/include" -I "$GLIB_INCLUDE/glib-2.0" \
  wireshark/epan/packet.h > wireshark-ast.json