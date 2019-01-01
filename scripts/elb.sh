#!/usr/bin/env bash

RTN=0
function check_nw_loading {
	a_command=${1}
	a_check=${2}
	a_max_count=${3}
	echo "- Checking: "${a_command}
	echo "- With: "${a_check}
	echo "- Max Times: "${a_max_count}
	a_try_n=0
	while :;do
		sleep 10
		a_try=$(eval ${a_command})
		echo ${a_try}
		if [ "${a_try}" == "${a_check}" ]; then
			echo "ok"
			RTN=0
			return
		elif [ "$a_try_n" -eq ${a_max_count} ]; then
			echo "still but break here!"
			break
		else
			echo "stil ${a_try} != ${a_check}"
			a_try_n=`expr $a_try_n + 1`
		fi
	done
	RTN=-1
	return
}

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
sudo apt-get update
sudo apt-get install python-pip -y
sudo pip install awscli

###############################################################
# Make s3 bucket
###############################################################
echo aws s3api create-bucket --bucket kops-state-tz --region us-west-1 --create-bucket-configuration LocationConstraint=us-west-1 >> /vagrant/exec.log
aws s3api create-bucket --bucket kops-state-tz --region us-west-1 --create-bucket-configuration LocationConstraint=us-west-1
export KOPS_STATE_STORE=s3://clusters.topzone.biz

# Make ssh key
rm -Rf ~/.ssh/id_rsa*
# ssh-keygen -f ~/.ssh/id_rsa
ssh-keygen -f ~/.ssh/id_rsa -q -N ""

# Set aws env.
mkdir -p /root/.aws
cp -rf /vagrant/etc/aws/config /root/.aws
cp -rf /vagrant/etc/aws/credentials /root/.aws 	

sudo apt-get install ntpdate -y
sudo ntpdate -s time.nist.gov

sudo apt-get install jq -y
echo aws --profile default route53 list-hosted-zones | jq '.HostedZones[] | select(.Name=="topzone.biz.") | .Id' >> /vagrant/exec.log
aws --profile default route53 list-hosted-zones | jq '.HostedZones[] | select(.Name=="topzone.biz.") | .Id'

echo ############################################################### >> /vagrant/exec.log
echo # Make a master and nodes >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
# Clean up kubes !!!
echo kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz       >> /vagrant/exec.log
kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz
sleep 30

echo kops create cluster --ssh-public-key ~/.ssh/id_rsa.pub --yes \
    --name=topzone.biz --state=s3://kops-state-tz --zones=us-west-1a \
    --node-count=1 --node-size=t2.micro --master-size=t2.micro --dns-zone=topzone.biz       >> /vagrant/exec.log

kops create cluster --ssh-public-key ~/.ssh/id_rsa.pub --yes \
    --name=topzone.biz --state=s3://kops-state-tz --zones=us-west-1a \
    --node-count=1 --node-size=t2.micro --master-size=t2.micro --dns-zone=topzone.biz

#kops edit cluster topzone.biz --state=s3://kops-state-tz
echo kops update cluster topzone.biz --yes --state=s3://kops-state-tz       >> /vagrant/exec.log
kops update cluster topzone.biz --yes --state=s3://kops-state-tz  
#kops rolling-update cluster

sleep 60

