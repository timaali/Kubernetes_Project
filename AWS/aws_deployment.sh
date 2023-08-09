#create a cluster
export AWS_REGION=us-east-2
export CLUSTER_NAME=yolo-cluster

eksctl create cluster -f cluster.json

#create the helm chart in the cluster
helm repo add eks https://aws.github.io/eks-charts
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

export VPC_ID=$(eksctl get cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --output json \
  | jq -r '.[0].ResourcesVpcConfig.VpcId')

# install the load balancer
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$CLUSTER_NAME \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system

#install bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install external-dns bitnami/external-dns \
  --set provider=aws \
  -n kube-system

# create dedicated namespace for our deployments
kubectl create ns yolo


# deploy mongo db cluster with stateful set
cd mongo
export AWS_REGION=us-east-2
eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=yolo-cluster --approve
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster yolo-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole
eksctl create addon --name aws-ebs-csi-driver --cluster yolo-cluster --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole --force
kubectl apply -f pvc.yaml -n yolo

#create secret in the .env file
cd ..
kubectl create secret -n yolo generic backend-secrets --from-env-file=.env
cd ..
cd client
kubectl create secret -n yolo generic client-secrets --from-env-file=.env
cd ../AWS

# deploy yolo backend cluster
kubectl apply -n yolo -f yolo-backend.yaml

# deploy yolo client cluster
kubectl apply -n yolo -f yolo-client.yaml

#to expose the port
kubectl expose deployment client --type=LoadBalancer --port=80 --target-port=80 --name=client -n yolo