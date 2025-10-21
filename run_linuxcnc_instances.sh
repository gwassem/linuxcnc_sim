#!/usr/bin/env bash
# run_linuxcnc_instances.sh
# Launch linuxcnc containers; interactive terminals let you get a shell inside each container.

IMAGE_NAME="linuxcnc-image"
FALLBACK_IMAGE="linuxcnc-2.9"

# Build image if missing
if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  echo "[INFO] Construindo imagem ${IMAGE_NAME}..."
  docker build -t ${IMAGE_NAME} .
fi

# Default values
INSTANCES=3
# "s" opens terminals (interactive shells inside container)
TERMINALS="s"

for i in $(seq 1 ${INSTANCES}); do
  NAME="cnc_${i}"
  HOST_CONFIG_DIR="$HOME/linuxcnc-configs/${NAME}"
  RUNTIME_DIR="/tmp/runtime-linuxcnc_${i}"

  mkdir -p "${HOST_CONFIG_DIR}"
  mkdir -p "${RUNTIME_DIR}"

  if [ "${TERMINALS}" = "s" ]; then
    echo "[INFO] (interactive) Starting ${NAME} and opening a host terminal with an interactive shell inside the container..."

    # Open a host terminal and run an interactive container shell (-it).
    # You will get a bash prompt inside the container and can run/edit/check anything there.
    # Note: use a different container name suffix for interactive mode to avoid name collisions.
    x-terminal-emulator -e bash -lc "\
docker run --rm --privileged --ipc=host -it \
  --name linuxcnc_instance_${i}_interactive \
  -e DISPLAY=${DISPLAY:-:0} \
  -e XDG_RUNTIME_DIR=${RUNTIME_DIR} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v \"${HOST_CONFIG_DIR}\":/home/linuxcnc/configs \
  -v \"${RUNTIME_DIR}\":\"${RUNTIME_DIR}\" \
  ${IMAGE_NAME} \
  bash" &

  else
    # Non-interactive branch (unchanged)
    echo "[INFO] Abrindo instância $i ($NAME) in detached mode..."
    docker run -d --rm --privileged \
      --ipc=host \
      --name linuxcnc_instance_${i} \
      -e DISPLAY=${DISPLAY:-:0} \
      -e XDG_RUNTIME_DIR=${RUNTIME_DIR} \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      -v "${HOST_CONFIG_DIR}":/home/linuxcnc/configs \
      -v "${RUNTIME_DIR}":"${RUNTIME_DIR}" \
      ${IMAGE_NAME} \
      linuxcnc
  fi
done

echo "[INFO] All instances started. Use 'docker ps' to verify."

