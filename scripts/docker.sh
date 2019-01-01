#!/usr/bin/env bash

###############################################################
# install docker-engine
###############################################################
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
apt-cache policy docker-ce
sudo apt-get install -y docker-ce
#sudo systemctl status docker

###############################################################
# install docker
###############################################################
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
docker version
usermod -G docker vagrant

echo ############################################################### > /vagrant/exec.log
echo # Execution log! >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # make node app >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
cd /vagrant/etc/nodejs
echo cd /vagrant/etc/nodejs >> /vagrant/exec.log
docker build -t doohee323/tzapp:0.3 .
echo docker build -t doohee323/tzapp:0.3 . >> /vagrant/exec.log
docker rmi doohee323/tzapp:0.3 -f
docker images -a

docker run -d -p 49160:3000 --name node3 -t doohee323/tzapp:0.3 

docker stop node3
docker rm node3

docker run -d -p 49160:3000 --name node3 -t doohee323/tzapp:0.3 
echo docker run -d -p 49160:3000 --name node3 -t doohee323/tzapp:0.3 >> /vagrant/exec.log 
#docker run -p 49163:3000 --name node33 -it doohee323/tzapp:0.3 

docker logs node3
docker ps -a

#docker exec -it node3 /bin/bash
#curl http://localhost:3000

curl http://localhost:49160
echo curl http://localhost:49160 >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # Need to change user_id and password here!!! >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
docker login -u doohee323 -p hdh971097
echo docker login -u doohee323 -p hdh971097 >> /vagrant/exec.log
#docker login
#Username: doohee323
#Password:
#Login Succeeded

echo docker images -a >> /vagrant/exec.log
a_img=`docker images -a | grep 'doohee323/tzapp' | grep '0.3' | awk '{ print $3}'`
#a_img=`docker images -a | grep 'doohee323/tzapp' | grep '0.2' | awk '{ print $3}'`
docker tag ${a_img} doohee323/tzapp:0.3
echo docker tag ${a_img} doohee323/tzapp:0.3 >> /vagrant/exec.log
docker push doohee323/tzapp:0.3
echo docker push doohee323/tzapp:0.3 >> /vagrant/exec.log
# https://hub.docker.com/
# make a repository, ex) tzapp
docker images -a


