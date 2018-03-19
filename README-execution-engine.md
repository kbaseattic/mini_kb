# execution-engine.yml

The [execution-engine.yml] file is a docker-compose file that brings up only enough of mini-kbase to perform
testing of the njs_wrapper/condor integration. The stack can be brought using the standard docker-compose
syntax, but specifying a execution-engine.yml file as the configuration ( "docker-compose -f execution-engine.yml up" ).
The services started are:
* nginx proxy
* condor
* njs_wrapper
* ujs
* awe
* workspace
* handle_service
* handle_manager
* shock
* auth
* ci-mongo
* ci-mysql

See the commit logs of the [njs_wrapper](https://github.com/kbase/njs_wrapper) and [kbase/condor](https://github.com/kbase/condor) repos for the most recent changes to those repos. As of 3/19/2018 
the default configuration of njs_wrapper and condor images uses anonymous authentication to allow
the use of condor commandline utilities such as condor_submit, condor_q, condor_rm against the
condor service specified in the execution-engine.yml file. A pool password is specified in the the
configuration file using the pool_password secret, and it is configured into the condor configurations
in the njs_wrapper and condor images, however there hasn't been enough testing to turn it on by default.
The password authentication should be enabled shortly.

When testing the condor command line clients, it is recommended to bring up the njs_wrapper container
normally, and then use the docker-compose exec command to start a shell in the njs wrapper container
to test configurations and various commands:
```sh-session
120:mini_kb sychan$ docker-compose -f execution-engine.yml up -d
Starting minikb_ci-mysql_1 ... 
Starting minikb_shell_1 ... 
Starting minikb_ci-mongo_1 ... 
Starting minikb_ci-mongo_1 ... done
Starting minikb_db-init_1 ... done
Starting minikb_auth_1 ... 
Starting minikb_auth_1 ... done
Starting minikb_shock_1 ... 
Starting minikb_shock_1 ... done
Starting minikb_handle_service_1 ... done
Starting minikb_ws_1 ... done
Starting minikb_ujs_1 ... done
Starting minikb_njs_1 ... done
Starting minikb_nginx_1 ... done
120:mini_kb sychan$ docker-compose -f execution-engine.yml ps
         Name                        Command               State            Ports          
-------------------------------------------------------------------------------------------
minikb_auth_1             /kb/deployment/bin/dockeri ...   Up      8080/tcp                
minikb_awe_1              /kb/deployment/bin/dockeri ...   Up                              
minikb_ci-mongo_1         /entrypoint.sh --smallfiles      Up      0.0.0.0:27017->27017/tcp
minikb_ci-mysql_1         docker-entrypoint.sh mysqld      Up      3306/tcp                
minikb_condor_1           /usr/bin/dockerize -templa ...   Up      0.0.0.0:9618->9618/tcp  
minikb_db-init_1          /kb/deployment/bin/dockeri ...   Up                              
minikb_handle_manager_1   /kb/deployment/bin/dockeri ...   Up                              
minikb_handle_service_1   /kb/deployment/bin/dockeri ...   Up      7109/tcp                
minikb_nginx_1            /kb/deployment/bin/dockeri ...   Up      0.0.0.0:8000->80/tcp    
minikb_njs_1              /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
minikb_shell_1            /bin/bash                        Up                              
minikb_shock_1            /kb/deployment/bin/dockeri ...   Up                              
minikb_ujs_1              /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
minikb_ws_1               /kb/deployment/bin/dockeri ...   Up      7058/tcp, 8080/tcp      
120:mini_kb sychan$ docker-compose -f execution-engine.yml exec njs /bin/bash
root@9bd56688bba7:/kb/deployment/jettybase# condor_q


-- Schedd: kbase@condor : <172.18.0.5:9618?...
 ID      OWNER            SUBMITTED     RUN_TIME ST PRI SIZE CMD               

0 jobs; 0 completed, 0 removed, 0 idle, 0 running, 0 held, 0 suspended
root@9bd56688bba7:/kb/deployment/jettybase# condor_status -schedd
Name                 Machine    TotalRunningJobs TotalIdleJobs TotalHeldJobs 

kbase@condor         condor                    0             0              0
                      TotalRunningJobs      TotalIdleJobs      TotalHeldJobs

                    
               Total                 0                  0                  0
root@9bd56688bba7:/kb/deployment/jettybase# ls /etc/condor/
condor_config  condor_config.local  condor_ssh_to_job_sshd_config_template  config.d  ganglia.d  interactive.sub  linux_kernel_tuning
```

Because there aren't persistent condor services in the njs_wrapper container, it is possible to
modify the configuration of the condor clients using the files in /etc/condor/ and then re-rerunning commands.
If changes need to be tested that effect the startup or persistent configuration of the njs_wrapper image,
then the changes should be tested interactively/iteratively using the above method. The
njs_wrapper repo should be checked out locally, update njs_wrapper repo locally and a new
image built (using the make docker_image). The make docker_image target builds a new kbase/njs_wrapper
image tagged with the current github commit hash. The recommendation is to temporarily update the execution-engine.yml
file so that the locally tagged image is used, and avoid making a commit that would update the image tag
until the changes are finalized. For example, the normal configuration for njs_wrapper is:
```YAML
  njs:
    image: kbase/kb_njs_wrapper:condor-cli
    command:
      - "-env"
    # [deleting lots of config directives]
    secrets:
      - pool_password
    environment:
      - SEC_PASSWORD_FILE=/run/secrets/pool_password
```

If work is being done on the njs_wrapper repo, the make docker_image command will report the tag being
used:
```sh-session
120:njs_wrapper sychan$ make docker_image
ant war
Buildfile: /Users/sychan/src/njs_wrapper/build.xml

init:
    [mkdir] Created dir: /Users/sychan/src/njs_wrapper/classes

# a bunch of build output happens here

Removing intermediate container 2476c693523c
 ---> e718aea2d097
Step 12/12 : WORKDIR /kb/deployment/jettybase
Removing intermediate container 2c99512c2461
 ---> 79ad4c9a01e2
Successfully built 79ad4c9a01e2
Successfully tagged kbase/kb_njs_wrapper:0499d47
120:njs_wrapper sychan$ 
```

The new image is tagged kbase/kb_njs_wrapper:0499d47 and continue to be tagged this value until a
git commit is made. The relevant part of the execution-engine.yml file can then be modified to:
```YAML
  njs:
    image: kbase/kb_njs_wrapper:0499d47
    command:
      - "-env"
# ...
```

The condor container has a persistent service that only picks up changes on startup, and
the container lifetime is determined by the initial process lifetime. If changes are made to the condor
configuration and an attempt is made to restart the service, the container will exit immediately. Changes to
the running image are also not persistent across container restarts - so any changes will be lost. To
work around this, change the final command passed to the dockerize entrypoint to a long
"sleep" command that will cause the container to linger around inactively, without starting the actual

For example, the condor service uses the default entrypoint and commands from the [kbase/condor repo](https://github.com/kbase/condor/blob/master/Dockerfile#L23), so it looks very simple:
```YAML
  condor:
    image: kbase/condor:latest
    hostname: condor
    secrets:
      - pool_password
    environment:
      - SEC_PASSWORD_FILE=/run/secrets/pool_password
    ports:
      - "9618:9618"
```

The actual startup for the image is specified as:
```YAML
ENTRYPOINT [ "/usr/bin/dockerize" ]
CMD [ "-template", "/etc/condor/.templates/condor_config.local.templ:/etc/condor/condor_config.local", \
      "/usr/sbin/start-condor.sh" ]
```

To convert it to a long sleep command instead of the start-condor script, modify the execution-engine.yml file
entry to something like this:
```YAML
  condor:
    image: kbase/condor:latest
    hostname: condor
    secrets:
      - pool_password
    environment:
      - SEC_PASSWORD_FILE=/run/secrets/pool_password
    ports:
      - "9618:9618"
    entrypoint:
      - "/usr/bin/dockerize"
    command:
      - "-template"
      - "/etc/condor/.templates/condor_config.local.templ:/etc/condor/condor_config.local"
      - "sleep"
      - "3600"
```

This will update the /etc/condor/condir_config.local file using the standard config and have the
container run a 1 hour sleep command, allowing the developer to enter the running container, start
the service, test it, stop it, make changes, restart it to iterate on the configuration. The sleep 3600
command can be replaced with a longer or shorter period of time.

Then the command "docker-compose -f execution-engine.yml exec /bin/bash" can be used to bring up a shell
to interactively change the files in /etc/condor/* and then start the service manually using the
/usr/sbin/start-condor.sh script. The service can be tested, and then stopped by using control-C in the
shell window, and edits can be made, restarted, etc...

Once the appropriate changes have been semi-finalized, they can be made to the kbase/condor repo, and then
tested using the command "IMAGE_NAME=kbase/condor:latest hooks/build" which will build a new image
locally so that it can be tested. Once the changes are ready to be ready to be pushed, they can be
pushed to github and a new image will be built.

Note that because changes to the service configurations in repos will effect the release process, they
will need to be handled as pull requests that are reviewed by devops members to make sure that they are
appropriate templatized and not stored in the repo as static configs, this is especially true for anything
related to authentication or ephemeral configs like IP addresses or hostnames.

For the purposes of testing with mini-kbase, the pool password has been set to "weakpassword" using the
[condor_store_cred](http://research.cs.wisc.edu/htcondor/manual/current/condor_store_cred.html) command
and the output file is committed as the file secrets/pool_password within this repo. Note that password is
only used for local testing and will not be used for any deployments into live KBase environments.
