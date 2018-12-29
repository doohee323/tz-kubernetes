#!/usr/bin/env bash

###############################################################
# Install kubectl
###############################################################
#https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-via-curl
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

###############################################################
# Install kops
###############################################################
#https://github.com/kubernetes/kops/releases
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops

###############################################################
# Install awscli
###############################################################
sudo apt-get install python-pip -y
sudo pip install awscli

# * make a sub domain in route53 ex) kops.sodatransfer.com
#sudo apt-get install whois
#sudo apt-get install bind9-host
#host -t NS kops.sodatransfer.com
#whois sodatransfer.com
#whois kops.sodatransfer.com

# Make ssh key
rm -Rf ~/.ssh/id_rsa*
# ssh-keygen -f ~/.ssh/id_rsa
ssh-keygen -f ~/.ssh/id_rsa -q -N ""

# Set aws env.
mkdir -p /root/.aws
cp -rf /vagrant/etc/aws/config /root/.aws
cp -rf /vagrant/etc/aws/credentials /root/.aws 	

echo ############################################################### >> /vagrant/exec.log
echo # Make a master and nodes >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
# Clean up kubes!!!!
kops delete cluster --name nextransfer.net --yes --state=s3://kops-state-hdh
echo sleep 60
sleep 60

kops create cluster --ssh-public-key ~/.ssh/id_rsa.pub --yes \
    --name=nextransfer.net --state=s3://kops-state-hdh --zones=us-west-2 \
    --node-count=3 --node-size=t2.micro --master-size=t2.micro --dns-zone=nextransfer.net

echo kops create cluster --ssh-public-key ~/.ssh/id_rsa.pub --yes \
    --name=nextransfer.net --state=s3://kops-state-hdh --zones=us-west-2 \
    --node-count=3 --node-size=t2.micro --master-size=t2.micro --dns-zone=nextransfer.net >> /vagrant/exec.log

#kops edit cluster nextransfer.net --state=s3://kops-state-hdh
kops update cluster nextransfer.net --yes --state=s3://kops-state-hdh
echo kops update cluster nextransfer.net --yes --state=s3://kops-state-hdh >> /vagrant/exec.log
#kops rolling-update cluster

echo sleep 60
sleep 60

