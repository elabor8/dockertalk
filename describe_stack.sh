#!/bin/bash
#
# Describes an existing Docker CE for AWS cluster created using a CloudFormation stack.

source ./aws_vars.sh

AWS_PROFILE="${AWS_PROFILE}" aws cloudformation describe-stacks \
  --stack-name DockerTutorial \
  --region "${AWS_REGION}"
