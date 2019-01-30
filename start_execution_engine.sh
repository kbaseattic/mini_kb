#!/usr/bin/env bash

# You will need to add the /mnt/condor directory to the list of bind mounts in docker. 
# Add /mnt/condor in the "File Sharing tab"
mkdir -p /mnt/condor && chmod 777 /mnt/condor

echo "
# Add the following to your /etc/hosts file
# 127.0.0.1 nginx
# 127.0.0.1 ci-mongo
"

#Get the latest fresh copies and restart
docker-compose -f execution-engine.yml down
docker-compose -f execution-engine.yml pull
docker-compose -f execution-engine.yml up -d
# docker-compose -f execution-engine.yml exec -u 0 njs bash

echo "
#You may need to run these manually on MacOSX by with docker exec
#docker-compose -f execution-engine.yml exec -u 0 condor_worker_mini sh -c "chmod 777 /run/docker.sock"
#docker-compose -f execution-engine.yml exec -u 0 condor_worker_max sh -c "chmod 777 /run/docker.sock"
"