echo ############################################################### >> /vagrant/exec.log
echo # Check master status >> /vagrant/exec.log
echo # ssh -i ~/.ssh/id_rsa admin@api.nextransfer.net >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_master=`aws ec2 describe-instances --filters "Name=tag:Name,Values=*masters.nextransfer.net" \
--query 'Reservations[*].Instances[*].[PublicIpAddress,InstanceId,State.Name,Tags[?Key==\`Name\`].Value]' \
--output text --region us-west-2 | grep running`

a_master_ip=`echo ${a_master} | awk '{print $1}'`
a_master_id=`echo ${a_master} | awk '{print $2}'`

echo "a_master_ip: ${a_master_ip}"
echo "a_master_id: ${a_master_id}"

a_sid=`aws ec2 describe-security-groups --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | grep -A 1 'masters.nextransfer.net' | head -2 | tail -1 | awk '{ print $2}' | sed 's|"||g'`
echo ${a_sid}

aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol icmp --port -1 --cidr 0.0.0.0/0

a_try_n=0
while :;do
	echo sleep 20
	sleep 20
	a_try=`dig api.nextransfer.net | grep 'api.nextransfer.net.' | head -2 | tail -1 | awk '{ print $5}'`
	echo ${a_try}
	if [ "${a_try}" == "${a_master_ip}" ]; then
		echo "ok"
		ping api.nextransfer.net -c 5
		echo sleep 20
		sleep 20
		break
	elif [ "$a_try_n" -eq 200 ]; then
		echo "still but break here!"
		kops delete cluster --name nextransfer.net --yes --state=s3://kops-state-hdh
		break
	else
		echo "stil ${a_try} != ${a_master_ip}"
		a_try_n=`expr $a_try_n + 1`
	fi
done

kubectl get node
echo kubectl get node >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # Check master >> /vagrant/exec.log
echo # ssh -i ~/.ssh/id_rsa admin@api.nextransfer.net >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # **** Run a service with a pod and a ELB >> /vagrant/exec.log
echo # 1. Create Service with pod >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
cd /vagrant/libs
echo cd /vagrant/libs >> /vagrant/exec.log
kubectl create -f app-elb/tzapp.yml
#kubectl delete -f app-elb/tzapp.yml
echo kubectl create -f app-elb/tzapp.yml >> /vagrant/exec.log
kubectl get pod
#watch -n1 kubectl get pods
echo kubectl get pod >> /vagrant/exec.log
kubectl describe pod node-tzapp.nextransfer.net

a_try_n=0
while :;do
	echo sleep 10
	sleep 10
	a_try=`kubectl describe pod node-tzapp.nextransfer.net | grep 'Status:' | awk '{ print $2}'`
	echo ${a_try}
	if [ "${a_try}" == "Running" ]; then
		echo "ok"
		echo sleep 10
		sleep 10
		break
	elif [ "$a_try_n" -eq 10 ]; then
		echo "still but break here!"
		echo kops delete cluster --name nextransfer.net --yes --state=s3://kops-state-hdh
		break
	else
		echo "stil"
		echo kubectl describe pod node-tzapp.nextransfer.net | grep 'Status:' | awk '{ print $2}'
		a_try_n=`expr $a_try_n + 1`
	fi
done

# Test the service with 8081
#kubectl port-forward node-tzapp.nextransfer.net 8081:3000
# curl http://localhost:8081

echo ############################################################### >> /vagrant/exec.log
echo # 2. Deploy Service to aws >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl expose pod node-tzapp.nextransfer.net --type=NodePort --name=node-tzapp-service
echo kubectl expose pod node-tzapp.nextransfer.net --type=NodePort --name=node-tzapp-service >> /vagrant/exec.log
#kubectl describe pod node-tzapp.nextransfer.net | grep Liveness

kubectl create -f app-elb/tzapp-service.yml
echo kubectl create -f app-elb/tzapp-service.yml >> /vagrant/exec.log
sleep 60

echo ############################################################### >> /vagrant/exec.log
echo # 3. Get Service port >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl get service
a_port=`kubectl get service | grep 'LoadBalancer' | grep 'tzapp-service' | head -2 | tail -1 | awk '{ print $5}'`
in1=`expr index $a_port ":"`; in2=`expr index $a_port "/"`; in2=`expr $in2 - $in1 - 1` 
a_port=${a_port:$in1:$in2}
echo ${a_port}
#kubectl describe service node-tzapp-service

echo ############################################################### >> /vagrant/exec.log
echo # 4. Get ELB IDs >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_elb=`kubectl describe service tzapp-service | grep 'LoadBalancer Ingress' | awk '{ print $3}'`
in1=`expr index $a_elb "-"`;  in1=`expr $in1 - 1`;  a_elb=${a_elb:0:$in1}
echo ${a_elb}

echo ############################################################### >> /vagrant/exec.log
echo # 5. Get working EC2 IPs >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_ec2=`aws elb describe-instance-health --region us-west-2 --load-balancer-name ${a_elb} | grep '"InstanceId":' | awk '{ print $2}'`
echo ${a_ec2}
a_sid=`aws ec2 describe-security-groups --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | grep -A 1 'nodes.nextransfer.net' | head -2 | tail -1 | awk '{ print $2}' | sed 's|"||g'`
echo ${a_sid}

while IFS= read -r ec2_id; do
    #echo "$ec2_id"
    ec2_id=$(echo $ec2_id | sed 's|,||g' | sed 's|"||g')
    a_ec2_ip=`aws ec2 describe-instances --region us-west-2 --instance-ids ${ec2_id} | grep '"PublicIp"' | head -2 | tail -1 | awk '{ print $2}' | sed 's|,||g' | sed 's|"||g'`
    echo ""
    echo ""
	echo "Added a port, ${a_port} on ES2 ${a_ec2_ip}'s firewall!!!"
	aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol tcp --port ${a_port} --cidr 0.0.0.0/0
	echo aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol tcp --port ${a_port} --cidr 0.0.0.0/0 >> /vagrant/exec.log
    echo "curl http://${a_ec2_ip}:${a_port}" >> /vagrant/exec.log
    echo ""
    echo ""
done <<< "${a_ec2}"

#kubectl config get-contexts
#kubectl expose pod node-tzapp.nextransfer.net --port=444 --name=frontend
#kubectl attach node-tzapp.nextransfer.net
#kubectl run -i --tty busybox --image=busybox --restart=Never -- sh
#kubectl exec node-tzapp.nextransfer.net -- ls -al
#kubectl label pods node-tzapp.nextransfer.net mylabel=awesome

#curl http://tzapp.nextransfer.net
echo kubectl cluster-info >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # 6. Make a HTTP listener for elb >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
aws elb create-load-balancer-listeners --load-balancer-name ${a_elb} --listeners "Protocol=TCP,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=${a_port}"
echo aws elb create-load-balancer-listeners --load-balancer-name ${a_elb} --listeners "Protocol=TCP,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=${a_port}" >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # 7. Make test domain using elb  >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_elb2=`aws elb describe-load-balancers --load-balancer-name ${a_elb} --output text | head -n 1`
a_alias_zone_id=`echo ${a_elb2} | awk '{ print $3}'`
a_dns_name=`echo ${a_elb2} | awk '{ print $2}'`
echo ${a_alias_zone_id}
echo ${a_dns_name}

a_hosted_zone_id=`aws route53 list-hosted-zones --output text | grep nextransfer.net| awk '{ print $3}'`
echo ${a_hosted_zone_id}
#change_batch="{\"Changes\":[{\"Action\":\"CREATE\",\"ResourceRecordSet\":{\"Name\":\"test.nextransfer.net\",\"Type\":\"A\",\"TTL\":60,\"ResourceRecords\":[{\"Value\":\"dualstack.abe48a4c79cbf11e8a146029f66f9273-1075833232.us-west-2.elb.amazonaws.com\"}]}}]}"

change_batch="{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":{\"Name\":\"test.nextransfer.net\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"${a_alias_zone_id}\",\"DNSName\":\"dualstack.${a_dns_name}\",\"EvaluateTargetHealth\":false}}}]}"
aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch}

sleep 10

change_batch="{\"Changes\":[{\"Action\":\"CREATE\",\"ResourceRecordSet\":{\"Name\":\"test.nextransfer.net\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"${a_alias_zone_id}\",\"DNSName\":\"dualstack.${a_dns_name}\",\"EvaluateTargetHealth\":false}}}]}"
aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch}
echo aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch} >> /vagrant/exec.log

echo curl http://test.nextransfer.net >> /vagrant/exec.log 

cat /vagrant/exec.log

exit 0

###############################################################
# Run a service without pod
###############################################################
#kubectl run tzapp-kubernetes --image=gcr.io/google_containers/echoserver:1.4 --port=8080
#kubectl expose deployment tzapp-kubernetes --type=NodePort
#kubectl get service

#kubectl run node-tzapp-service --image=doohee323/tzapp:0.1 --port=3000
#kubectl expose deployment node-tzapp-service --type=NodePort
#kubectl get service
#kubectl delete svc node-tzapp-service

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/
#kubectl delete po,svc --all

###############################################################
# Run a service with a pod 
###############################################################
kubectl create -f app-pod/pod-tzapp.yml
kubectl get pod
#kubectl logs node-tzapp-service
#kubectl edit -f app-pod/pod-tzapp.yml --save-config
#kubectl delete -f app-pod/pod-tzapp.yml
#kubectl delete pods podname --grace-period=0 --force

kubectl delete pod node-tzapp.nextransfer.net
#kubectl delete svc node-tzapp-service

#kubectl delete svc node-tzapp-service
#kubectl expose pod tzapp-kubernetes-56fd99dc9-8gc9f --type=NodePort --name=node-tzapp-service



