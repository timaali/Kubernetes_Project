
FROM node:19-alpine3.16 as builder

ENV NODE_OPTIONS=--openssl-legacy-provider

RUN mkdir app

WORKDIR /app

COPY . .

RUN npm i

RUN npm run build

#-------------------------------------------

