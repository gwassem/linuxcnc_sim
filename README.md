# LinuxCNC Multi-Instance Fleet Simulation

## 1\. Overview

This project provides a complete, containerized environment for simulating a **fleet of multiple LinuxCNC machines** (three, by default). It is designed for testing and validating distributed monitoring and control systems.

The architecture is built around a central **OPC UA server** that acts as the single source of truth for the entire machine cell. Each simulated LinuxCNC machine runs independently in its own container, connects to this central server, and reports its real-time status (e.g., *Machine On*, *E-Stop Active*).

Finally, an **OpenSCADA** service provides a web-based dashboard, offering a top-down view of the entire fleet by consuming data from the OPC UA server.

## 2\. Repository Structure

```
linuxcnc_sim-main/
│
├── docker-compose.yml        # Master file: defines and launches all services.
├── Dockerfile                # Builds the LinuxCNC simulation container.
├── server.Dockerfile         # Builds the lightweight OPC UA server container.
│
├── host_opcua_server.py      # Python code for the central OPC UA server.
├── entrypoint.sh             # Helper script to start LinuxCNC inside its container.
├── requirements.txt          # Python requirements.
│
├── linuxcnc-configs/         # Directory for machine-specific configs.
│   ├── cnc_1/
│   │   ├── axis_mm.ini       # LinuxCNC config (axes, kinematics).
│   │   ├── opcua_postgui.hal # HAL file to load the OPC UA client.
│   │   └── hal_opcua_client.py # Python script (the OPC UA client).
│   ├── cnc_2/                # (Identical structure for machine 2)
│   └── cnc_3/                # (Identical structure for machine 3)
│
├── linuxcnc-nc_files/        # G-code files folder, connected by Samba.
│
├── openscada-config/
│   └── oscada.xml            # OpenSCADA configuration for the web dashboard.
│
└── Pictures/                 # Project images
```

## 3\. Architecture

The entire system is orchestrated by `docker-compose.yml` and runs on a dedicated bridge network (`cnc-net`) to allow services to communicate using their container names as hostnames.

The system consists of five key services:

1.  **`opcua-server` (The Hub):**

      * Built from `server.Dockerfile`, this is a minimal Python container running the `host_opcua_server.py` script.
      * It acts as the central data broker. Upon launch, it receives a command-line argument (`3`) instructing it to create an OPC UA namespace for three machines: `Lathe_1`, `Lathe_2`, and `Lathe_3`.

2.  **`linuxcnc-1`, `linuxcnc-2`, `linuxcnc-3` (The Machines):**

      * These three identical containers are the core simulations, built from the main `Dockerfile`.
      * This `Dockerfile` compiles LinuxCNC 2.9 from source and sets up a complete simulation environment.
      * Each container runs a full LinuxCNC instance with its `AXIS` GUI, which is displayed on the host's X11 server.
      * Crucially, each container also runs the `hal_opcua_client.py` script. This script connects to the `opcua-server` container and acts as a two-way "data bridge."

3.  **`openscada` (The Dashboard):**

      * This service runs a standard `dudanov/openscada` image.
      * Its configuration is loaded from `oscada.xml`, which instructs it to connect to `opc.tcp://opcua-server:4840/linuxcnc/` as a client.
      * It reads the status variables from all lathes and presents them on a simple web dashboard, accessible from the host.

### End-to-End Data Flow (Example)

1.  A user clicks the "Machine On" button in the **`linuxcnc-1`** GUI.
2.  A HAL signal (`halui.machine.is-on`) inside that container goes `True`.
3.  The `opcua_postgui.hal` file routes this signal to the `hal_opcua_client.py` script.
4.  The Python script, knowing its `MACHINE_ID` is `Lathe_1`, writes `True` to the `Lathe_1.Sensors.Machine_On` node on the central `opcua-server`.
5.  The `openscada` service, which is subscribed to this node, reads the change and updates the web dashboard at `http://localhost:8080`.

## 4\. Component Breakdown

