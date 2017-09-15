#!/bin/bash

set -e

stack_file="${1:?"Missing stack file"}"
env_file="${2}"

[[ -f "${env_file}" ]] || (echo "Missing env file" && exit 1)

stack_name="$(basename -s .yml ${stack_file} | cut -f 3,3 -d '-')"

echo "Stack Name: ${stack_name}"

env $(cat "${env_file}" | grep ^[A-Z] | xargs) docker stack deploy "${stack_name}" --compose-file "${stack_file}"
