FROM node:19-alpine3.16 as builder

ENV NODE_OPTIONS=--openssl-legacy-provider

RUN mkdir app

WORKDIR /app

COPY . .

RUN npm i

RUN npm run build

#-------------------------------------------

FROM nginx:1.23.4-alpine as production

ENV NODE_ENV production

COPY --from=builder /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx","-g", "daemon off;"]