echo ############################################################### >> /vagrant/exec.log
echo # Check master status >> /vagrant/exec.log
echo # ssh -i ~/.ssh/id_rsa admin@api.topzone.biz >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_master=`aws ec2 describe-instances --filters "Name=tag:Name,Values=*masters.topzone.biz" \
--query 'Reservations[*].Instances[*].[PublicIpAddress,InstanceId,State.Name,Tags[?Key==\`Name\`].Value]' \
--output text --region us-west-1 | grep running`

a_master_ip=`echo ${a_master} | awk '{print $1}'`
a_master_id=`echo ${a_master} | awk '{print $2}'`

echo "a_master_ip: ${a_master_ip}" >> /vagrant/exec.log
echo "a_master_id: ${a_master_id}" >> /vagrant/exec.log

a_sid=`aws ec2 describe-security-groups --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | grep -A 1 'masters.topzone.biz' | head -2 | tail -1 | awk '{ print $2}' | sed 's|"||g'`
echo ${a_sid} >> /vagrant/exec.log

echo aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol icmp --port -1 --cidr 0.0.0.0/0       >> /vagrant/exec.log
aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol icmp --port -1 --cidr 0.0.0.0/0

check_nw_loading "dig api.topzone.biz | grep 'api.topzone.biz.' | head -2 | tail -1 | awk '{ print \$5}'" ${a_master_ip} 400
if [ ${RTN} == 0 ]; then
		ping api.topzone.biz -c 5
		sleep 20
elif [ ${RTN} == -1 ]; then
		echo kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz       >> /vagrant/exec.log
		kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz
		exit -1
fi

echo kubectl get node       >> /vagrant/exec.log
kubectl get node       

echo ############################################################### >> /vagrant/exec.log
echo # Check master >> /vagrant/exec.log
echo # ssh -i ~/.ssh/id_rsa admin@api.topzone.biz >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # **** Run a service with a pod and a ELB >> /vagrant/exec.log
echo # 1. Create Service with pod >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
cd /vagrant/libs
echo cd /vagrant/libs >> /vagrant/exec.log

echo kubectl delete -f mysql/db-secrets.yml       >> /vagrant/exec.log
kubectl delete -f mysql/db-secrets.yml
echo kubectl create -f mysql/db-secrets.yml       >> /vagrant/exec.log
kubectl create -f mysql/db-secrets.yml
echo kubectl get secret        >> /vagrant/exec.log
kubectl get secret 

echo kubectl create -f app-elb/tzapp.yml       >> /vagrant/exec.log
kubectl create -f app-elb/tzapp.yml      
#kubectl delete -f app-elb/tzapp.yml
echo kubectl get pod       >> /vagrant/exec.log
kubectl get pod    
   
#watch -n1 kubectl get pods
echo kubectl describe pod node-tzapp.topzone.biz       >> /vagrant/exec.log
kubectl describe pod node-tzapp.topzone.biz      

check_nw_loading "kubectl describe pod node-tzapp.topzone.biz | grep 'Status:' | awk '{ print \$2}'" "Running" 100
if [ ${RTN} == 0 ]; then
		sleep 10
elif [ ${RTN} == -1 ]; then
		echo kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz       >> /vagrant/exec.log
		kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz
		exit -1
fi

# Test the service with 8081
#kubectl port-forward node-tzapp.topzone.biz 8081:3000
# curl http://localhost:8081

echo ############################################################### >> /vagrant/exec.log
echo # 2. Deploy Service to aws >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
echo kubectl expose pod node-tzapp.topzone.biz --type=NodePort --name=node-tzapp-service       >> /vagrant/exec.log
kubectl expose pod node-tzapp.topzone.biz --type=NodePort --name=node-tzapp-service
#kubectl describe pod node-tzapp.topzone.biz | grep Liveness

echo kubectl create -f app-elb/tzapp-service.yml       >> /vagrant/exec.log
kubectl create -f app-elb/tzapp-service.yml
sleep 60

echo ############################################################### >> /vagrant/exec.log
echo # 3. Get Service port >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
kubectl get service       >> /vagrant/exec.log
a_port=`kubectl get service | grep 'LoadBalancer' | grep 'tzapp-service' | head -2 | tail -1 | awk '{ print $5}'`
in1=`expr index $a_port ":"`; in2=`expr index $a_port "/"`; in2=`expr $in2 - $in1 - 1` 
a_port=${a_port:$in1:$in2}
echo ${a_port} >> /vagrant/exec.log
#kubectl describe service node-tzapp-service

echo ############################################################### >> /vagrant/exec.log
echo # 4. Get ELB IDs >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_elb=`kubectl describe service tzapp-service | grep 'LoadBalancer Ingress' | awk '{ print $3}'`
in1=`expr index $a_elb "-"`;  in1=`expr $in1 - 1`;  a_elb=${a_elb:0:$in1}
echo "a_elb: "${a_elb} >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # 5. Get working EC2 IPs >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
a_ec2=`aws elb describe-instance-health --region us-west-1 --load-balancer-name ${a_elb} | grep '"InstanceId":' | awk '{ print $2}'`
echo ${a_ec2} >> /vagrant/exec.log
a_sid=`aws ec2 describe-security-groups --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | grep -A 1 'nodes.topzone.biz' | head -2 | tail -1 | awk '{ print $2}' | sed 's|"||g'`
echo ${a_sid} >> /vagrant/exec.log

while IFS= read -r ec2_id; do
    #echo "$ec2_id"
    ec2_id=$(echo $ec2_id | sed 's|,||g' | sed 's|"||g')
    a_ec2_ip=`aws ec2 describe-instances --region us-west-1 --instance-ids ${ec2_id} | grep '"PublicIp"' | head -2 | tail -1 | awk '{ print $2}' | sed 's|,||g' | sed 's|"||g'`
    echo ""
    echo ""
	echo "Added a port, ${a_port} on ES2 ${a_ec2_ip}'s firewall!!!"
	echo aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol tcp --port ${a_port} --cidr 0.0.0.0/0       >> /vagrant/exec.log
	aws ec2 authorize-security-group-ingress --group-id ${a_sid} --protocol tcp --port ${a_port} --cidr 0.0.0.0/0
    echo "curl http://${a_ec2_ip}:${a_port}" >> /vagrant/exec.log
    echo ""
    echo ""
done <<< "${a_ec2}"

#kubectl config get-contexts
#kubectl expose pod node-tzapp.topzone.biz --port=444 --name=frontend
#kubectl attach node-tzapp.topzone.biz
#kubectl run -i --tty busybox --image=busybox --restart=Never -- sh
#kubectl exec node-tzapp.topzone.biz -- ls -al
#kubectl label pods node-tzapp.topzone.biz mylabel=awesome

#curl http://tzapp.topzone.biz
echo kubectl cluster-info >> /vagrant/exec.log

echo ############################################################### >> /vagrant/exec.log
echo # 6. Make a HTTP listener for elb >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
echo aws elb create-load-balancer-listeners --load-balancer-name ${a_elb} --listeners "Protocol=TCP,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=${a_port}"       >> /vagrant/exec.log
aws elb create-load-balancer-listeners --load-balancer-name ${a_elb} --listeners "Protocol=TCP,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=${a_port}"

echo ############################################################### >> /vagrant/exec.log
echo # 7. Make test domain using elb  >> /vagrant/exec.log
echo ############################################################### >> /vagrant/exec.log
# a_elb="a15a539880d6911e991be02e1a8cce97"
a_elb2=`aws elb describe-load-balancers --load-balancer-name ${a_elb} --output text | head -n 1`
a_alias_zone_id=`echo ${a_elb2} | awk '{ print $3}'`
a_dns_name=`echo ${a_elb2} | awk '{ print $2}'`
echo "a_alias_zone_id: "${a_alias_zone_id}
echo "a_dns_name: "${a_dns_name}

a_hosted_zone_id=`aws route53 list-hosted-zones --output text | grep topzone.biz| awk '{ print $3}'`
echo ${a_hosted_zone_id}
#change_batch="{\"Changes\":[{\"Action\":\"CREATE\",\"ResourceRecordSet\":{\"Name\":\"test.topzone.biz\",\"Type\":\"A\",\"TTL\":60,\"ResourceRecords\":[{\"Value\":\"dualstack.abe48a4c79cbf11e8a146029f66f9273-1075833232.us-west-1.elb.amazonaws.com\"}]}}]}"

change_batch="{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":{\"Name\":\"test.topzone.biz\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"${a_alias_zone_id}\",\"DNSName\":\"dualstack.${a_dns_name}\",\"EvaluateTargetHealth\":false}}}]}"
echo aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch}       >> /vagrant/exec.log
aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch}

sleep 10

change_batch="{\"Changes\":[{\"Action\":\"CREATE\",\"ResourceRecordSet\":{\"Name\":\"test.topzone.biz\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"${a_alias_zone_id}\",\"DNSName\":\"dualstack.${a_dns_name}\",\"EvaluateTargetHealth\":false}}}]}"
echo aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch}       >> /vagrant/exec.log
aws route53 change-resource-record-sets --hosted-zone-id "${a_hosted_zone_id}" --change-batch ${change_batch}

echo aws route53 list-resource-record-sets --hosted-zone-id ""${a_hosted_zone_id}" --query "ResourceRecordSets[?Name == 'test.topzone.biz.']"       >> /vagrant/exec.log
aws route53 list-resource-record-sets --hosted-zone-id ""${a_hosted_zone_id}" --query "ResourceRecordSets[?Name == 'test.topzone.biz.']"

#dig a4df4582c0d6b11e991c70281dca20bc-1812966068.us-west-1.elb.amazonaws.com | grep a4df4582c0d6b11e991c70281dca20bc-1812966068.us-west-1.elb.amazonaws.com. | head -2 | tail -1 | awk '{ print $5}'
a_elb_ip=`dig ${a_dns_name} | grep ${a_dns_name}. | head -2 | tail -1 | awk '{ print $5}'`
echo "a_elb_ip: "${a_elb_ip}

check_nw_loading "dig test.topzone.biz | grep 'test.topzone.biz.' | head -2 | tail -1 | awk '{ print \$5}'" ${a_elb_ip} 100
if [ ${RTN} == 0 ]; then
		ping test.topzone.biz -c 5
		sleep 20
elif [ ${RTN} == -1 ]; then
		echo kops delete cluster --name topzone.biz --yes --state=s3://kops-state-tz       >> /vagrant/exec.log
		exit -1
fi

echo curl http://test.topzone.biz >> /vagrant/exec.log 

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

kubectl delete pod node-tzapp.topzone.biz
#kubectl delete svc node-tzapp-service

#kubectl delete svc node-tzapp-service
#kubectl expose pod tzapp-kubernetes-56fd99dc9-8gc9f --type=NodePort --name=node-tzapp-service



