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

# You can also see the tasks for a service:
docker service ps votingapp_vote
```

To access the voting app that is deployed to the swarm, you will need the ELB name:

```sh
./get_elb_names.sh

# ==>
"DNSName": "DockerTut-External-P2N78KBI3BAI-1241970304.ap-southeast-2.elb.amazonaws.com",
```

You can now access each service which have published ports at:

`http://DockerTut-External-P2N78KBI3BAI-1241970304.ap-southeast-2.elb.amazonaws.com:<published_port>`

Try accessing the exposed services:

* Vote : `http://<elb_dns_name>:5000`
* Result : `http://<elb_dns_name>:5001`
* Visualizer : `http://<elb_dns_name>:8080`

**Note**: These are exposed as HTTP by default since the ELB is not terminating TLS.  It is acting as a Layer 4 LB and reverse proxy.  This feature is setup automatically as part of Docker for AWS.

Later we will expose services using TLS termination on the ELB.

## Check the Swarm Visualiser

Browse to the Swarm Visualizer : `http://<elb_dns_name>:8080`

Undeploy the stack so we can use a custom reverse proxy as the entrypoint to the swarm:

```sh
docker stack rm votingapp
```

## Deploy Traefik reverse proxy

The Docker for AWS setup currently only creates an ELB (Layer 4) not an ALB (Layer 7).  This means we have to use a custom Layer 7 reverse proxy to route to our services in the swarm over a single port (443 or 80).

We will use a Traefik service with a published port on port 443 to handle internal routing on the swarm ingress load balancer (routing mesh).

### With a custom domain name, ACM certificate and Route 53 DNS setup

We will use a custom domain name and ACM wildcard certificate to get TLS termination working on the ELB and then use Traefik to route to services internally in the swarm via a host header.

Prerequisite: A custom domain name (e.g. `mydomain.com`)

In Route 53, create a Hosted Zone for your domain.

In your DNS registrar, point it to at least two of the DNS servers assigned by AWS (in your NS record).

Create a host wildcard record in your hosted zone (A record of type alias):

Name: `*.mydomain.com`
Type: `A - IPv4 address`
Alias: `Yes`
Alias Target: `<Select your ELB DNS NAme from the list>`
ß
Leave the remaining fields as is.
Create the record.

Go to Amazon Certificate Manager and create a free wildcard certificate for your domain: `*.mydomain.com`

Approve the certificate request in your email.

Record the ARN for the ACM certificate, e.g: `arn:aws:acm:ap-southeast-2:XXXXXXXXXXXX:certificate/e807ff24-1988-428e-a326-8e`d928d535b6

This will be needed for Traefik later.

Copy the file `prod.env.template` to `prod.env` and update the environment variables with your domain name and ACM certificate ARN:

```sh
DOMAIN_NAME=<your_domain>
ACM_CERT_ARN=<your_acm_cert_arn>
```

Create the overlay network for Traefik and other services to communicate within the swarm:

```sh
docker network create -d overlay traefik
```

Deploy the Traefik stack to the swarm:

```sh
./deploy_stack.sh voting-app/docker-stack-traefik.yml prod.env
```

Browse to the Traefik dashboard: http://traefik.dockertutorial.technology:8000/
(No services displayed yet.)

Deploy the Voting App stack to the swarm:

```sh
./deploy_stack.sh voting-app/docker-stack-votingapp.yml prod.env
```

Let's check our stacks:

```sh
docker stack ls

# ==>
NAME                SERVICES
traefik             1
votingapp           5
```

Thanks to Traefik, we can now browse to the vote and result apps:

Browse to: https://vote.dockertutorial.technology
Browse to: https://result.dockertutorial.technology

