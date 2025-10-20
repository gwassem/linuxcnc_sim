#!/usr/bin/env bash
# run_linuxcnc_instances.sh
# Preserves commands from your original script and launches linuxcnc in a terminal per instance.

IMAGE_NAME="linuxcnc-image"
FALLBACK_IMAGE="linuxcnc-2.9"

# Build image if missing (keeps your original behavior)
if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  echo "[INFO] Construindo imagem ${IMAGE_NAME}..."
  docker build -t ${IMAGE_NAME} .
fi

#read -p "Quantas instâncias deseja abrir? " INSTANCES
#read -p "Quer abrir os terminais? " TERMINALS

# Default values (change if you want)
INSTANCES=3
# Use "s" to open terminals and start linuxcnc inside each container (this matches your original interactive branch).
TERMINALS="n"

for i in $(seq 1 ${INSTANCES}); do
  NAME="cnc_${i}"
  HOST_CONFIG_DIR="$HOME/linuxcnc-configs/${NAME}"
  RUNTIME_DIR="/tmp/runtime-linuxcnc_${i}"

  mkdir -p "${HOST_CONFIG_DIR}"
  mkdir -p "${RUNTIME_DIR}"

  # If user wanted interactive terminals (your commented branch), run that variant:
  if [ "${TERMINALS}" = "s" ]; then
    echo "[INFO] (interactive) Starting ${NAME} and opening a host terminal that runs linuxcnc inside the container..."

    # Use x-terminal-emulator to open a terminal on the host that executes the docker run command.
    # The docker container will run /bin/bash -c "linuxcnc <config>" so linuxcnc runs inside the container.
    # We set XDG_RUNTIME_DIR and bind it so multiple instances don't conflict.
    x-terminal-emulator -e bash -lc "\
docker run --rm --privileged --ipc=host \
  --name linuxcnc_instance_${i} \
  -e DISPLAY=${DISPLAY:-:0} \
  -e XDG_RUNTIME_DIR=${RUNTIME_DIR} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v \"${HOST_CONFIG_DIR}\":/home/linuxcnc/configs \
  --entrypoint /bin/bash \
  ${FALLBACK_IMAGE} -c '\
mkdir -p \"${RUNTIME_DIR}\"; \
export XDG_RUNTIME_DIR=\"${RUNTIME_DIR}\"; \
# Attempt to run linuxcnc with the config for this instance (falls back to shell if not found) \
if command -v linuxcnc >/dev/null 2>&1; then \
  linuxcnc /home/linuxcnc/configs/${NAME}/axis_mm.ini || bash; \
else \
  echo \"linuxcnc binary not found inside image ${FALLBACK_IMAGE}. Dropping to shell.\"; \
  bash; \
fi' " &

  else
    # Non-interactive branch (keeps full original docker run shape but detached)
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
      # note: container command is image's default CMD; if that exits, container will exit
  fi
done

echo "[INFO] All instances started. Use 'docker ps' to verify."

