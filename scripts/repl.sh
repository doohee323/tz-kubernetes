#!/usr/bin/env bash

cd /vagrant/libs

echo ############################################################### >> /vagrant/exec.log
echo # Make a controller >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl create -f app-controller/tzapp-repl-controller.yml
kubectl get pods
kubectl scale --replicas=4 -f app-controller/tzapp-repl-controller.yml
kubectl get rc
kubectl scale --replicas=1 -f app-controller/tzapp-repl-controller.yml
kubectl get rc
kubectl get pods
#kubectl delete rc/tzapp-controller
kubectl get pods

echo ############################################################### >> /vagrant/exec.log
echo # Make a deployment >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl get deployments
kubectl get rs
kubectl get pods --show-labels

#kubectl label nodes ip-172-20-63-194.us-west-2.compute.internal hardware=high-spec
#kubectl get nodes --show-labels | grep 'hardware=high-spec'

kubectl create -f app-deployment/tzapp-deployment.yml
#kubectl create -f app-deployment/tzapp-deployment_label.yml
#kubectl delete -f app-deployment/tzapp-deployment.yml

kubectl rollout status deployment/tzapp-deployment
kubectl expose deployment tzapp-deployment --type=NodePort
kubectl get services
kubectl describe service tzapp-deployment
kubectl set image deployment/tzapp-deployment app-deploy=doohee323/tzapp:0.2
kubectl rollout status deployment/tzapp-deployment
kubectl get pods

#kubectl edit deployment/tzapp-deployment
kubectl rollout history deployment/tzapp-deployment
kubectl rollout undo deployment/tzapp-deployment
kubectl rollout undo deployment/tzapp-deployment --to-revision=2

echo ############################################################### >> /vagrant/exec.log
echo # Make a service >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl delete svc tzapp-service
kubectl delete svc node-tzapp-service
kubectl create -f app-service/tzapp-service.yml
kubectl get services
kubectl get pods
kubectl expose deployment tzapp-deployment --name=node-tzapp-service





