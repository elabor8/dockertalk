#!/bin/bash
#
# Opens an ssh tunnel in background to a Docker Manager in the Docker for AWS cluster.
#
# Use 'fg' to bring it to the forground and CTRL+C to exit.
# Type: 'jobs' to see any background jobs.
# Note: the tunnel may timeout if left idle for extended periods.
#       In this case, kill the existing session and create a new tunnel.
#
# You will need the SSH private KEY (PEM) that you created in the AWS EC2 region of your choice.
# Add the key to your ssh agent:
# On Mac, 'ssh-add <your_pem_file>'

set -e

DOCKER_MANAGER_PUBLIC_IP="${1:?"Missing Docker Manager Public IP"}"
DOCKER_HOST=localhost:2374

pkill -f "ssh.*localhost:2374" || echo "No existing ssh tunnel found."
nohup ssh -o StrictHostKeyChecking=no -A -NL "${DOCKER_HOST}":/var/run/docker.sock "docker@${DOCKER_MANAGER_PUBLIC_IP}" > /tmp/docker-ssh.log 2>&1 &

echo "Type: export DOCKER_HOST=${DOCKER_HOST}"
