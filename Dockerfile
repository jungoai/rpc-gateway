FROM haskell:9.6.5 AS builder

WORKDIR /app

COPY stack.yaml stack.yaml
COPY package.yaml package.yaml
COPY src src
COPY app app
COPY README.md README.md
COPY test test

RUN stack setup && stack build --dependencies-only

RUN stack build
RUN stack install

FROM ubuntu:24.04

WORKDIR /app

COPY --from=builder /root/.local/bin/* /app/

ENV LOG_LEVEL="info"

CMD ["./rpc-gateway-exec"]
