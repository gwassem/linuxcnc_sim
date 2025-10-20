FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# =============================
# Dependências principais
# =============================
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential cmake autoconf automake libtool intltool gettext bwidget \
    tcl8.6-dev tk8.6-dev tclx8.4 tclx8.4-dev bwidget \
    python3-dev python3-tk python3-pyqt5 python3-opengl python3-pip python3-xlib \
    python3-gi python3-gi-cairo gir1.2-pango-1.0 python3-pyqt5.qtsvg python3-pyqt5.qtwebengine \
    libreadline-dev libncurses-dev libudev-dev libmodbus-dev libusb-1.0-0-dev \
    libglu1-mesa-dev libgl1-mesa-dev libgl1-mesa-glx libglib2.0-dev libepoxy-dev \
    libgpiod-dev libgtk-3-dev libgtk2.0-dev \
    libxmu-dev libboost-all-dev \
    asciidoc python3-docutils xmlto \
    qtbase5-dev qtbase5-dev-tools libqt5svg5-dev libqt5opengl5-dev \
    locales xauth x11-apps sudo x11-apps psmisc \
    && rm -rf /var/lib/apt/lists/*

# =============================
# Yapps2 (necessário para parser)
# =============================
RUN pip3 install --no-cache-dir yapps2

# =============================
# Criar usuário linuxcnc
# =============================
# CHANGED: fixed user home, UID, and removed wrong /home/sidney
RUN useradd -ms /bin/bash -u 1000 linuxcnc && \
    echo "linuxcnc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# CHANGED: ensure user dirs exist with proper permissions
RUN mkdir -p /home/linuxcnc/.config /home/linuxcnc/linuxcnc && \
    chown -R linuxcnc:linuxcnc /home/linuxcnc

# CHANGED: setup environment for QtVCP
ENV USER=linuxcnc
ENV HOME=/home/linuxcnc
ENV LINUXCNC=/usr/local
ENV LINUXCNC_HOME=/home/linuxcnc/linuxcnc
ENV XDG_RUNTIME_DIR=/tmp/runtime-linuxcnc

# CHANGED: prepare runtime dir
RUN mkdir -p /tmp/runtime-linuxcnc && \
    chown -R linuxcnc:linuxcnc /tmp/runtime-linuxcnc && \
    chmod 700 /tmp/runtime-linuxcnc

# =============================
# Instalar LinuxCNC
# =============================
USER linuxcnc
WORKDIR /home/linuxcnc

# Clonar LinuxCNC 2.9
RUN git clone -b 2.9 https://github.com/LinuxCNC/linuxcnc.git

WORKDIR /home/linuxcnc/linuxcnc/src

# Compilar LinuxCNC 2.9 usando autotools
RUN ./autogen.sh && \
    ./configure --with-realtime=uspace \
                --prefix=/usr/local \
                --enable-non-distributable=yes \
                --disable-gtk2 && \
    make -j$(nproc) && \
    sudo make install && \
    sudo ldconfig && \
    sudo make setuid

# =============================
# Entrypoint
# =============================
COPY entrypoint.sh /home/linuxcnc/entrypoint.sh
RUN sudo chmod +x /home/linuxcnc/entrypoint.sh
ENTRYPOINT ["/home/linuxcnc/entrypoint.sh"]

WORKDIR /home/linuxcnc

