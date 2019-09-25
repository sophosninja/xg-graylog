#!/bin/bash 
set -e

#AGREEMENTS
echo "Welcome to the Sophos Graylog Creator script. This is designed to setup and install the Graylog SIEM locally on a Linux host using Docker containers. 
This script is designed and tested on Ubuntu 18.04 only. It may work on other distributions, but I have not tested it, it might work, or it might break things, make kittens explode and otherwise cause global warming* and other ill-effects. There are no guarantees with this software, and if stuff does break, it's not my/our fault.
This script will install the following software:
  1. Docker
  2. Containerd
  3. Docker compose
This script will perform certain checks on the system and ask questions related to your setup.
Script created by Andy Martin. 
* Probably won't cause global warming, but you should use some good power saving features on your machines to help our Earth!"

echo ""

echo "Agreements
This should not be used in production, but is for demonstration purposes only. The script will install software on your machine, it is therefore recommended that you run this on a dedicated virtual machine that has been created solely for this purpose. If you agree to these warnings, enter 'yes' to continue."
read AGREE
if [ $AGREE != yes ]; then
    echo "I'm sorry you don't agree, but it's probably for the best"
    exit 0
fi

echo ""

# ARE YOU RUNNING AS ROOT/SUDO?
echo "This needs to be run as root. Are you running it as root or with sudo priviledges? (yes/no)"
read ROOT
if [ $ROOT != "yes" ]; then
    echo "Not root! Exiting"
    echo "Please run this script with root priviledges"
    exit 0
fi

echo ""

# SETTING THE IP ADDRESS OF THE GRAYLOG SERVER
echo "Your IP addresese are: " 
ip addr show | grep 'inet '
echo  "Set your preferred Graylog WebAdmin IP address:"
read IP_ADDRESS

