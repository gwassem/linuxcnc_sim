#!/bin/bash
IMAGE_NAME="linuxcnc-image"

if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  echo "[INFO] Construindo imagem ${IMAGE_NAME}..."
  docker build -t ${IMAGE_NAME} .
fi

# Número de instâncias (ajuste conforme necessidade)
INSTANCES=1

for i in $(seq 1 $INSTANCES); do
  NAME="cnc_${i}"
  CONFIG_DIR="$HOME/linuxcnc-configs/${NAME}"

  echo "[INFO] Preparando diretório de configuração para $NAME..."
  mkdir -p "$CONFIG_DIR"

  echo "[INFO] Abrindo instância $i ($NAME)..."
  docker run -it --rm --privileged \
    --ipc=host \
    --name ${NAME} \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$CONFIG_DIR":/home/linuxcnc/linuxcnc/configs \
    ${IMAGE_NAME}
done

echo "[INFO] Todas as instâncias foram iniciadas. Use 'docker ps' para verificar."