### Key Files & Their Purpose

  * **`docker-compose.yml`**

      * **Purpose:** The master orchestration file. It defines all services, builds their respective images, connects them to the `cnc-net` network, and maps host volumes (like configuration files and X11 sockets). It is the single entry point for launching the entire simulation.

  * **`Dockerfile`**

      * **Purpose:** A "heavyweight" build script that installs all dependencies for, and compiles **LinuxCNC 2.9 from source** inside an `ubuntu:22.04` image. It also creates the `linuxcnc` user and sets up the environment required to run the simulation GUI.

  * **`server.Dockerfile`**

      * **Purpose:** A minimal, lightweight build script. It uses a `python:3.10-slim` image and installs *only* the `asyncua` library. This creates a fast-to-launch, low-resource container for the sole purpose of running the central server.

  * **`host_opcua_server.py`**

      * **Purpose:** The code for the central OPC UA server. It's an `asyncua` server that, when run, takes a number as an argument (e.g., `3`). It then dynamically builds a namespace containing an object for each machine (e.g., `Lathe_1`, `Lathe_2`, `Lathe_3`), each with its own `Sensors` and `Commands` variables.

  * **`hal_opcua_client.py`**

      * **Purpose:** This is the "data bridge" that runs *inside* each LinuxCNC container. It is a Python script that creates a HAL component (`opcua`) and also connects as a client to the central `opcua-server`. It continuously reads its HAL input pins (like `machine-status`) and writes those values to the OPC UA server, and vice-versa for commands.

  * **`opcua_postgui.hal`**

      * **Purpose:** A HAL configuration file loaded by LinuxCNC after the GUI starts. Its one and only job is to load the `hal_opcua_client.py` script as a real-time component (`loadusr`) and connect its HAL pins (e.g., `opcua.machine-status`) to the main LinuxCNC HAL signals (e.g., `halui.machine.is-on`).

  * **`axis_mm.ini`**

      * **Purpose:** The standard LinuxCNC configuration file. It defines the machine's properties (kinematics, axes limits, velocities) and, most importantly, specifies which HAL files to load (like `opcua_postgui.hal`).

  * **`oscada.xml`**

      * **Purpose:** The configuration file for the OpenSCADA service. It defines the data source (our `opcua-server`) and maps specific OPC UA nodes (e.t., `2:"Lathe_1.Sensors.Machine_On"`) to internal SCADA tags, which are then displayed on its web interface.

  * **`entrypoint.sh`**

      * **Purpose:** A utility script used by the `Dockerfile` to start the LinuxCNC container. It correctly sets up the `XDG_RUNTIME_DIR` and provides a flexible way to launch the `linuxcnc` command with the correct configuration file.

## 5\. Quick Start

This project is managed entirely by Docker Compose.

**Prerequisites:**

  * Docker
  * Docker Compose
  * An X11 server (for viewing the LinuxCNC GUIs)

**Launch:**

1.  **Clone the repository** (or ensure you are in the project's root directory).
2.  **Set up external volumes:** The `docker-compose.yml` file maps local directories (e.g., `$HOME/linuxcnc_sim/linuxcnc-configs`) into the containers. Ensure these directories exist on your host machine.
3.  **Launch the simulation stack:**
    ```bash
    docker-compose up --build
    ```
4.  **Observe:** You should see:
      * Three LinuxCNC `AXIS` GUIs appear on your desktop.
      * The `opcua-server` log showing it has configured 3 instances.
      * The OpenSCADA service start.

## 6\. Validation Plan

1.  **Launch:** Start the stack using `docker-compose up`.
2.  **Verify Connections:** Confirm three `AXIS` GUIs are visible and the `opcua-server` log is running.
3.  **Connect OPC UA Client:**
      * Use a client like UaExpert to connect to the server at: `opc.tcp://localhost:4840/linuxcnc/`
      * Verify you see `Lathe_1`, `Lathe_2`, and `Lathe_3` in the namespace, each with `Sensors` and `Commands` folders.
4.  **Connect SCADA Client:**
      * Open a web browser to `http://localhost:8080`.
      * You should see the OpenSCADA dashboard, showing the status of all three lathes (defaulting to 'False' or 'Off').
5.  **Test Instance 1 (CNC -\> SCADA):**
      * In the **`linuxcnc-1`** GUI, click the "Machine On" (F2) button.
      * **Expected Result:** Watch the `Lathe_1.Sensors.Machine_On` variable flip to `True` in UaExpert.
      * **Expected Result:** Watch the "Lathe 1 Machine On" status update to `True` on the OpenSCADA web dashboard.
6.  **Test Instance 2 (SCADA -\> CNC):**
      * In UaExpert, find the `Lathe_2.Commands.Execute_EStop` node, set it to `True`.
      * **Expected Result:** The **`linuxcnc-2`** GUI should immediately enter an E-Stop state. The `Lathe_2.Sensors.EStop_Active` node should flip to `True` in UaExpert and OpenSCADA.
