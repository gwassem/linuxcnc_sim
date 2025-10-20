#!/usr/bin/env bash
IMAGE_NAME="linuxcnc-image"

# build image if missing
if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  echo "[INFO] Building ${IMAGE_NAME}..."
  docker build -t ${IMAGE_NAME} .
fi

# single instance
NAME="cnc_1"
HOST_CONFIG_DIR="$HOME/linuxcnc-configs/${NAME}"
RUNTIME_DIR="/tmp/runtime-linuxcnc_1"

mkdir -p "${HOST_CONFIG_DIR}" "${RUNTIME_DIR}"

echo "[INFO] If GUI windows don't appear, run on the host:  xhost +local:docker"

docker run --rm --privileged --ipc=host \
  --name "${NAME}" \
  -e DISPLAY="${DISPLAY:-:0}" \
  -e XDG_RUNTIME_DIR="${RUNTIME_DIR}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${HOST_CONFIG_DIR}":/home/linuxcnc/configs \
  -v "${RUNTIME_DIR}":"${RUNTIME_DIR}" \
  --entrypoint /bin/bash \
  "${IMAGE_NAME}" -c "\
mkdir -p '${RUNTIME_DIR}'; \
export XDG_RUNTIME_DIR='${RUNTIME_DIR}'; \
# run linuxcnc with the expected config; if missing, drop to shell for debugging \
if command -v linuxcnc >/dev/null 2>&1; then \
  linuxcnc /home/linuxcnc/configs/${NAME}/axis_mm.ini; \
else \
  echo 'linuxcnc binary not found inside the container. Dropping to shell.'; \
  bash; \
fi"

