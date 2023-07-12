export AWS_REGION=us-east-2
export CLUSTER_NAME=yolo-cluster

eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --version 1.22 \
  --with-oidc \
  --alb-ingress-access \
  --external-dns-access \
  --node-type t3.medium \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 1 \
  --managed

helm repo add eks https://aws.github.io/eks-charts
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

export VPC_ID=$(eksctl get cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --output json \
  | jq -r '.[0].ResourcesVpcConfig.VpcId')

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$CLUSTER_NAME \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system

helm repo add bitnami https://charts.bitnami.com/bitnami

helm install external-dns bitnami/external-dns \
  --set provider=aws \
  -n kube-system

# create dedicated namespace for our deployments
kubectl create ns yolo


# deploy mongo db cluster with stateful set
kubectl apply -n churpy  -f ./mongo/storage-class.yaml
kubectl patch storageclass sc-gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl apply -n churpy  -f ./mongo/services.yaml
kubectl apply -n churpy -f ./mongo/rbac.yaml
kubectl apply -n churpy -f ./mongo/mongo-statefulset.yaml
kubectl apply -n churpy -f ./mongo/lb-service.yaml

kubectl create secret -n yolo generic backend-secrets --from-env-file=.env

# deploy yolo backend cluster
kubectl apply -n churpy -f yolo-backend.yaml

# deploy yolo client cluster
kubectl apply -n churpy -f yolo-client.yaml