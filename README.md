# Motivation
CloudMaker makes deployment of instances in the cloud easy and allows them to be configured

# Cloud init execution order

1. Environment variables are loaded into /etc/environment. **In order to access the environment variables from an include script you will need to `source /etc/environment`, there is no easy way to access them from a runcmd.**
1. SSH keys are installed.
1. Listed packages are installed.
1. Include scripts are executed.
1. Runcmds are executed.

# Caveats

* Installing runit via packages seems to break all further steps in the build process. As a work around include `apt-get install -y runit` in the `runcmd` section of your cloud init file.
