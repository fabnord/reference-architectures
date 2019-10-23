#!/usr/bin/env bash
set -e 
set -o pipefail

cloud_type="azure"
seed_node_dns_name=$1

echo "Input to node.sh is:"
echo cloud_type $cloud_type
echo seed_node_dns_name $seed_node_dns_name

echo "Calling opscenter.sh with the settings:"
echo cloud_type $cloud_type
echo seed_node_dns_name $seed_node_dns_name

export DEBIAN_FRONTEND=noninteractive
apt-get -yq update
apt-get -yq install unzip openjdk-8-jdk

wget https://github.com/DSPN/install-datastax-ubuntu/archive/master.zip
unzip master.zip
cd install-datastax-ubuntu-master/bin

# Since we are using Azure Private DNS, this doesn't work correctly anymore, so we'll fix it. :)
sed -i 's/\.\/opscenter\/configure_opscenterd_conf\.sh \$opscenter_broadcast_ip/\.\/opscenter\/configure_opscenterd_conf\.sh 10.0.0.132/g' ./opscenter.sh

# Fix the Java install
sed -i 's/\.\/os\/install_java\.sh/\.\/os\/install_java\.sh -m/g' ./opscenter.sh

# The default version of 6.7.1 is no longer available, so we have to set this.
export OPSC_VERSION=6.7.4
./opscenter.sh $cloud_type $seed_node_dns_name