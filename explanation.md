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
