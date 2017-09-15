#!/bin/bash
#
# Gets Docker Swarm Manager IPs for given stack in Docker CE for AWS cluster created using a CloudFormation stack.

source ./aws_vars.sh

STACK_NAME="${STACK_NAME:-DockerTutorial}"

AWS_PROFILE="${AWS_PROFILE}" aws ec2 describe-instances \
  --filters "Name=tag-key,Values=aws:cloudformation:stack-name" "Name=tag-value,Values=${STACK_NAME}" \
            "Name=tag-key,Values=swarm-node-type" "Name=tag-value,Values=manager" \
            | grep PublicIpAddress | sed 's/[ \t"A-Za-z\:,]*//g'
