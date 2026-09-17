FROM node:24-alpine@sha256:50c8e8ca1d27439048670df5883f32d57cf81cff6233222c893fd0d9884cbd81

WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server/*.js server/schema.sql ./
COPY server/public/ ./public/
COPY build/web/ /app/web/
ENV NODE_ENV=production WEB_ROOT=/app/web PORT=8080
USER node

EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=75s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
CMD ["node", "main.js"]
