FROM node:16-bullseye-slim AS ui-build

WORKDIR /app

COPY package*.json ./
COPY ui/package*.json ./ui/

RUN npm ci
RUN npm install --prefix ui

COPY . .
RUN npm run build

FROM node:16-bullseye-slim AS runtime

ENV NODE_ENV=production

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates ffmpeg tini \
  && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev \
  && npm cache clean --force

COPY --from=ui-build /app/interface ./interface
COPY bin ./bin
COPY src ./src

RUN mkdir -p /data \
  && chown -R node:node /app /data

USER node

VOLUME ["/data"]
EXPOSE 8081 7272 2727 5050

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8081/version', (res) => process.exit(res.statusCode < 500 ? 0 : 1)).on('error', () => process.exit(1))"

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "bin/camera.ui.js", "--no-sudo", "--no-global", "-S", "/data"]
