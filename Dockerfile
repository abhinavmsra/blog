FROM golang:1.22.6

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        git \
        hugo

WORKDIR /app
