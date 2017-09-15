#!/bin/bash
#
# Creates a new Docker CE for AWS cluster using a CloudFormation stack.

set -e

source ./aws_vars.sh

echo "Creating the CloudFormation Stack..."
AWS_PROFILE="${AWS_PROFILE}" aws cloudformation create-stack \
  --stack-name DockerTutorial \
  --template-url "${CF_TEMPLATE_URL}" \
  --region "${AWS_REGION}" \
  ${CF_ROLE_PARAM} \
  --parameters \
    ParameterKey=ManagerSize,ParameterValue=1 \
    ParameterKey=ManagerInstanceType,ParameterValue=t2.small \
    ParameterKey=ManagerDiskSize,ParameterValue=20 \
    ParameterKey=ManagerDiskType,ParameterValue=standard \
    ParameterKey=ClusterSize,ParameterValue=3 \
    ParameterKey=InstanceType,ParameterValue=t2.small \
    ParameterKey=WorkerDiskSize,ParameterValue=20 \
    ParameterKey=WorkerDiskType,ParameterValue=standard \
    ParameterKey=EnableCloudStorEfs,ParameterValue=yes \
    ParameterKey=EnableCloudWatchLogs,ParameterValue=yes \
    ParameterKey=EnableSystemPrune,ParameterValue=yes \
    ParameterKey=KeyName,ParameterValue=DockerTutorial \
  --capabilities CAPABILITY_IAM \
  --on-failure ROLLBACK \
  --tags Key=DockerType,Value=DockerCEForAWS