# QUESTIONS
# Set new Graylog admin password:
echo "Now to secure the Graylog admin password."
echo "Need some salt first..."
echo ""
while [ ${#SALT} -le 15 ]
do
  echo "Mash the keyboard to create some salt (must be at least 16 characters long - Don't use commas):"
  read SALT
  if [ ${#SALT} -le 15 ]
  then 
    echo "Still too small! More mashing required!"
  #  else break
  fi
done
echo ""
echo "Set the Graylog admin password"
echo -n "Enter Password: "
read PASSWORD
SHA_PASSWORD=$(echo -n $PASSWORD | sha256sum | cut -d" " -f1)

# SET ANSWERS IN THE CONFIGURATION FILES
echo ""
echo "Modifying the docker-compose file with your customisations"
sed -i "s,GRAYLOG_PASSWORD_SECRET:.*,GRAYLOG_PASSWORD_SECRET: $SALT,g" docker-compose.yml
sed -i "s,GRAYLOG_ROOT_PASSWORD_SHA2:.*,GRAYLOG_ROOT_PASSWORD_SHA2: $SHA_PASSWORD,g" docker-compose.yml
sed -i "s,GRAYLOG_HTTP_EXTERNAL_URI:.*,GRAYLOG_HTTP_EXTERNAL_URI: \"http://$IP_ADDRESS:9000/\",g" docker-compose.yml
echo ""

# # Make sure the system is up to date first
echo "Forcing a system update"
apt-get update
apt-get dist-upgrade -y
echo ""

# Remove Ubuntu Docker installations and previous containerd packages
echo "Removing older versions of Docker and containerd"
apt-get remove docker docker-engine docker.io containerd runc
echo ""

# Add the Docker repositories and keys
echo "Adding the Docker community edition repositories"
apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update and Install Docker
echo ""
echo "Installing Docker"
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io -y

# Install Docker Compose and set to executable
echo ""
echo "Installing Docker Compose"
curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create required storage directories (logs and configurations will be saved here)
echo ""
echo "Creating the persistent storage directories"
mkdir -p /graylog/data/elasticsearch
mkdir -p /graylog/data/journal
mkdir -p /graylog/data/mongo
mkdir -p /graylog/config
mkdir -p /graylog/plugin
chown 1000:1000 /graylog/data/elasticsearch
chown 1100:1100 /graylog/data/journal
chown 1100:1100 /graylog/config
chown 1100:1100 /graylog/plugin

# Install Graylog Service
echo ""
echo "Creating the Sophos Graylog Service"
PWD=$(pwd)
sed -i "s,/DIRECTORY,$PWD,g" sophos-graylog.service
cp sophos-graylog.service /etc/systemd/system/sophos-graylog.service
chmod 644 /etc/systemd/system/sophos-graylog.service
echo "Enabling Sophos Graylog Service"
systemctl enable sophos-graylog.service

# Run Graylog docker containers
echo "Starting the Sophos Graylog docker containers"
systemctl start sophos-graylog.service

# Check Graylog is up and running
while true
do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://$IP_ADDRESS:9000)
  if [ $STATUS -eq 200 ]; then
    echo "Sophos Graylog is up and running."
    break
  else
    echo "Sophos Graylog is not up yet... please wait..."
  fi
  sleep 10
done

# Install Collector Package
echo ""
echo "Installing Sophos customisations..."
# Sophos XG Education Content Pack
GRAYLOG_CONTENT_ID=8932f1f0-4f35-4558-833b-ceab441f0532
GRAYLOG_CONTENT_REV=1
GRAYLOG_CONTENT_INSTALL='{"parameters":{},"comment":""}'

curl -u admin:$PASSWORD -d "@content-pack-8932f1f0-4f35-4558-833b-ceab441f0532-1.json" -H "Content-Type: application/json" -H "X-Requested-By: Graylog API" -X POST http://$IP_ADDRESS:9000/api/system/content_packs
curl -u admin:$PASSWORD -d "${GRAYLOG_CONTENT_INSTALL}" -H "Content-Type: application/json" -H "X-Requested-By: Graylog API" -X POST http://$IP_ADDRESS:9000/api/system/content_packs/$GRAYLOG_CONTENT_ID/$GRAYLOG_CONTENT_REV/installations

# Setting up inputs
#echo "Setting up additional data inputs for Graylog nodes..."
#
#GRAYLOG_INPUT_TCP='{"title":"SYSLOG-TCP","type":"org.graylog2.inputs.syslog.tcp.SyslogTCPInput","configuration":{"bind_address":"0.0.0.0","port":5140,"recv_buffer_size":1048576,"number_worker_threads":4,"tls_cert_file":"","tls_key_file":"","tls_enable":false,"tls_key_password":"","tls_client_auth":"disabled","tls_client_auth_cert_file":"","tcp_keepalive":false,"use_null_delimiter":false,"max_message_size":2097152,"override_source":null,"force_rdns":false,"allow_override_date":true,"store_full_message":false,"expand_structured_data":false},"global":true}'
#GRAYLOG_INPUT_UDP='{"title":"SYSLOG-UDP","type":"org.graylog2.inputs.syslog.udp.SyslogUDPInput","configuration":{"bind_address":"0.0.0.0","port":5140,"recv_buffer_size":262144,"number_worker_threads":4,"override_source":null,"force_rdns":false,"allow_override_date":true,"store_full_message":false,"expand_structured_data":false},"global":true}'

#
#curl -u admin:$PASSWORD -d "${GRAYLOG_INPUT_TCP}" -H "Content-Type: application/json" -H "X-Requested-By: Graylog API" -X POST http://$IP_ADDRESS:9000/api/system/inputs
#curl -u admin:$PASSWORD -d "${GRAYLOG_INPUT_UDP}" -H "Content-Type: application/json" -H "X-Requested-By: Graylog API" -X POST http://$IP_ADDRESS:9000/api/system/inputs


# All done, you can now start using it
echo ""
echo "Browse to http://$IP_ADDRESS:9000 and login as 'admin' to get started."
echo ""
echo "Start sending SYSLOG data to the Grayloy server @ $IP_ADDRESS:5140 (UDP)"

#################################### TO DO ################################################

# Create an nginx reverse proxy with HTTPS setup to route to the graylog 9000 port (change to expose rather than port)
# https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-with-ssl-as-a-reverse-proxy-for-jenkins
# https://dev.to/domysee/setting-up-a-reverse-proxy-with-nginx-and-docker-compose-29jg