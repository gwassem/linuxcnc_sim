import asyncio
import hal
import sys
import os
from asyncua import Client, ua

# --- CONFIGURATION ---
# Server address is read from the 'OPCUA_SERVER_HOST' environment variable
# This is set to 'opcua-server' by docker-compose
OPCUA_SERVER_HOST = os.environ.get("OPCUA_SERVER_HOST", "localhost")
OPC_UA_URL = f"opc.tcp://{OPCUA_SERVER_HOST}:4840/linuxcnc/"

MACHINE_ID = os.environ.get("MACHINE_ID", "Lathe_2")
NAMESPACE_INDEX = 2
POLLING_RATE = 1.0

NODE_ID_MACHINE_ON = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Sensors.Machine_On"
NODE_ID_ESTOP_ACTIVE = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Sensors.EStop_Active"
NODE_ID_EXECUTE_ESTOP = f"ns={NAMESPACE_INDEX};s={MACHINE_ID}.Commands.Execute_EStop"

async def main():
    try:
        c = hal.component("opcua")
    except hal.error as e:
        print(f"Error: Could not create HAL component: {e}", file=sys.stderr)
        sys.exit(1)

    c.newpin("machine-status", hal.HAL_BIT, hal.HAL_IN)
    c.newpin("emergency-stop", hal.HAL_BIT, hal.HAL_IN)
    c.newpin("trigger-estop", hal.HAL_BIT, hal.HAL_OUT)
    c.ready()
    print(f"HAL Component 'opcua' for {MACHINE_ID} is ready.")

    while True: 
        try:
            print(f"[{MACHINE_ID}] Connecting to OPC UA Server at {OPC_UA_URL}...")
            async with Client(url=OPC_UA_URL) as client:
                
                print(f"[{MACHINE_ID}] Finding nodes...")
                node_machine_on = client.get_node(NODE_ID_MACHINE_ON)
                node_estop_active = client.get_node(NODE_ID_ESTOP_ACTIVE)
                node_execute_estop = client.get_node(NODE_ID_EXECUTE_ESTOP)
                print("OPC UA Nodes found successfully.")

                while True:
                    try:
                        machine_on_val = c['machine-status']
                        emergency_stop_val = c['emergency-stop']
                        
                        await node_machine_on.write_value(machine_on_val)
                        await node_estop_active.write_value(emergency_stop_val)
                        
                        print(f"[{MACHINE_ID}] HAL->OPC: Machine_On={machine_on_val}, EStop={emergency_stop_val}")
                        
                        execute_estop_val = await node_execute_estop.read_value()
                        
                        if execute_estop_val:
                            print(f"[{MACHINE_ID}] OPC UA Read: Execute_EStop detected. Triggering HAL pin.")
                            c['trigger-estop'] = True
                            await node_execute_estop.write_value(False)
                        else:
                            c['trigger-estop'] = False

                    except Exception as e:
                        print(f"[{MACHINE_ID}] OPC UA Read/Write Error: {e}", file=sys.stderr)
                        break 
                    await asyncio.sleep(POLLING_RATE)
        except (ConnectionRefusedError, asyncio.TimeoutError):
            print(f"Error: Connection refused. Is {OPCUA_SERVER_HOST} running? Retrying in 5s...", file=sys.stderr)
            await asyncio.sleep(5)
        except Exception as e:
            print(f"An unexpected error occurred: {e}. Retrying in 5s...", file=sys.stderr)
            await asyncio.sleep(5)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(f"\nShutting down HAL-OPCUA client for {MACHINE_ID}.")
