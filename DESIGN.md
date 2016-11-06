# Cloud Maker Design Document

## Status

In Progress: This document is a draft that is actively being worked on.

Things marked in this document as NYI are Not Yet Implemented.

## People

Authors: Nathan Baxter
Reviewers: Tobi Knaup, Flo Leibert

## Overview

It should be possible for an engineer to launch new instances or debug existing instances, however often it is difficult to find the correct documentation or to know if a system was built with the same specifications as are currently documented. It is also often difficult to access the Amazon console in a time of crisis when launching and debugging instances is most critical. Cloud Maker aims to solve these problems by providing a command line interface to launch and retrieve information about instances. Instances will be described by a human readable configuration file, which will be archived at instance launch, to provide a documentation source both for launching new instances and debugging existing ones.

## Background

This project started out of a need for a better way to provide instance specific configuration. We had been using EC2 tags set through the Amazon console as a way to pass configuration data to instances, however depending on the state of the Amazon API there were times when the tags were not set before the cloud init scripts for an instance were executed. As we considered ways to address this problem and realized that it would likely require a new tool to launch instances we also identified several other issues that might be addressed by the same tool.

We had an existing internal tool for launching some specific instance types when the Amazon console was unavailable. However, it was not something we expected to be easily extendable to a more generic case. It did give us a good idea of what a starting point for functionality should be, and we appropriated its name for the project. Producing a tool that could serve as a more generic replacement for launching new instances became a project goal.

We also wanted to produce a record of how an instance had been built and archive it for review later in the case of a problem with the instance. This is something that would help anyone troubleshoot an instance, but especially those who might be less familiar with it. Democratizing the ability to troubleshoot problems with an instance became another project goal.

## Requirements

* Launch new EC2 instances appropriate to a service from a CLI
* Install all necessary software and perform all configuration necessary to launch a service on a new instance
* Support instance specific configuration properties from a service specific configuration file
* Allow sharing of configuration data between services (ie. through inheritance or aggregation)
* Produce an archive of the configuration and the ability to retrieve it

## Design Overview

There are three primary pieces to the Cloud Maker design, a config object (backed by a YAML file), an ec2 interface, and the CLI for user interaction.

### Configuration

