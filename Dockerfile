FROM node:16-alpine

WORKDIR /app

COPY package.json ./
RUN npm install

COPY app.js ./
RUN mkdir -p public
COPY index.html ./public/

EXPOSE 80
CMD ["node", "app.js"]