# Use a slim Python base image
FROM python:3.10-slim

WORKDIR /app

# Install asyncua library
RUN pip install --no-cache-dir asyncua

# Copy the server script into the image
COPY host_opcua_server.py .

# The default command will be overridden by docker-compose,
# but we provide a sensible default.
CMD ["python3", "host_opcua_server.py", "1"]
