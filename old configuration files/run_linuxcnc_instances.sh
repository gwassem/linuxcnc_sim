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

# --- Set number of instances to 3 ---
INSTANCES=2
# "dev" opens terminals (interactive shells inside container)
TERMINALS="dev"
BASE_MACHINE_NAME="Lathe" # Must match the server's BASE_MACHINE_NAME

for i in $(seq 1 ${INSTANCES}); do
  NAME="cnc_${i}"
  MACHINE_ID="${BASE_MACHINE_NAME}_${i}" # e.g., "Lathe_1", "Lathe_2"
  HOST_CONFIG_DIR="$HOME/linuxcnc_sim/linuxcnc-configs/${NAME}"
  RUNTIME_DIR="/tmp/runtime-linuxcnc_${i}"

  mkdir -p "${HOST_CONFIG_DIR}"
  mkdir -p "${RUNTIME_DIR}"

  if [ "${TERMINALS}" = "dev" ]; then
    echo "[INFO] (interactive) Starting ${NAME} (ID: ${MACHINE_ID}) and opening a host terminal..."

    # Open a host terminal and run an interactive container shell (-it).
    x-terminal-emulator -e bash -lc "\
    docker run --rm --privileged -it \
      --name linuxcnc_instance_${i} \
      --add-host host.docker.internal:host-gateway \
      -e DISPLAY=${DISPLAY:-:0} \
      -e XDG_RUNTIME_DIR=${RUNTIME_DIR} \
      -e MACHINE_ID=\"${MACHINE_ID}\" \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      -v \"${HOST_CONFIG_DIR}\":/home/linuxcnc/linuxcnc/configs \
      -v \"${RUNTIME_DIR}\":\"${RUNTIME_DIR}\" \
      ${IMAGE_NAME} \
      linuxcnc /home/linuxcnc/linuxcnc/configs/axis_mm.ini
      bash" &

  else
    # Non-interactive branch
    echo "[INFO] Abrindo instância $i (${NAME}, ID: ${MACHINE_ID}) in detached mode..."
    
    docker run -d --rm --privileged \
      --name linuxcnc_instance_${i} \
      --add-host host.docker.internal:host-gateway \
      -e DISPLAY=${DISPLAY:-:0} \
      -e XDG_RUNTIME_DIR=${RUNTIME_DIR} \
      -e MACHINE_ID=\"${MACHINE_ID}\" \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      -v "${HOST_CONFIG_DIR}":/home/linuxcnc/linuxcnc/configs \
      -v "${RUNTIME_DIR}":"${RUNTIME_DIR}" \
      ${IMAGE_NAME} \
      linuxcnc /home/linuxcnc/linuxcnc/configs/axis_mm.ini
  fi
done

echo "[INFO] All instances started. Use 'docker ps' to verify."
