#!/bin/bash

# Clean the tmp directory
rm temp/* 2>/dev/null

# Set Default Profile.  This assumes that you have followed these steps:
# https://github.com/Resistor52/tm_deep_security_poc/blob/master/configuration.md
export AWS_DEFAULT_PROFILE=$(cat setup.conf | grep "AWS_DEFAULT_PROFILE" | cut -d" " -f1 | cut -d"=" -f2)
export EC2_KEY_PAIR=$(cat setup.conf | grep "EC2_KEY_PAIR" | cut -d" " -f1 | cut -d"=" -f2)
export LOCAL_PEM=$(cat setup.conf | grep "LOCAL_PEM" | cut -d" " -f1 | cut -d"=" -f2)
export REGION=$(cat setup.conf | grep "REGION" | cut -d" " -f1 | cut -d"=" -f2)
export LINUX_IMAGEID=$(cat setup.conf | grep "LINUX_IMAGEID" | cut -d" " -f1 | cut -d"=" -f2)
export ACCOUNT=$(cat setup.conf | grep "ACCOUNT" | cut -d" " -f1 | cut -d"=" -f2)
export TREND_ID=$(cat setup.conf | grep "TREND_ID" | cut -d" " -f1 | cut -d"=" -f2)
export TREND_TOKEN=$(cat setup.conf | grep "TREND_TOKEN" | cut -d" " -f1 | cut -d"=" -f2)


# Get External IP Address for Configuration
MY_EXTERNAL_IP=$(curl -s icanhazip.com)
OUTPUT=$(echo $MY_EXTERNAL_IP | cut -d"." -f4 | wc -c)
if [ $OUTPUT == 1 ] || [ $OUTPUT -gt 4 ] # As a test of validity, check 4th octet string size
#if [ $OUTPUT -gt 4 ] # As a test of validity, check 4th octet string size
then
echo "*****ERROR - Unable to obtain a valid external IP Address for configuration. Result: "$MY_EXTERNAL_IP
exit 1
fi

# Test Profile Parameters
function test_config_file {
OUTPUT=$(cat setup.conf | grep $1 | wc -c)
if [ $OUTPUT == 0 ]
then
echo " "
echo "*****ERROR - Unable to find the $1 parameter in setup.config. See \
https://github.com/Resistor52/tm_deep_security_poc/blob/master/configuration.md and \
http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html for more information"
exit 1
fi
}
PARAMETER_LIST=$(cat setup.example.conf | cut -d"=" -f1)
for PARAMETER in $PARAMETER_LIST; do
  test_config_file $PARAMETER
done
OUTPUT=$(cat ~/.aws/config | grep $AWS_DEFAULT_PROFILE | wc -c)
if [ $OUTPUT == 0 ]
then
echo " "
echo "*****ERROR - Unable to find a profile in ~/.aws/config that matches the AWS_DEFAULT_PROFILE parameter set in \
this script. See https://github.com/Resistor52/tm_deep_security_poc/blob/master/configuration.md and \
http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html for more information"
exit 1
fi
OUTPUT=$(cat ~/.aws/credentials | grep $AWS_DEFAULT_PROFILE | wc -c)
if [ $OUTPUT == 0 ]
then
echo " "
echo "*****ERROR - Unable to find a profile in ~/.aws/credentials that matches the AWS_DEFAULT_PROFILE parameter set in \
this script. See https://github.com/Resistor52/tm_deep_security_poc/blob/master/configuration.md and \
http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html for more information"
exit 1
fi
REGIONLIST=(
    'us-east-2'
    'us-east-1'
    'us-west-1'
    'us-west-2'
    'ca-central-1'
    'ap-south-1'
    'ap-northeast-2'
    'ap-southeast-1'
    'ap-southeast-2'
    'ap-northeast-1'
    'eu-central-1'
    'eu-west-1'
    'eu-west-2'
    'sa-east-1'
    )
if [[ ! " ${REGIONLIST[@]} " =~ " ${REGION} " ]];
then
echo "*****ERROR - The REGION parameter set in this script is invalid.  For valid us-east-1s, See \
http://docs.aws.amazon.com/general/latest/gr/rande.html#ssm_us-east-1"
fi
OUTPUT=$(aws ec2 describe-key-pairs --profile $AWS_DEFAULT_PROFILE --region $REGION | grep $EC2_KEY_PAIR | wc -c)
if [ $OUTPUT == 0 ]
then
echo " "
echo "*****ERROR - Unable to find an EC2 Key Pair that matches the EC2_KEY_PAIR parameter set in \
this script. See https://github.com/Resistor52/tm_deep_security_poc/blob/master/configuration.md and \
http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html for more information"
exit 1
fi
if [ -e $LOCAL_PEM ]
then
echo "Profile Parameters Test Completed"
else
echo "*****ERROR - Unable to find the local PEM file that matches the LOCAL_PEM parameter set in \
this script. See https://github.com/Resistor52/tm_deep_security_poc/blob/master/configuration.md and \
http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html for more information"
exit 1
fi

echo; echo "Customize the config-ec2-with-agent.sh with Trend Micro Keys"
cp config-ec2-with-agent.template temp/config-ec2-with-agent.sh
sed -i "s/===TENANTID===/$TREND_ID/" temp/config-ec2-with-agent.sh
sed -i "s/===TOKEN===/$TREND_TOKEN/" temp/config-ec2-with-agent.sh


#***************** PROVISION ASSETS *****************
echo; echo "Create VPC"
OUTPUT=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --region $REGION)
export VPCID=$(echo $OUTPUT | cut -d" " -f7)
echo "VPC "$VPCID" created"
echo $VPCID > temp/vpc.log

echo; echo "Create a Subnet"
OUTPUT=$(aws ec2 create-subnet --vpc-id $VPCID --cidr-block 10.0.1.0/24 --output text --region $REGION)
export SUBNET_PUB=$(echo $OUTPUT | cut -d" " -f9)
echo $SUBNET_PUB created

echo; echo "Create an Internet gateway and attach to VPC"
OUTPUT=$(aws ec2 create-internet-gateway --output text --region $REGION)
export IGWID=$(echo $OUTPUT | cut -d" " -f2)
echo "Internet Gateway "$IGWID" created"
aws ec2 attach-internet-gateway --vpc-id $VPCID --internet-gateway-id $IGWID --output text --region $REGION
echo "Internet Gateway "$IGWID" attached to VPC "$VPCID
echo $IGWID > temp/igw.log

echo; echo "Create a custom route table for your VPC"
OUTPUT=$(aws ec2 create-route-table --vpc-id $VPCID --output text --region $REGION)
export ROUTETABLEID=$(echo $OUTPUT | cut -d" " -f2)
echo "Route Table "$ROUTETABLEID" created"
echo $ROUTETABLEID > temp/route-table.log

echo; echo "Create a route in the route table that points all traffic (0.0.0.0/0) to the Internet gateway"
OUTPUT=$(aws ec2 create-route --route-table-id $ROUTETABLEID --destination-cidr-block 0.0.0.0/0 \
--gateway-id $IGWID --output text --region $REGION)
if [ $OUTPUT == "True" ]
then
echo "Created a route in the route table that points all traffic (0.0.0.0/0) to Internet gateway"
else
echo "ERROR - Error creating route to Internet Gateway"
exit 1
fi

echo; echo "Associate Public Subnet with route and configure to recieve a public IP address"
OUTPUT=$(aws ec2 associate-route-table  --subnet-id $SUBNET_PUB --route-table-id $ROUTETABLEID \
--output text --region $REGION)
echo "Associated public subnet with route: "$OUTPUT
OUTPUT=$(aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB --map-public-ip-on-launch  \
--output text --region $REGION)
echo "Public Subnet configured to recieve a public IP Address"

echo; echo "Create a security group in VPC for Linux Instances"
OUTPUT=$(aws ec2 create-security-group --group-name sgLinux --description "Security \
group for Linux Instances" --vpc-id $VPCID  --output text --region $REGION)
export SECGROUP_LINUX=$OUTPUT
echo "Created security group "$SECGROUP_LINUX" in VPC "$VPCID
OUTPUT=$(aws ec2 authorize-security-group-ingress --group-id $SECGROUP_LINUX --protocol tcp --port 22 \
 --cidr $MY_EXTERNAL_IP"/32" --output text --region $REGION)
echo "Security Group "$SECGROUP_LINUX" allow inbound SSH from "$MY_EXTERNAL_IP

# Launch EC2 Instance
NAME="Deep_Security_POC"
OUTPUT=$(aws ec2 run-instances --image-id $LINUX_IMAGEID --count 1 --instance-type t2.large --key-name "$EC2_KEY_PAIR" \
--security-group-ids $SECGROUP_LINUX --subnet-id $SUBNET_PUB --private-ip-address "10.0.1.70" --tag-specifications \
"ResourceType=instance,Tags=[{Key=Name,Value=$NAME}]" --output text --region $REGION --user-data file://temp/config-ec2-with-agent.sh)
INSTANCE_ID=$(echo $OUTPUT | cut -d" " -f9)
echo $INSTANCE_ID > temp/instance.log

# Wait for EC2 Instance to enter running state
STATE="pending"
while [ "$STATE" != "running" ]; do
	echo "EC2 Instance "$STATE"....please wait"
	OUTPUT=$(aws ec2 describe-instances --instance-id $INSTANCE_ID --output text --region $REGION)
	STATE=$(echo $(echo $OUTPUT | sed 's/^.*STATE/STATE/') | cut -d" " -f3)
	if [ "$STATE" != "running" ]; then
		sleep 15
	fi
done
echo "EC2 Instance "$NAME"  ("$INSTANCE_ID") has entered the running state"
INSTANCE_IP=$(echo $(echo $OUTPUT | sed 's/^.*ASSOCIATION/ASSOCIATION/') | cut -d" " -f3)

# Wait for EC2 Instance to finish initializing
echo "Waiting for EC2 Configuration script to complete. This may take several minutes..."
STATE=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID | grep -c initializing)
while [ "$STATE" != "0" ]; do
    STATE=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID | grep -c initializing)
    echo "please wait..."
    sleep 15
done


# Generate Details for Linux system
echo "======= $NAME =======" >> temp/details.txt
echo "EC2 Instance $INSTANCE_ID has an external IP Address of $INSTANCE_IP" >> temp/details.txt
echo "Connect to instance using    ===>   ssh -i $LOCAL_PEM ubuntu@$INSTANCE_IP" >> temp/details.txt
echo " " >> temp/details.txt

cat temp/details.txt

echo; echo "Setup complete"
