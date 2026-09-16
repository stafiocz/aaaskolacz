FROM nginx:stable-alpine@sha256:9874b7a098bbd4e9454941c9e3f87600d7a6e2bb081a06f453202933fe7520d1

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web/ /usr/share/nginx/html/

EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
