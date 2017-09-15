#!/bin/bash
#
# Deletes an existing Docker CE for AWS cluster created using a CloudFormation stack.

source ./aws_vars.sh

echo "Deleting the CloudFormation Stack..."
AWS_PROFILE="${AWS_PROFILE}" aws cloudformation delete-stack \
  --stack-name DockerTutorial \
  --region "${AWS_REGION}" \
  ${CF_ROLE_PARAM}

echo "Done."
