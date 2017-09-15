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

ssh -o StrictHostKeyChecking=no -A -NL localhost:2374:/var/run/docker.sock "docker@${DOCKER_MANAGER_PUBLIC_IP}" &

echo "Type: export DOCKER_HOST=localhost:2374"
