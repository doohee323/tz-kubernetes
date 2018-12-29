#!/usr/bin/env bash

sudo su
set -x

echo "Reading config...." >&2
source /vagrant/setup.rc

export DEBIAN_FRONTEND=noninteractive

apt-get install -y git

exit 0

sudo bash /vagrant/scripts/docker.sh
sudo bash /vagrant/scripts/elb.sh
sudo bash /vagrant/scripts/admin_ui.sh

#bash /vagrant/scripts/repl.sh
