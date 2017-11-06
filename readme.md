# Trend Micro Deep Security POC
Provision an EC2 Instance with a Deep Security agent via CLI Script

## Instructions

To provision an EC2 Instance with a Deep Security Agent in AWS, enter the following
command:
```
./setup.sh # Set up the environment and configure the EC2 Instance
```

To use it you must [configure your AWS Profile Parameters](../master/doc/configuration.md)
in **setup.conf**.

`./teardown.sh` will delete all EC2 instances, the VPC, and other objects created
by the aws-setup script with the help of the .log files created during setup.

## Description
This script creates a single Amazon Linux instance in a dedicated VPC, complete
with security groups, routing and everything necessary to deploy via script.  

The `config-ec2-with-agent.sh` script boots the EC2 instance with a script that
installs the Deep Security agent on first boot.  

The script detects your external IP address and restricts inbound access to only
that address on port 22 (SSH).

Assuming that you create a Deep Security account as described below and add your
unique TREND_ID and TOKEN to the setup.conf, you see the agent in the 
[Trend Micro Dashboard](https://app.deepsecurity.trendmicro.com/Application.screen?#dashboard)

## Prerequisites
1. Sign up for a free [Trend Micro Deep Security Demo account](https://www.trendmicro.com/aws/free-trial/).
2. OPTIONAL: Add your AWS account to Trend Micro Deep Security using a cross-account role , following the
steps in this [article](https://help.deepsecurity.trendmicro.com/Add-Computers/add-aws.html#Add).
