FROM nginx:alpine

# if using Istio with mTLS, we need to use curl to run the probe
# ref: https://github.com/istio/istio/issues/1194
RUN apk --no-cache add curl

COPY default.conf /etc/nginx/conf.d/default.conf
