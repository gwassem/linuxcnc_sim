#!/bin/bash
IMAGE_NAME="linuxcnc-image"

if ! docker images --format '{{.Repository}}' | grep -q "^${IMAGE_NAME}$"; then
  echo "[INFO] Construindo imagem ${IMAGE_NAME}..."
  docker build -t ${IMAGE_NAME} .
fi

#read -p "Quantas instâncias deseja abrir? " INSTANCES
#read -p "Quer abrir os terminais? " TERMINALS


for i in $(seq 1 1); do #$(seq 1 $INSTANCES); do
  NAME="cnc_${i}"
  CONFIG_DIR="$HOME/linuxcnc-configs/${NAME}"

  mkdir -p "$CONFIG_DIR"
#  if [$TERMINALS -eq s]; then
#     docker run -it --rm --privileged \
#     --ipc=host \
#     --name cnc_${i} \
#     -e DISPLAY=$DISPLAY \
#     -v /tmp/.X11-unix:/tmp/.X11-unix \
#     -v /home/linuxcnc-configs/cnc_${i}:/home/configs \
#     --entrypoint /bin/bash \
#     linuxcnc-2.9  &&\
#     exec x-terminal-emulator 
#  else
    echo "[INFO] Abrindo instância $i ($NAME)..."
     docker run -it --rm --privileged \
     --ipc=host \
     --name linuxcnc_instance_1 \
     -e DISPLAY=$DISPLAY \
     -v /tmp/.X11-unix:/tmp/.X11-unix \
     -v /home/linuxcnc-configs/linuxcnc_instance_1:/home/linuxcnc/configs \
     --entrypoint /bin/bash \
     linuxcnc-2.9
#  fi
done

echo "[INFO] Todas as instâncias foram iniciadas. Use 'docker ps' para verificar."



