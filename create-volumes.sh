#!/bin/bash

docker volume create -d "cloudstor:aws" --opt backing=shared esdata_shared
