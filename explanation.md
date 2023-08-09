#Choice of the base image on which to build each container.
The application is built on react which can be run within the Node.js runtime hence my choice of the container i.e node:19-alpine3.16. This image is based on the popular Alpine Linux project. Alpine Linux is much smaller than most distribution base images (~5MB), and thus leads to much slimmer images in general.
This container has the necessary node dependancies hence reducing the stages that run in the container. Had I chosen a container like Debian, I would have to add steps that allow installation of node. My choice reduces execution time.


#Dockerfile directives used in the creation and running of each container.

--------------------------------------------Client Dockerfile-------------------------------------
FROM node:19-alpine3.16 as builder

ENV NODE_OPTIONS=--openssl-legacy-provider     
- Assist clear the ERR_OSSL_EVP_UNSUPPORTED error as I am using node v19. The other option is to downgrade to node v16 or v17

RUN mkdir app
- creates a directory called app

WORKDIR /app
- defines app as the working directory

COPY . .
- copies everything to the current directory

RUN npm i

RUN npm run build
- installs npm and runs the build

#-------------------------------------------

FROM nginx:1.23.4-alpine as production

ENV NODE_ENV production

COPY --from=builder /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx","-g", "daemon off;"]

- The above lines define a production environment for the client and define the networt port





----------------------------------------------Backend dockerfile---------------------------------------------
FROM node:19-alpine3.16    
- uses this image to run the backend container 

RUN apk update             
- Updates the package list

RUN apk add nginx 
- Installs nginx         

RUN apk add supervisor
- Installs Supervisor which acts as our entry point   

COPY nginx.conf etc/nginx/http.d/default.conf
- copies the nginx.conf file to api file

COPY supervisord.conf /etc/supervisor/supervisord.conf
- copies supervisord.conf file into the specified path
- supervisord defines files with processes that run in the background
- It is responsible for starting child programs at its own invocation, responding to commands from clients, restarting crashed or exited subprocesseses, logging its subprocess stdout and stderr output defined in the supervisor.conf file, and generating and handling “events” corresponding to points in subprocess lifetimes.

COPY supervisor.conf /etc/supervisor/conf.d/supervisor.conf
- copies supervisor.conf file in the specified path
- spervisor.conf file defines 2 programs node & nginx

RUN mkdir -p /home/www/node/node_modules && chown -R node:node /home/www/node
- Creates the /home/www/node/node_modules directory and changes ownership to node. Everything under node_modules will have the node ownership.

RUN mkdir -p /var/log/supervisor && chown -R node:node /var/log/supervisor
creates the log directory and changes the ownership to node

WORKDIR /home/www/node
- Defines the working working directory 

COPY package*.json ./
- copies the package.json and package-lock.json to the current directory

RUN npm install
- installs npm

RUN npm ci --only=production

COPY --chown=node:node . ./


EXPOSE 8080
- Exposes port 8080 as the access point for the site.

CMD ["/usr/bin/supervisord","-n","-c","/etc/supervisor/supervisord.conf"]
- used supervisor as it runs forever and is a lightweight version of nodemon


#Docker-compose Networking (Application port allocation and a bridge network implementation) where necessary.
- Docker compose file contains the access ports being exposed by the container for the backend and the frontend. No bridge newtork used for this deployment.



#Docker-compose volume definition and usage (where necessary).
- Defined in the docker compose file to allow for data persistency in the add product section of the website

#Git workflow used to achieve the task.
- Forked the yolo repository to my github account
- Cloned the repository to my local repository
- integrated the repo with docker for deployment
- Pushed the changes to github.


--------------------------AWS Deployment Expanation-----------------------------------------------------------
Located in the AWS Folder:

To facilitate successful deployment on AWS CLoud. Configuration is defined in the aws_deployment.sh file.

This configuration files will guide you on the below steps:

- Creating a cluster on AWS for our deployment
   export AWS_REGION=us-east-2
   export CLUSTER_NAME=yolo-cluster

   eksctl create cluster -f cluster.json  

- In the cluster we creat the helm charts - an easier way to deploy instead of always writing yaml files
   helm repo add eks https://aws.github.io/eks-charts
   kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

   export VPC_ID=$(eksctl get cluster \
     --name $CLUSTER_NAME \
     --region $AWS_REGION \
     --output json \
     | jq -r '.[0].ResourcesVpcConfig.VpcId')


- Install a load-balancer
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --set clusterName=$CLUSTER_NAME \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID \
    --set serviceAccount.name=aws-load-balancer-controller \
    -n kube-system


- Install bitnami helm chart that will help in installation of the external DNS
   helm repo add bitnami https://charts.bitnami.com/bitnami

   helm install external-dns bitnami/external-dns \
      --set provider=aws \
      -n kube-system

- Create a namespace for our cluster
    kubectl create ns yolo


- install Mongo
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
        

- create a secret for the .env
       cd ..
        kubectl create secret -n yolo generic backend-secrets --from-env-file=.env
        cd ..
        cd client
        kubectl create secret -n yolo generic client-secrets --from-env-file=.env
        cd ../AWS

- Deploy the backend and the client which contain the below:
        - Deployment - deployment of pods
        - service - internal networking, which port will be exposed to the other containers or services
        - ingress - internet facing configuration

        kubectl apply -n yolo -f yolo-backend.yaml
        kubectl apply -n yolo -f yolo-client.yaml

- Expose the ports
        kubectl expose deployment client --type=LoadBalancer --port=80 --target-port=80 --name=client -n yolo
               
- Stateful sets implemented using the statefulset.yaml configuration to allow for persistent storage in mongo db


To note:
For all permission denied errors, please login to the IAM on the cloud console, for your specified user add inline permissions for the services you require or the already defined permissions