# An example Dockerfile for installing Git on debian
FROM debian:latest
LABEL maintainer="mwanashifa.tima@gmail.com"
RUN apt-get update && apt-get install -y git
ENTRYPOINT ["git"]
RUN This will not work