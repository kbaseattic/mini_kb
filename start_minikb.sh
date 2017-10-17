#!/bin/bash -x
#
# Simplistic demo script to startup the stack using docker-compose. Will need more
# work for "real" use
#
# Assumes that the necessary images have been pulled and tagged appropriately and
# that there aren't lingering containers from previous runs
#
# sychan@lbl.gov
# 10/17/2017
#

docker-compose up -d ci-mysql
docker-compose up -d ci-mongo
sleep 15 # Give some time for mongo + mysql to come up. This will be unnecessary once we get a
         # wrapper script that checks for the dependent services to be up before starting
docker-compose up mongoinit
docker-compose up mysqlinit
docker-compose up -d auth2
docker-compose up -d shock
sleep 5 # Sometimes shock is a little slow to come up
docker-compose up -d handle_service
docker-compose up -d handle_manager
sleep 5 # Give a little time for the perl apps to come up
docker-compose up -d workspace