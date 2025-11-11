# LinuxCNC Multi-Instance Fleet Simulation

## Overview

This project simulates a **fleet of multiple LinuxCNC machines** (e.g., lathes) running in parallel. Each simulation runs inside its own Docker container.

A central **OPC UA server**, running on the host machine, monitors the status of every machine in the fleet. Each containerized simulation sends its status (like "Machine On" and "E-Stop") to this central server, allowing for single-point monitoring of the entire machine cell.

## Architecture

The system is composed of two main parts: the **Host Server** and the **Simulation Containers**.

1.  **Host Server (`host_opcua_server.py`):**
    * A Python server you run on your local machine.
    * It uses `asyncua` to create a central OPC UA endpoint.
    * It dynamically creates objects in its namespace for each machine (e.g., `Lathe_1`, `Lathe_2`).

2.  **Simulation Containers (`Dockerfile`):**
    * Each container runs a full, independent LinuxCNC 2.9 simulation.
    * Inside each container, a Python client (`hal_opcua_client.py`) connects the simulation's internal signals (HAL pins) to the host's OPC UA server.
    * A launcher script (`run_linuxcnc_instances.sh`) starts all containers.


### Data Flow
The data flows from the simulation's UI to the central server:
1.  A user clicks "Machine On" in a LinuxCNC GUI.
2.  The `halui.machine.is-on` pin goes `True`.
3.  `opcua_postgui.hal` connects this pin to the `opcua.machine-status` pin.
4.  The `hal_opcua_client.py` script reads this pin.
5.  The client sends the `True` value to the host server (e.g., to the `Lathe_1.Machine_On` OPC UA node).

## Key Components

* `host_opcua_server.py`: The central OPC UA data aggregation server.
* `run_linuxcnc_instances.sh`: Shell script to build and launch the LinuxCNC simulation containers.
* `Dockerfile`: Builds the container image with LinuxCNC 2.9 and all dependencies.
* `linuxcnc-configs/`: Contains all the simulation configuration files (INI, HAL).
* `hal_opcua_client.py`: (Runs *inside* container) The client that reads HAL pins and sends data to the host server.
* `opcua_postgui.hal`: (Runs *inside* container) Connects LinuxCNC's UI pins to the OPC UA client's pins.

## How to Run the Simulation

### Prerequisites
* Docker
* Python 3
* `asyncua` Python library
* An X11 server (standard on desktop Linux)

### Step 1: Install Host Dependencies
The host server requires the `asyncua` library.
```bash
# Installs asyncua and other dependencies
pip3 install -r requirements.txt
````

### Step 2: Build the Docker Image

The launcher script will do this for you, but you can run it manually:

```bash
docker build -t linuxcnc-image .
```

### Step 3: Run the Host OPC UA Server

You must start the central server first. The `run_linuxcnc_instances.sh` script is configured to launch **2** instances, so you **must** pass `2` as an argument.

Open a terminal and run:

```bash
python3 host_opcua_server.py 2
```

You should see it start and register nodes for `Lathe_1` and `Lathe_2`.

### Step 4: Run the LinuxCNC Instances

Open a **second terminal** and run the launcher script:

```bash
bash run_linuxcnc_instances.sh
```

This will open two new terminal windows, each launching a separate LinuxCNC instance. You will see two LinuxCNC (AXIS) GUIs appear.

## How to Verify

1.  **Check Server Logs:** The terminal from Step 3 should show messages like `[Lathe_1] OPC UA Write: ...` as it receives data.
2.  **Use an OPC UA Client:**
      * Use a client like **UaExpert** to connect to the host server.
      * **Endpoint:** `opc.tcp://localhost:4840/linuxcnc/`
      * You will see `Lathe_1` and `Lathe_2` in the address space.
3.  **Toggle Machine State:**
      * In the **cnc\_1** GUI, click the "Machine On" (F2) button.
      * In UaExpert, watch the `Lathe_1.Machine_On` variable flip to `True`.
      * In the **cnc\_2** GUI, click the "E-Stop" (F1) button.
      * In UaExpert, watch the `Lathe_2.Emergency_Stop` variable flip to `True`.

<!-- end list -->


---



## Initial Validation Plan

A formal validation test should consist of the following steps:
1.  **Launch:** Start the `host_opcua_server.py 2` and `run_linuxcnc_instances.sh` scripts.
2.  **Verify Connections:** Confirm two `AXIS` GUIs are visible and the host server log shows write messages from both `Lathe_1` and `Lathe_2`.
3.  **Connect Client:** Connect UaExpert (or other OPC UA client) to `opc.tcp://localhost:4840/linuxcnc/`.
4.  **Verify Namespace:** Confirm `Lathe_1` and `Lathe_2` objects exist with their `Machine_On` and `Emergency_Stop` children, all defaulting to `False`.
5.  **Test Instance 1:**
    * On the `cnc_1` GUI, press F2 to turn the machine on.
    * **Expected Result:** The `Lathe_1.Machine_On` node in UaExpert flips to `True`.
6.  **Test Instance 2:**
    * On the `cnc_2` GUI, press F1 to activate the E-Stop.
    * **Expected Result:** The `Lathe_2.Emergency_Stop` node in UaExpert flips to `True`.

This completes my initial documentation. I am ready to document further changes or create the "Researcher's Manual" based on this analysis.
````
