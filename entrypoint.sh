#!/bin/bash
# entrypoint.sh

# Diretório do host mapeado como volume
CONFIG_DIR=${INSTANCE_CONFIG_DIR:-/home/linuxcnc/configs}

# Criar configuração se não existir
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/sim.qtdragon" ]; then
    cp -r /usr/local/share/linuxcnc/configs/sim.qtdragon "$CONFIG_DIR/sim.qtdragon"
fi

echo "[INFO] Abrindo LinuxCNC com QtDragon usando configuração em '$CONFIG_DIR'..."
linuxcnc

