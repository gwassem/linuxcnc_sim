import asyncio
import logging
import sys 
from asyncua import Server, ua

OPC_UA_ENDPOINT = "opc.tcp://0.0.0.0:4840/linuxcnc/"
OPC_UA_NAMESPACE = "urn:linuxcnc:opcua:machine-status"
BASE_MACHINE_NAME = "Lathe"

async def main():
    _logger = logging.getLogger(__name__)

    # --- Read Number of Instances from command line ---
    try:
        # Check if an argument is provided, otherwise default to 1
        num_instances = int(sys.argv[1]) if len(sys.argv) > 1 else 1
        _logger.info(f"Configuring server for {num_instances} machine instance(s).")
    except ValueError:
        _logger.error("Invalid argument. Please provide a number (e.g., 'python3 host_opcua_server.py 3')")
        return
    # ---------------------------------------------------

    # 1. Initialize the server
    server = Server()
    
    await server.init()
    server.set_endpoint(OPC_UA_ENDPOINT)
    server.set_server_name("LinuxCNC Host Server")
    
    # 2. Set the security policy
    server.set_security_policy([ua.SecurityPolicyType.NoSecurity])

    # 3. Set up our own namespace
    idx = await server.register_namespace(OPC_UA_NAMESPACE)
    _logger.info(f"Namespace {OPC_UA_NAMESPACE} registered as ns={idx}")

    # --- Loop to create nodes for each instance ---
    all_vars = []
    for i in range(1, num_instances + 1):
        machine_id = f"{BASE_MACHINE_NAME}_{i}"
        _logger.info(f"Creating nodes for: {machine_id}")

        # 4. Populating our address space
        machine_obj = await server.nodes.objects.add_object(idx, machine_id)

        # 5. Add variables using the explicit string NodeId
        node_id_machine_on = f"ns={idx};s={machine_id}.Machine_On"
        node_id_door_closed = f"ns={idx};s={machine_id}.Door_Closed"
        
        var_machine_on = await machine_obj.add_variable(
            node_id_machine_on, 
            "Machine_On", 
            False, 
            varianttype=ua.VariantType.Boolean
        )
        var_door_closed = await machine_obj.add_variable(
            node_id_door_closed, 
            "Door_Closed", 
            True, 
            varianttype=ua.VariantType.Boolean
        )

        # 6. Set variables to be writable
        await var_machine_on.set_writable()
        await var_door_closed.set_writable()
        
        all_vars.append(var_machine_on)
        all_vars.append(var_door_closed)
    # -------------------------------------------------

    _logger.info(f"Server started at {OPC_UA_ENDPOINT}")
    _logger.info("Using default permissive user manager (anonymous access allowed).")
    _logger.info("Registered Nodes:")
    for var in all_vars:
        _logger.info(f"  - {var.nodeid}")

    # 7. Run the server
    async with server:
        while True:
            await asyncio.sleep(1)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