The most important component of Cloud Maker is the configuration. It is an extension of the CloudInit format (https://help.ubuntu.com/community/CloudInit). The CloudInit format has been extended to include three other top level properties: ```include```, ```import``` **NYI** and ```cloud-maker``` to support CloudInit includes, importing local CloudMaker config files, and setting configuration properties respectively. When the instance is created this configuration will be compiled into a CloudInit multipart mime archive to be used as the user data for the instance.

The configuration is generally loaded from a YAML file, but is accessed internally as a CloudMaker::Config object. The config object is also capable of producing a CloudInit friendly multipart archive describing itself.

### Cloud Interaction (EC2)

The CloudMaker::EC2 class handles launching an instance with the appropriate user data and performing any post-launch meta configuration (such as tags, elastic ips, etc). It relies on access to a CloudMaker::Config object to provide the content/configuration for these interactions. While initially only EC2 support is on the roadmap the separation of configuration from instance instantiation should allow flexibility if supporting other platforms becomes desirable.

### CLI

It is intended to provide a user friendly interface for launching and retrieving information about instances. It will instantiate the config and ec2 objects and act as the controller to actually execute actions. It will also be responsible for passing in execution time configurations to the config object, these will be passable as command line arguments, through environment variables, or if specified in the config file the user will be prompted to enter them if they haven't been provided elsewhere.

## Software Dependencies

* Thor for generation of the CLI
* Right AWS for interaction with EC2

## Detailed Design

### Configuration File Format

The ```include``` property contains either an array of URLs or a string containing include user data (one URL per line with comments allowed prefixed by #). These URLs will be included in the CloudInit user data that the instance is initialized with, each will downloaded and treated as a CloudInit file (most often they will consist of shell scripts to be executed on the instance).

**NYI** The ```import``` property is used as a local import. It consists of an array of other Cloud Maker configurations that will be merged into the one importing them. Properties will be deeply merged where possible. The order of precedence is the file with the import statement, followed by the list of imports in reverse order (ie. base file overrides imports[n+1] overrides imports[n]).

The ```cloud-maker``` property describes configuration properties for the instance, these include both properties for launching the instance, and properties for building the instance once it is launched. By default all properties specified here will be available as global environment variables within the instance. Properties specified in ```cloud-maker``` can come in two different formats:

1. **key: value** - This is the simplest way to specify properties. The key will simply be assigned the property value.
1. **key: property_config** - If the value passed in is itself a hash and it contains at least one of the keys described below it will be treated as a property_config. This allows greater control of how the property is handled.
    * ```environment``` True by default, if set to false there will be no environment variable created for **key**.
    * ```required``` False by default, if set to true the value will be prompted for if it isn't passed in via the command-line or an environment variable.
    * ```default``` Nil by default, if set the value will be prompted for if it isn't passed in, but a default value will be provided as a suggestion to the user.
    * ```value``` Nil by default, if set the value will be used and the user will not be prompted. They may still override it via the command-line but not via an environment variable.
    * ```description``` Nil by default, shown to the user when prompting them about a property.

### Configuration Object

The configuration object provides an interface for getting/setting configuration properties, and for exporting itself to user data for use with CloudInit. Internally configuration object parses out the properties of the config file it knows about and assumes all other properties belong to CloudInit.

It provides getter/setter functionality for the Cloud Maker specific properties through the ```[]``` and ```[]=``` functions. These functions access and set the value of the property config rather than returning the property config itself. If access to the property config is desired it can be accessed via ```<config_object>.options[<key>]```.

The list of URLs to be included can be accessed via the ```includes``` accessor, it is internally represented as an array of URLs regardless of its representation in the YAML file.

The list CloudInit config can be accessed via the ```cloud_config``` accessor.

When exporting to user data a multipart archive with 3 components is generated.

1. The first component is a CloudInit boothook script that sets all properties in the ```cloud-maker``` section as environment variables by adding them to ```/etc/environment```. Hashes/arrays will be expanded to have keys of the form key_index = value (eg. key1: {foo: bar} will generate an environment variable named key1_foo with the value bar). If you need to access these environment variables from within a CloudInit script you will need to ```source /etc/environment```.
1. The second component is the CloudInit config file. This will be generated by deep merging any imported configurations (**NYI**) and executing any !shell-script nodes and then exporting back to YAML. The CloudMaker::Config object has no special awareness of any of the internal properties in this section.
1. The third component is a CloudInit include file. It will be generated by concatenating all of the imports includes list together (**NYI**) with the base configuration's include list last. Each URL in the include file will be treated as a CloudInit file in its own right, however our most common use case is to use this section to include shell scripts (including .arx files) to be run on the new instance.

### YAML Shell Script Extension

Using YAML as our configuration format has the advantage of making our configuration files readable and well structured. The downside to it though is that it provides no built-in interface for more complex logic or interfacing with other tools. We felt that best way to provide the power to bridge this divide was to allow for a new type of YAML node. The ```!shell-script``` node type will execute (once per instantiation) its contents and replaces itself with the resulting string (with a trailing newline removed if it exists). An example should serve to illustrate this:

    # These two configurations produce equivalent results

    cloud-maker:
      foo: bar

    cloud-maker:
      foo: !shell-script echo bar

### EC2

CloudMaker::EC2 provides a wrapper around RightAws that pulls configuration information from a CloudMaker::Config object and uses it to launch an instance and to archive configuration information about that instance. It also provides an interface for later retrieving the configuration information for a previously launched instance. It relies on several ```cloud-maker``` properties.

* ```ami``` (required) - The AMI ID to use for the new instance eg 'ami-82fa58eb'
* ```instance_type``` (required) - The AWS instance type, eg. 'm1.small'
* ```availability_zone``` (required) - The AWS availability zone eg. 'us-east-1b'
    <br/>_Tobi, you mentioned striping across zones in a pull request comment. I think that functionality might be better suited to being integrated into a multi_launch CLI command that handles passing appropriate availability zone information to the individual instances it spins up, any thoughts?_
* ```key_pair``` (required) - The security key that will be associated with the instance.
* ```security_group``` (optional) - The security group (or groups) that will be assigned to the instance eg. 'default'
* ```s3_archive_bucket``` (required) - The S3 bucket to archive configuration information.
* ```elastic_ip``` (optional) - If specified after the instance is launched we will continue polling until it has entered a running state and then associated the specified elastic IP.
* ```tags``` (optional) - A hash, each key, value pair will be assigned as an EC2 tag as soon as the instance is launched.

### CLI

The CLI is implemented in Thor and help information for any command can be accessed via ```cloud-maker help <command>```. Below is a list of the existing and planned functionality.

* ```launch``` - The launch command launches an individual EC2 instance, it provides interactive prompts for missing configuration settings and provides summary data of the newly launched instance.
* ```user_data``` - Generates the user data the would be used to launch a new instance but does not create a new instance. It will provide the same prompts for configuration as ```launch``` and can be used as a dry-run.
* ```multi-launch```? **NYI** - Provide a wrapper around launch for initializing multiple instances with the ability to stripe across zones.
* ```info``` **NYI** - Fetch information about the current state of an instance and the configuration which it was built from.
* ```terminate``` **NYI** - Terminate a running instance.

## Caveats

* We chose to build our own tool rather than lean on an existing tool (ie. Chef/Opscode) because we wanted to be able to rely as much as possible on our existing configuration infrastructure and to use a small and simple tool rather than bringing in a significant new source of complexity.
* The !shell-script functionality provides a window into existing configuration tools, in particular s3dist which can be used to generate the ```include``` property of the config file.

## Testability

* Unit tests should be written for at least the lib portions of this codebase _I would love to hear anyone's thoughts about hooking into infrastructure for automatically executing them._
* Special attention should be paid to the YAML integration as Ruby doesn't always use the same underlying YAML library.

## Security & Privacy Plan

This is a publicly accessible tool and repository. As such it is important that all developers ensure that private information, especially security credentials are kept completely out of this code base.

## Open Source

This project is being developed entirely in the open under a three clause BSD license. Flo has been taking the point on this aspect of things, looking for way to share basic system configurations with the community. Once a basic level of stability has been reached it is an excellent candidate for a blog post.

## Logging

This system relies on access to an S3 bucket for storing configuration information. The information is stored based on instance ID.

## Launch plan

Systems are expected to be gradually migrated to launching using Cloud Maker as work is done on them. Cloud Maker development will proceed based on feedback from the initial services.

## Approximate Timeline

<table>
  <tr>
    <th>Version</th>
    <th>Highlights</th>
    <th>Who</th>
    <th>Date</th>
  </tr>
  <tr>
    <td>0.0.0</td>
    <td>Launch command functional, config file working (without import), config archiving working</td>
    <td>Nathan Baxter</td>
    <td>July 20th, 2012</td>
  </tr>
  <tr>
    <td>0.1.0</td>
    <td>Add in commands for user_data, info, and termination. Support importing cloud maker config files.</td>
    <td>Nathan Baxter</td>
    <td>ETA: August 3rd, 2012</td>
  </tr>
</table>

## Major Document History (optional)

<table>
  <tr>
    <th>Date</th>
    <th>Author</th>
    <th>Description</th>
    <th>Reviewed by</th>
    <th>Signed off by</th>
  </tr>
  <tr>
    <td>July 31st, 2012</td>
    <td>Nathan Baxter</td>
    <td>Initial Design Draft</td>
    <td></td>
    <td></td>
  </tr>
</table>
