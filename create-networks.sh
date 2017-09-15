#!/bin/bash

docker network create -d overlay logging
docker network create -d overlay traefik
