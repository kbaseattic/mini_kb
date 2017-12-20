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

docker-compose pull
docker-compose up -d nginx
