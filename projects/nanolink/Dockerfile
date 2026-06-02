FROM node:20-slim

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./
RUN npm ci

COPY backend/tsconfig.json ./
COPY backend/src ./src

RUN npm run build

ENV NODE_ENV=production
EXPOSE 8080

CMD ["node", "dist/index.js"]
