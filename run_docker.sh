#!/bin/bash

image=ghcr.io/jungoai/rpc-gateway:latest

docker pull $image

docker run \
    --name          "rpc-gateway" \
    --network       host \
    -v              "$HOME/.rpc-gateway.json:/root/.rpc-gateway.json" \
    --log-driver    json-file       \
    --log-opt       max-size="10m"  \
    --log-opt       max-file=10     \
    -d \
    $image

