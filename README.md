Demo - Using Docker in production: Get started today!
=====================================================

*Version: Docker CE v17.06*

*A talk by Clarence Bakirtzidis - Email: [clarence.bakirtzidis@elabor8.com.au](mailto:clarence.bakirtzidis@elabor8.com.au), Twitter: [@clarenceb_oz](https://twitter.com/clarenceb_oz)*

We will be using [Docker for AWS](https://docs.docker.com/docker-for-aws/) Community Edition (CE).

There are two ways to deploy Docker for AWS:

* With a pre-existing VPC
* With a new VPC created by Docker

You can use either the AWS Management Console (browser based) or use the AWS CLI (command-line based).

**In this tutorial we will use a new VPC created by Docker and the AWS CLI.**

## Prerequisites

* Access to an AWS account with permissions to use CloudFormation and to create the following objects (see [full set of required permissions](https://docs.docker.com/docker-for-aws/iam-permissions/)):
    * EC2 instances + Auto Scaling groups
    * IAM profiles
    * DynamoDB Tables
    * SQS Queue
    * VPC + subnets and security groups
    * ELB
    * CloudWatch Log Group
* SSH key in the AWS region where you want to deploy (required to access the completed Docker install)
* AWS account that supports EC2-VPC (See the [FAQ for details about EC2-Classic](https://docs.docker.com/docker-for-aws/faqs/))

*It is recommended that you do not use your AWS root account and instead create a new IAM user.  You can either grant them [all these permissions](https://docs.docker.com/docker-for-aws/iam-permissions/) or make them an admin.  We will use a service role with CloudFormation that only has minimum required permissions.*

## Install the AWS CLI and configure your AWS access keys

TODO

## Provision a Docker for AWS cluster

**Note**: You must have created an EC2 ssh key pair in the desired region before creating the cluster. the keypair name must be called `DockerTutorial`.

Make a copy of the `aws_vars.sh.template` file and called it `aws_vars.sh`
Set the required values environment variables:

* `AWS_PROFILE` or leave blank for default profile
* `AWS_REGION`
* `CF_ROLE_ARN` or leave blank to use your IAM user permissions

```sh
./create_stack.sh

# ==>
Creating the CloudFormation Stack...
{
    "StackId": "arn:aws:cloudformation:ap-southeast-2:XXXXXXXXXX:stack/DockerTutorial/7adc6f40-99d5-11e7-a360-50fa575f6862"
}
```

After some time, check the status:

```sh
./describe_stack.sh

# ==>
{
    "Stacks": [
        {
            "StackId": "arn:aws:cloudformation:ap-southeast-2:899051371423:stack/DockerTutorial/7adc6f40-99d5-11e7-a360-50fa575f6862",
            "Description": "Docker CE for AWS 17.06.1-ce (17.06.1-ce-aws1)",
            ...snip...
            "StackStatus": "CREATE_IN_PROGRESS",
            ...snip...

        }
    ]
}
```

When the stack is ready, the `StackStatus` will be `CREATE_COMPLETE`.
If the stack creation fails, the `StackStatus` will be `ROLLBACK_COMPLETE`.

## Setup the local environment to talk to a Swarm Manager

Find a Docker Swarm Manager instance public IP:

```sh
./get_manager_ips.sh

# ==>
54.79.9.120
```

First, add your SSH keypair PEM file to your SSH agent or keychain:

```sh
# Use the path to your SSH keypair PEM file location:
ssh-add ~/.ssh/DockerTutorial.pem
```

You can SSH directly to the Docker manager like so:

```sh
ssh -A docker@54.79.9.120
docker ps
exit
```

But since we want to use scripts and config files locally, we will open an SSH tunnel instead.

Open an ssh tunnel to the manager so you can use `docker` commands directly with the Docker for AWS swarm.

```sh
./ssh_tunnel.sh 54.79.9.120

# ==>
Type: export DOCKER_HOST=localhost:2374
```

Set the `DOCKER_HOST` environment variable and test connection to the Docker swarm manager:

```sh
export DOCKER_HOST=localhost:2374
docker info

# ==>
...snip...
Server Version: 17.06.1-ce
...snip...
Labels:
 os=linux
 region=ap-southeast-2
 availability_zone=ap-southeast-2b
 instance_type=t2.small
 node_type=manager
...snip...
```

The Labels can be used with placement constraints or [preferences](https://docs.docker.com/engine/swarm/services/#specify-service-placement-preferences-placement-pref) (e.g. to evenly distribute services across AZs, not just nodes), e.g.

```sh
docker service create \
  --replicas 9 \
  --name redis_2 \
  --placement-pref 'spread=node.labels.availability_zone' \
  redis:3.0.6
```

## Verify your swarm nodes are up and running

```sh
docker node ls

# ==>
ID                            HOSTNAME                                           STATUS              AVAILABILITY        MANAGER STATUS
6r7o5rv4x3pv3757ik2y5jm6j *   ip-172-31-21-75.ap-southeast-2.compute.internal    Ready               Active              Leader
a3o4uvlpdtrbcpxwu9hou4fsf     ip-172-31-10-93.ap-southeast-2.compute.internal    Ready               Active
i75ybtjkpdfq2dm8v0lojj7mo     ip-172-31-38-221.ap-southeast-2.compute.internal   Ready               Active
q3dmtefzvtd075rsfdgl8dxxp     ip-172-31-25-160.ap-southeast-2.compute.internal   Ready               Active
```

## (Optional) Running the app locally

If you have Docker setup on your local machine (e.g. for Mac or Docker for Windows) then you can test out the app locally using `docker-compose`:

```sh
unset DOCKER_HOST
cd voting-app
docker-compose -f ./docker-stack.yml up -d
# This may take a couple of minutes...
docker-compose ps

# ==>
       Name                     Command               State            Ports
-------------------------------------------------------------------------------------
votingapp_db_1       docker-entrypoint.sh postgres    Up      5432/tcp
votingapp_redis_1    docker-entrypoint.sh redis ...   Up      0.0.0.0:32768->6379/tcp
votingapp_result_1   node server.js                   Up      0.0.0.0:5001->80/tcp
votingapp_vote_1     gunicorn app:app -b 0.0.0. ...   Up      0.0.0.0:5000->80/tcp
votingapp_worker_1   /bin/sh -c dotnet src/Work ...   Up
```

Browse to `http://localhost:5000` for the Vote interface.
Browse to `http://localhost:5001` for the Result interface.

Stop and remove the local application:

```sh
docker-compose down
```

Reset the local env to point back to the Docker for AWS manager:

```sh
cd ..
export DOCKER_HOST=localhost:2374
docker node ls
```

## Deploy voting app to Docker for AWS

Use `docker stack deploy` with the Docker Compose V3 format YAML file to deploy the app onto the swarm:

```sh
docker stack deploy votingapp --compose-file voting-app/docker-stack.yml

# ==>
Creating network votingapp_backend
Creating network votingapp_frontend
Creating network votingapp_default
Creating service votingapp_db
Creating service votingapp_vote
Creating service votingapp_result
Creating service votingapp_worker
Creating service votingapp_visualizer
Creating service votingapp_redis
```

```sh
docker stack ls

# ==>
NAME                SERVICES
votingapp           6
```

```sh
docker service ls

# ==>
ID                  NAME                   MODE                REPLICAS            IMAGE                                          PORTS
f0t0bqff6opc        votingapp_redis        replicated          1/1                 redis:alpine                                   *:0->6379/tcp
ge4vah4nc0mp        votingapp_db           replicated          1/1                 postgres:9.4
ndm6ytoqvaz4        votingapp_visualizer   replicated          1/1                 dockersamples/visualizer:stable                *:8080->8080/tcp
uwk4s3y27pud        votingapp_worker       replicated          1/1                 dockersamples/examplevotingapp_worker:latest
vbhjil2sk8z1        votingapp_result       replicated          1/1                 dockersamples/examplevotingapp_result:before   *:5001->80/tcp
w5rt9x4bt6sw        votingapp_vote         replicated          2/2                 dockersamples/examplevotingapp_vote:before     *:5000->80/tcp
```

## Deploy the Swarm Visualiser

## Deploy Portainer

## Deploy Logging

## Deploy Monitoring

## Get everyone to vote via the custom domain

## No volumes: Drain node, state is lost

## With Volumes (Cloudstor) - drain node, move to another node (state is retained)

## Scaling up / down

## Rolling updates (V1 -> V2) – Zero downtime

## Teardown
