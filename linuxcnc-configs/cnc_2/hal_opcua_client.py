import asyncio
import hal
import sys
import os  # Import os to read environment variables
from asyncua import Client, ua

# --- CONFIGURATION ---

# URL for the HOST OPC UA Server
OPC_UA_URL = "opc.tcp://host.docker.internal:4840/linuxcnc/"

# --- Dynamic Node Configuration ---
# Read the MACHINE_ID from the environment, defaulting to 'Lathe_1' if not set.
# This ID is set by the 'run_linuxcnc_instances.sh' script.
MACHINE_ID = os.environ.get("MACHINE_ID", "Lathe_2")
NAMESPACE_INDEX = 2  # This is 'idx' from the server, typically 2

# NodeIDs are now generated dynamically based on the MACHINE_ID
NODE_ID_MACHINE_ON = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Machine_On"
NODE_ID_DOOR_CLOSED = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Door_Closed"
# ---------------------------------

# How often to read HAL and update the server (in seconds)
POLLING_RATE = 1.0

async def main():
    # --- 1. Setup HAL Component ---
    try:
        c = hal.component("hal-opcua-client")
    except hal.error as e:
        print(f"Error: Could not create HAL component: {e}", file=sys.stderr)
        print("Is LinuxCNC (rtapi) running?", file=sys.stderr)
        sys.exit(1)

    c.newpin("machine-on", hal.HAL_BIT, hal.HAL_IN)
    c.newpin("door-closed", hal.HAL_BIT, hal.HAL_IN)
    c.ready()
    print(f"HAL Component 'hal-opcua-client' for {MACHINE_ID} is ready.")

    # --- 2. Connect to OPC UA Server ---
    try:
        print(f"Connecting to OPC UA Server at {OPC_UA_URL}...")
        async with Client(url=OPC_UA_URL) as client:
            
            print(f"Finding nodes for {MACHINE_ID}:")
            print(f"  - {NODE_ID_MACHINE_ON}")
            print(f"  - {NODE_ID_DOOR_CLOSED}")

            # 2a. Get the specific nodes for this machine instance
            node_machine_on = client.get_node(NODE_ID_MACHINE_ON)
            node_door_closed = client.get_node(NODE_ID_DOOR_CLOSED)
            
            # 2b. Check if nodes exist by reading their browse name (or any attribute)
            await node_machine_on.read_browse_name()
            await node_door_closed.read_browse_name()
            
            print("OPC UA Nodes found successfully.")

            # --- 3. Start Read/Write Loop ---
            while True:
                # 3a. Read values from HAL
                machine_on_val = c['machine-on']
                door_closed_val = c['door-closed']

                try:
                    # 3b. Write values to OPC UA Server
                    await node_machine_on.write_value(machine_on_val)
                    await node_door_closed.write_value(door_closed_val)
                    
                    # --- NEW LOGS ---
                    # This print statement is now active and formatted
                    # to show the instance, variables, and their values.
                    print(f"[{MACHINE_ID}] OPC UA Write: Machine_On -> {machine_on_val}, Door_Closed -> {door_closed_val}")
                    # ----------------

                except Exception as e:
                    # Format the error log to also include the machine ID
                    print(f"[{MACHINE_ID}] OPC UA Write Error: {e}", file=sys.stderr)

                # 3c. Wait for the next poll cycle
                await asyncio.sleep(POLLING_RATE)

    except ConnectionRefusedError:
        print(f"Error: Connection refused. Is the host server at {OPC_UA_URL} running?", file=sys.stderr)
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(f"\nShutting down HAL-OPCUA client for {MACHINE_ID}.")
