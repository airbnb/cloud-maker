# Motivation
CloudMaker makes deployment of instances in the cloud easy and allows them to be configured

# Cloud init execution order

1. Environment variables are placed in /etc/environment. **See Caveats**
1. SSH keys are installed.
1. Listed packages are installed.
1. Include scripts are executed.
1. Runcmds are executed.

# Useful config properties

* Store the output of all Cloud Init script execution in a log file:

        output:
          all: '| tee -a /var/log/cloud-init-output.log'

  Building a machine can take awhile, to watch it happen SSH into the machine and ```tail -f /var/log/cloud-init-output.log```

# Caveats

* Installing runit via packages seems to break all further steps in the build process. As a work around include `apt-get install -y runit` in the `runcmd` section of your cloud init file.

* In order to access the environment variables from an include script you will need to `source /etc/environment`, there is no easy way to access them from a runcmd.
