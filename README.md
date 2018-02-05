# mini_kb
Docker-compose configuration that brings up a mini-KBase

Includes configurations for all of the services to setup a minimal test environment

TL;DNR
======

1. Install docker-compose and its dependencies
1. Clone the mini-kb repo
1. cd into the repo
1. run "start_minikb.sh"
1. The mini-kb front proxy is now listening on port 8000. KBase services can be found under http://localhost:8000/services/{servicename}

Structure of Docker Images
==========================

Docker images used for mini-kbase use a [modified version](https://github.com/kbase/dockerize) of [dockerize](https://github.com/jwilder/dockerize)

Documentation for dockerize can be found at the github links above. In addition to the original
dockerize features, the KBase fork has been extended to inject the contents of INI files into the
environment as well options to pass headers along when fetching the INI file over http and an
option to turn off certificate validation on SSL connections.

Mini-kbase images generally use dockerize as the entrypoint, and templated configuration files are
then rendered using whatever environment variables that are passed in. The dockerize tool can also
be configured to wait for upstream dependency endpoints to start accepting TCP connections before
starting the primary container program.

The layout of each docker image follows current KBase conventions with the primary configuration
file identified by the KB_DEPLOYMENT_CONFIG environment variable, and the majority of the image
specific files under /kb/deployment, with /kb/deployment/services/{servicename} generally being
the location for the executable and support files for the image's primary program.

Here is a typical snippet from a dockerfile that shows how dockerize is typically called:

~~~
ENV KB_DEPLOYMENT_CONFIG=/kb/deployment/conf/deployment.cfg

ENTRYPOINT [ "/kb/deployment/bin/dockerize" ]

# Here are some default params passed to dockerize. They would typically
# be overidden by docker-compose at startup
CMD [  "-template", "/kb/deployment/conf/.templates/deployment.cfg.templ:/kb/deployment/conf/deployment.cfg", \
       "java", "-DSTOP.PORT=8079", "-DSTOP.KEY=foo", "-Djetty.home=$JETTY_HOME", \
       "-jar", "$JETTY_HOME/start.jar" ]
~~~

The entrypoint is the dockerize binary itself, with the parameters set in the CMD section so that it can be
reconfigured conveniently at runtime. The "-template" "/kb/deployment/conf/.templates/deployment.cfg.templ:/kb/deployment/conf/deployment.cfg" arguments tells dockerize to
look in the file /kb/deployment/conf/.templates/deployment.cfg.templ for a dockerize template, render it with the
current set of environment variables and then write it out to /kb/deployment/conf/deployment.cfg, which was setup
to be the configuration file by the KB_DEPLOYMENT_CONFIG environment variable.

Multiple template files can be renders by additional "-template src:dest" directives when a program has configuration
spread across multiple locations

The next set of options to dockerize spins up the jvm and hands off executing to the the JETTY server, after
which the jetty configuration that has been laid out on the image will take over. Dockerize will than wait for
the jvm to finish executing before exiting. Please see the dockerize documentation for additional directives
that can be used to tail files to the console, wait for upstream services to come up before starting the main
program, etc...

Docker-Compose
==============

Mini-kbase consists of multiple images with dependencies among them - this is handled using [docker-compose](https://docs.docker.com/compose/).
This design mirrors what is used in the CI, AppDev, Next and Prod environments for KBase, and can also be
used in [Rancher](https://rancher.com/rancher/) based environments. Docker-compose and docker are requirements
for mini-kbase and need to be installed locally before trying to bring up mini-kbase.

The [docker-compose.yml](https://docs.docker.com/compose/compose-file/) file in this repo defines the mini-kbase
environment which the docker-compose command brings up. It brings up an nginx proxy front end which is exposed
to the external network via port 8000, shared mongo-db and mysql backends which are restricted to the private
docker network, and a collection of KBase services (including kbase-ui) which can see each other based on their
service names, but can only be accessed outside of the docker environment via the nginx proxy.

The nginx proxy is configured so that queries to http://nginx/services/servicename are proxied to the
container named "servicename" on port 8080. For example, the container called "workspace" brings up
it's listener on port 8080, and is accessible via http://workspace:8080/ within the private docker network,
but it is not directly exposed outside of the docker network. However a request that comes into the nginx
proxy requesting /services/workspace in the path component will be proxied to workspace port 8080. This is
configured as a regular expression in the nginx configuration, and names are dynamically resolved by the
docker DNS services so new containers on the docker network do not need to be added to the nginx configuration.
This means that so long as an entry is added to docker-compose.yml with a listener on port 8080, it will be
available via the nginx proxy.

This also means that if a docker container is brought up manually and its
network is manually set to minikb_default ( the name of the mini-kbase private network ) with the docker run
option *--network="minikb_default"*, it will also be accessible by the nginx proxy (as well as the other
containers within mini-kbase) by the name assigned to the container. An example of this will be shown later in
this document.

Manually Adding Container to running mini-kb stack
==================================================

It is sometimes useful to add containers to the mini-kb environment without modifying the docker-compose.yml
file. Here is an example of how to add a new container called kbase-ui2 into the environment and accessing
it via the front end proxy.

We start with a mini-kbase environment with nginx and several backend services running (but not kbase-ui)
~~~
120:mini_kb sychan$ docker-compose ps
         Name                        Command               State            Ports          
-------------------------------------------------------------------------------------------
minikb_auth_1             /kb/deployment/bin/dockeri ...   Up      8080/tcp                
minikb_awe_1              /kb/deployment/bin/dockeri ...   Up                              
minikb_ci-mongo_1         /entrypoint.sh --smallfiles      Up      0.0.0.0:27017->27017/tcp
minikb_ci-mysql_1         docker-entrypoint.sh mysqld      Up      3306/tcp                
minikb_db-init_1          /kb/deployment/bin/dockeri ...   Up                              
minikb_handle_manager_1   /kb/deployment/bin/dockeri ...   Up                              
minikb_handle_service_1   /kb/deployment/bin/dockeri ...   Up      7109/tcp                
minikb_nginx_1            /kb/deployment/bin/dockeri ...   Up      0.0.0.0:8000->80/tcp    
minikb_shock_1            /kb/deployment/bin/dockeri ...   Up                              
minikb_ujs_1              /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
minikb_workspace_1        /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
120:mini_kb sychan$ curl http://localhost:8000/kbase-ui/build-info.js
<html>
<head><title>502 Bad Gateway</title></head>
<body bgcolor="white">
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.12.2</center>
</body>
</html>
~~~

We then start a kbase-ui container manually using docker run, plug it into the minikb_default network, set
the name to kbase-ui so that this can be used as the hostname within the minikb_default network, then give
it a set of environment variables via the --env-file directive that sets the port to 8080 as well as other
appropriate settings:

~~~
120:mini_kb sychan$ docker run -d --network=minikb_default --name=kbase-ui --env-file=deployment/conf/kbase-ui-minikb.ini kbase/kbase-ui:latest
5a0512c2bffa87735d6fb1fef4280bdf217fd50a57df566b3c4899a6092bce81
120:mini_kb sychan$ docker-compose ps
         Name                        Command               State            Ports          
-------------------------------------------------------------------------------------------
minikb_auth_1             /kb/deployment/bin/dockeri ...   Up      8080/tcp                
minikb_awe_1              /kb/deployment/bin/dockeri ...   Up                              
minikb_ci-mongo_1         /entrypoint.sh --smallfiles      Up      0.0.0.0:27017->27017/tcp
minikb_ci-mysql_1         docker-entrypoint.sh mysqld      Up      3306/tcp                
minikb_db-init_1          /kb/deployment/bin/dockeri ...   Up                              
minikb_handle_manager_1   /kb/deployment/bin/dockeri ...   Up                              
minikb_handle_service_1   /kb/deployment/bin/dockeri ...   Up      7109/tcp                
minikb_nginx_1            /kb/deployment/bin/dockeri ...   Up      0.0.0.0:8000->80/tcp    
minikb_shock_1            /kb/deployment/bin/dockeri ...   Up                              
minikb_ujs_1              /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
minikb_workspace_1        /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
~~~

Notice that a container started direct with docker does not show up as part of the docker-compose
managed containers. Docker-compose has no direct knowledge of this container. However, because it
is part of the network, the name will resolve and the nginx proxy will be able to find the container
through the wildcard rule for /services/*

~~~
120:mini_kb sychan$ curl http://localhost:8000/kbase-ui/build-info.js
(function (global) {
    global.__kbase__build__ = {
        // git rev-parse HEAD
        // dev or prod
        deployType: 'ci',
        gitCommitHash: 'be51434',
        builtAt: 1517335396917,
    };
}(window));120:mini_kb sychan$ docker ps | grep kbase-ui
5a0512c2bffa        kbase/kbase-ui:latest          "/kb/deployment/bin/…"   12 seconds ago      Up 29 seconds       80/tcp                     kbase-ui
~~~

If we kill the container, it will no longer be accessible by the nginx proxy and we are back to the
original state.

~~~
120:mini_kb sychan$ docker kill kbase-ui
kbase-ui
120:mini_kb sychan$ curl http://localhost:8000/kbase-ui/build-info.js
<html>
<head><title>504 Gateway Time-out</title></head>
<body bgcolor="white">
<center><h1>504 Gateway Time-out</h1></center>
<hr><center>nginx/1.12.2</center>
</body>
</html>
120:mini_kb sychan$ 
~~~


