#!/usr/bin/env bash
set -euo pipefail

# default runtime dir (can be overridden by -e XDG_RUNTIME_DIR=... when running container)
: "${XDG_RUNTIME_DIR:=/tmp/runtime-linuxcnc}"
mkdir -p "$XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR

# default config path (override with -e LINUXCNC_CONFIG=/home/linuxcnc/configs/cnc_1/axis_mm.ini)
CONFIG_PATH="${LINUXCNC_CONFIG:-/home/linuxcnc/configs/default/axis_mm.ini}"

# If linuxcnc exists in image, decide what to exec
if command -v linuxcnc >/dev/null 2>&1; then
  if [ $# -eq 0 ]; then
    # no args -> start linuxcnc with default config
    exec linuxcnc "$CONFIG_PATH"
  else
    case "$1" in
      bash|sh|/bin/bash|/bin/sh)
        # user explicitly asked for a shell -> give it
        exec "$@"
        ;;
      linuxcnc)
        # user passed linuxcnc + args -> run exactly that
        exec "$@"
        ;;
      *)
        # any other arguments -> treat them as linuxcnc args (common case: path to config)
        exec linuxcnc "$@"
        ;;
    esac
  fi
else
  echo "linuxcnc binary not found in image. Dropping to shell."
  exec bash
fi

