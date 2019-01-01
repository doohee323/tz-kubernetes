#!/usr/bin/env bash

cd /vagrant/libs

echo ############################################################### >> /vagrant/exec.log
echo # Install admin UI >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

echo ############################################################### >> /vagrant/exec.log
echo # Make an user >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl create -f dashboard/sample-user.yml
echo kubectl create -f dashboard/sample-user.yml >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo "# Open https://api.topzone.biz/ui" >> /vagrant/exec.log
echo "# Log in with username / password" >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_auth=`kubectl config view | tail -n 2`
echo kubectl config view | tail -n 2  >> /vagrant/exec.log
echo ${a_auth}  >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo "log in with this token" >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # Install admin UI >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_token=`kubectl -n kube-system get secret | grep admin-user | awk '{ print $1}'`
echo a_token=`kubectl -n kube-system get secret | grep admin-user | awk '{ print $1}'` >> /vagrant/exec.log
a_token=`kubectl -n kube-system describe secret ${a_token}`
echo a_token=`kubectl -n kube-system describe secret ${a_token}` >> /vagrant/exec.log
echo ${a_token}

# kubectl run -i --tty busybox --image=busybox --restart=Never -- sh
# vi /etc/resolv.conf
# nameserver 100.64.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local us-west-1.compute.internal
# options ndots:5

kubectl create -f manage/lifecycle.yml
#kubectl delete -f manage/lifecycle.yml
a_pod=`kubectl get pods | grep lifecycle | awk '{ print $1}'`
kubectl exec -it ${a_pod} -- tail -f /timing

mkdir -p /root
echo -n "root" > /root/username.txt
echo -n "password11" > /root/password.txt
# echo -n "root" | base64
# echo -n "password11" | base64
#kubectl create secret generic db-secrets --from-file=/root/username.txt --from-file=/root/password.txt

cd /vagrant/libs
#kubectl delete secret db-secrets
kubectl delete -f mysql/db-secrets.yml
kubectl create -f mysql/db-secrets.yml
#kubectl create secret generic my-secret --from-file=ssh-privatekey=/root/.ssh/id_rsa --from-file=ssh-publickey=/root/.ssh/id_rsa.pub
kubectl get secret 

#kubectl delete -f app-deployment/tzapp-deployment.yml
kubectl create -f app-deployment/tzapp-deployment.yml

a_pod=`kubectl get pods | grep tzapp-deployment | head -2 | tail -1 | awk '{ print $1}'`
kubectl describe pod ${a_pod} | grep '/etc/creds'
echo kubectl exec ${a_pod} -i -t -- /bin/bash
echo cat /etc/creds/password

kubectl create -f mysql/mysql.yml
kubectl create -f mysql/mysql-service.yml

database->helloworld
password->password
rootPassword->rootpassword
username->helloworld

kubectl exec mysql -i -t -- mysql -u root -p
# username->rootpassword
kubectl exec mysql -i -t -- bash
# mysql -u root -p
# rootpassword
# show databases;
# use helloworld;
# show tables;

kubectl create configmap app-config --from-file=/vagrant/etc/app.properties
kubectl create configmap nginx-config --from-file=/vagrant/etc/nginx/reverseproxy.conf
#kubectl delete configmap nginx-config

kubectl get configmap
kubectl get configmap nginx-config -o yaml

#kubectl delete -f tzapp-nginx/nginx.yml
#kubectl delete -f tzapp-nginx/nginx-service.yml
kubectl create -f tzapp-nginx/nginx.yml
#kubectl create -f tzapp-nginx/nginx-service.yml

#kubectl port-forward tzapp-nginx 8081:30481
#kubectl expose pod tzapp-nginx --type=NodePort --name=tzapp-nginx-service
#curl http://13.125.191.194:30052 -vvvv
#kubectl exec -i -t tzapp-nginx -c nginx -- bash

echo ############################################################### >> /vagrant/exec.log
echo # Ingress
echo ############################################################### >> /vagrant/exec.log
kubectl create -f tzapp-ingress/ingress.yml
#kubectl delete -f tzapp-ingress/nginx-ingress-controller.yml
kubectl create -f tzapp-ingress/nginx-ingress-controller.yml

kubectl create -f tzapp-ingress/tzapp-v1.yml
kubectl create -f tzapp-ingress/tzapp-v2.yml