TLS is [setup automatically for us in the ELB](https://docs.docker.com/docker-for-aws/load-balancer/) by the `com.docker.aws.lb.arn` label:

```yaml
traefik:
  deploy:
    ...snip...
    labels:
      ...snip...
      - "com.docker.aws.lb.arn=${ACM_CERT_ARN}"
```

### Get everyone to vote via the custom domain

Which the most popular pet?  Cats or Dogs?

### Alternative: no custom domain - using path routing

There will be no TLS termination on the ELB using this method (Traefik does supports TLS itself but that is beyond the scope of this tutorial).

TODO

## Deploy the Swarm Visualizer

```sh
./deploy_stack.sh voting-app/docker-stack-visualizer.yml prod.env
```

Browse to: https://vizualizer.dockertutorial.technology

## Deploy Portainer

```sh
./deploy_stack.sh voting-app/docker-stack-portainer.yml prod.env
```

Browse to: https://portainer.dockertutorial.technology

**Note**: Normally, you would use a [persistent volume for Portainer](https://portainer.readthedocs.io/en/stable/deployment.html#persist-portainer-data) to retain state.  In this demo we will not use a volume.

Scale up the vote service to 2 containers then try voting and see that different containers process the vote.

In Portainer, check the logs (e.g. traefik) and console (e.g. db) for a running container.

Check the Traefik dashboard now: http://traefik.dockertutorial.technology:8000

Check the health page as well: http://traefik.dockertutorial.technology:8000/dashboard/#/health

**Note:** Exposing Portainer is a security risk - do not expose it publicly!

## Deploy Logging

Containers can use one of [several drivers](https://docs.docker.com/engine/admin/logging/overview/) to ship logs.

`docker logs` / `docker-compose logs` / `docker service logs` only work with the default `json-file` logging driver.

The containers in the Docker for AWS cluster are already configured to send all their logs to AWS CloudWatch Logs.  This is not the easily interface to use in the AWS Console.  You can ship elsewhere from here.  For the demo, we'll use EFK stack to ship to a private Elasticsearch server.

**Note**: In production, you’ll need to consider HA, scaling, data backup and retention, security, disaster recovery, etc.

**Note:** Fluentd is exposed publicly due to limitations of the Docker for AWS setup.  You can create additional security groups or setup NACLs to block access.  In Docker EE you can configure UCP logging to ship logs to Elasticsearch.

Create the logging network:

```sh
docker network create -d overlay logging
```

Deploy the logging stack:

```sh
./deploy_stack.sh voting-app/docker-stack-logging.yml prod.env
```

Check that the logging stack and services are up and running:

```sh
docker stack ls
docker service ls --filter name=logging
```

Check the Kibana dashboard:

Browse to: https://kibana.dockertutorial.technology

No logs?

Update the `votingapp` stack to connect to the `logging` network and add the fluentd logging options, then re-deploy.

```sh
./deploy_stack.sh voting-app/docker-stack-votingapp.yml prod.env
```

Only services that have changed will be restarted.

In Kibana, click "refresh fields" to configure the index pattern then click Create.

Go to the 'Discover' view - logs should now appear.

Select the container_name, log, and message fields.
Auto-refresh every 10 secs.

Try voting a few times then check the logs (try query: Processing vote for '?')

### (Optional) Create a visualisation - tally of all votes

Click 'Vizualise'
Click 'Create Visualization'
Select 'Metric' as the visualization type
Select the `logstash-*` index
Select `count` for Metric
Select 'Filters' under Split group / Aggregation
Filter 1: "Processing vote for 'a'"
Label 1: Cats
Click Add Filter
Filter 2: "Processing vote for 'b'"
Label 2: Dogs
Click Save
Enter "Vote Tally"

Note: Make sure no filter is added to the query at the top.

Click 'Dashboard'
Click 'Create a dashboard'
Click 'Add'
Select 'Vote Tally'
Click Save
Maximise the dashboard

Try voting some more and check the dashboard.

Any data that is logged can be searched and made into a dashboard for key performance or business metrics.

## Scaling up / down

Scale up the `worker` service and check Kibana logs:

docker service scale votingapp_worker=3

Try query: worker

Check Portainer and Vizualiser.

## Deploy Monitoring

For this demo we'll deploy a monitoring stack consisting off: cAdvisor (host/container meterics) + Prometheus (server + alarm manager) + Grafana (dashboard)

Alternatives:

* Sysdig, Datadog, CloudWatch, APM tools (Dynatrace, AppDynamics, etc.)

UCP provides some monitoring too: https://docs.docker.com/datacenter/ucp/1.1/monitor/monitor-ucp/

We'll use this setup as it works: https://github.com/bvis/docker-prometheus-swarm and its dashboard: https://grafana.com/dashboards/609

### Create config for Prometheus

```sh
docker config create prometheus.yml docker-prometheus-swarm/rootfs/etc/prometheus_custom/prometheus.yml
docker config create alert.rules_services docker-prometheus-swarm/rootfs/etc/prometheus_custom/alert.rules_services

# Check config exists
docker config ls
```

### Monitoring stack

./deploy_stack.sh voting-app/docker-stack-monitoring.yml prod.env

Check the monitoring services:

Browse to: https://alertmanager.dockertutorial.technology
Browse to: https://prometheus.dockertutorial.technology
Browse to: https://alertmanager.dockertutorial.technology
Browse to: https://grafana.dockertutorial.technology

Import the JSON dashboard: `docker-prometheus-swarm/dashboards/docker-swarm-container-overview_rev23_no_logging.json`

Inspect some of the metrics available.

## No volumes: Drain node, state is lost

## With Volumes (Cloudstor) - drain node, move to another node (state is retained)

## Rolling updates (V1 -> V2) – Zero downtime

## Teardown

## Credits

The voting app was copied from Docker Samples here: https://github.com/dockersamples/example-voting-app
