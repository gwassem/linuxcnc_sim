import asyncio
import hal
import sys
import os  # Import os to read environment variables
from asyncua import Client, ua

# --- CONFIGURATION ---

# URL for the HOST OPC UA Server
OPC_UA_URL = "opc.tcp://host.docker.internal:4840/linuxcnc/"

# --- Dynamic Node Configuration ---
MACHINE_ID = os.environ.get("MACHINE_ID", "Lathe_2")
NAMESPACE_INDEX = 2  # This is 'idx' from the server, typically 2

# NodeIDs are now generated dynamically based on the MACHINE_ID
NODE_ID_MACHINE_ON = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Machine_On"
# FIXED: Changed from 'Emergency_Status' to 'Emergency_Stop' to match the server
NODE_ID_EMERGENCY_STATUS = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Emergency_Stop"
# ---------------------------------

# How often to read HAL and update the server (in seconds)
POLLING_RATE = 1.0

async def main():
    # --- 1. Setup HAL Component ---
    try:
        # FIXED: Changed component name to 'opcua' to match the .hal file
        c = hal.component("opcua")
    except hal.error as e:
        print(f"Error: Could not create HAL component: {e}", file=sys.stderr)
        print("Is LinuxCNC (rtapi) running?", file=sys.stderr)
        sys.exit(1)

    # FIXED: Changed pin names to match the .hal file
    c.newpin("machine-status", hal.HAL_BIT, hal.HAL_IN)
    c.newpin("emergency-stop", hal.HAL_BIT, hal.HAL_IN)
    c.ready()
    # FIXED: Updated log message
    print(f"HAL Component 'opcua' for {MACHINE_ID} is ready.")

    # --- 2. Connect to OPC UA Server ---
    try:
        print(f"Connecting to OPC UA Server at {OPC_UA_URL}...")
        async with Client(url=OPC_UA_URL) as client:
            
            print(f"Finding nodes for {MACHINE_ID}:")
            print(f"  - {NODE_ID_MACHINE_ON}")
            print(f"  - {NODE_ID_EMERGENCY_STATUS}")

            # 2a. Get the specific nodes for this machine instance
            node_machine_on = client.get_node(NODE_ID_MACHINE_ON)
            node_emergency_status = client.get_node(NODE_ID_EMERGENCY_STATUS)
            
            # 2b. Check if nodes exist
            await node_machine_on.read_browse_name()
            await node_emergency_status.read_browse_name()
            
            print("OPC UA Nodes found successfully.")

            # --- 3. Start Read/Write Loop ---
            while True:
                # 3a. Read values from HAL (using new pin names)
                machine_on_val = c['machine-status']
                emergency_stop_val = c['emergency-stop']

                try:
                    # 3b. Write values to OPC UA Server
                    await node_machine_on.write_value(machine_on_val)
                    await node_emergency_status.write_value(emergency_stop_val)
                    
                    print(f"[{MACHINE_ID}] OPC UA Write: Machine_On -> {machine_on_val}, Emergency_Stop -> {emergency_stop_val}")

                except Exception as e:
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
