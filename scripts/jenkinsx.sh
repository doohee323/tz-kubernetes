#!/usr/bin/env bash

###############################################################
# install jenkinsx
###############################################################
curl -L https://github.com/jenkins-x/jx/releases/download/v1.3.153/jx-linux-amd64.tar.gz | tar xzv
sudo mv jx /usr/local/bin

jx create cluster aws

kops create cluster --ssh-public-key ~/.ssh/id_rsa.pub --yes \
    --name=nextransfer.net --state=s3://kops-state-hdh --zones=us-west-2 \
    --node-count=2 --node-size=t2.micro --master-size=t2.micro --dns-zone=nextransfer.net


kubectl get service -n kube-system jxing-nginx-ingress-controller  -oyaml | grep nextransfer.net

exit 0
