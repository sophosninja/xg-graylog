# xg-graylog

Welcome to the Sophos XG Firewall Graylog installer. This collection of scripts will automatically install a Graylog SIEM into a Ubuntu 18.04 installation. The included Collection Package will automatically configure a lot of the Graylog settings for it to be able to work nicely with the data that the Sophos XG Firewall produces.

## Requirements

The installation script 'installer.sh' requires the following:

* A virtual or physical machine running:
  * Ubuntu 18.04
  * At least a dual core CPU
  * At least 4GB RAM
  * At least 40GB HDD
* An Internet connection is required for installation and updates.

## Installation Instructions

You'll want to install Git and download these scripts and configuration files. It just makes things easier:

```code
sudo apt update && sudo apt install git -y && git clone https://github.com/sophosninja/xg-graylog.git
```

Change the permissions on the 'installer.sh' script to allow it to execute:

```code
chmod +x installer.sh
```

And then run the installer!

```code
sudo sh ./installer.sh
```

You'll be prompted to enter some details and agree to my spelling mistakes and badly written code. Once happy, the scripts will run and automatically configure much of the system for you.

## Important Reads

There are various applications installed as part of the non-production quality deployment. You should read their manuals and guides about security:

* [Mongo](https://hub.docker.com/_/mongo/)
* [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/6.x/docker.htmll/)
* [Graylog](https://hub.docker.com/r/graylog/graylog/)

## WARNING

These scripts will uninstall Docker, containerd, and runc from the machine. If you are using these already, then this is not the script for you!
