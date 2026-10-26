FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bash ca-certificates curl git openssh-client rsync openssl && rm -rf /var/lib/apt/lists/*
RUN git config --global --add safe.directory /workspace
WORKDIR /workspace
