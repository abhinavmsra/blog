---
title: "Multistage Docker Builds"
date: 2021-08-21T20:33:47+07:00
draft: true
---

So recently I was working on a relatively small Golang microservice. It consumed ZeroMQ streams, performed some calculations on the timeseries data & exposed standarized data via a web API.

I used [goczmq](https://github.com/zeromq/goczmq) as a golang interface to the CZMQ API.
Looking at the [cgo tags](https://github.com/zeromq/goczmq/blob/master/goczmq.go#L17), `goczmq` depends on following libraries.
  - [libczmq](https://github.com/zeromq/czmq)
  - [libzmq](https://github.com/zeromq/libzmq)
  - [libsodium](https://github.com/jedisct1/libsodium)

These are all the dependencies I needed for my app. Hence, my initial `Dockerfile` was relatively straightforward.

{{<code>}}
FROM golang:1.16 as base
RUN apt-get update -qq && \
    apt-get install -qq --yes --no-install-recommends \
      build-essential \
      libczmq-dev \
      libzmq3-dev \
      libsodium-dev
WORKDIR /go/src/app
COPY . .
RUN go get -d -v ./... 
RUN go install -v ./...
CMD ["app"]
{{</code>}}

While it did the job, the resulting docker image was huge (~1.4GB). The compressed docker image was too around ~500MB. It seemed quite a lot, when the app itself had only 2 package dependencies.

`go.mod`
{{<code>}}
require (
  github.com/sirupsen/logrus v1.8.1
  github.com/zeromq/goczmq v0.0.0-20190622112907-4715d4da6d4b
)
{{</code>}}

{{<note>}}
Wonder why I am using a commit hash for goczmq.
It's a whole other story which I intend to write about in a separate blog.
{{</note>}}

Certainly, it was not ideal. 

To tackle this, I switched to a multistage build approach. The idea was to:
1. use `golang` docker image to prepare the final build.
2. throw that build on a lightweight base image (_`debian:buster-slim`_ in this case) for final execution.

With this approach, my final `Dockerfile` looked as follows:

{{<code>}}
# syntax=docker/dockerfile:1

FROM golang:1.16 as base
RUN apt-get update -qq && \
  apt-get install -qq --yes --no-install-recommends \
    build-essential \
    libczmq-dev \
    libzmq3-dev \
    libsodium-dev

WORKDIR /go/src/app
COPY . .
RUN go get -d -v ./...
RUN go build -o app ./... 

# ---- Release ----
FROM debian:buster-slim AS release
RUN apt-get update -qq && \
  apt-get install -qq --yes --no-install-recommends libczmq-dev
COPY --from=build /go/src/app/app ./
CMD ["./app"]
{{</code>}}

The image final size came down to 137MB with compressed size of ~40MB.