#!/usr/bin/env bash
set -e 
set -o pipefail

cloud_type="azure"
seed_node_dns_name=$1
opscenter_node_dns_name=$2
data_center_name=$3

echo "Calling dse.sh with the settings:"
echo cloud_type $cloud_type
echo seed_node_dns_name $seed_node_dns_name
echo opscenter_node_dns_name $opscenter_node_dns_name
echo data_center_name $data_center_name

export DEBIAN_FRONTEND=noninteractive
apt-get -yq update
apt-get -yq install unzip openjdk-8-jdk

wget https://github.com/DSPN/install-datastax-ubuntu/archive/master.zip
unzip master.zip
cd install-datastax-ubuntu-master/bin

# Since we are using Azure Private DNS, this doesn't work correctly anymore, so we'll fix it. :)
sed -i 's/node_broadcast_ip=`curl --retry 10 icanhazip\.com`/node_broadcast_ip=`echo $(hostname -I)`/g' ./dse.sh

# Fix the Java install
sed -i 's/\.\/os\/install_java\.sh/\.\/os\/install_java\.sh -m/g' ./dse.sh

# The default version of 6.7.1 is no longer available, so we have to set this.
export OPSC_VERSION=6.7.4
./dse.sh $cloud_type $seed_node_dns_name $data_center_name $opscenter_node_dns_name