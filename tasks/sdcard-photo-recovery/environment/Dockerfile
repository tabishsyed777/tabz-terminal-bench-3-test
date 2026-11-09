FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pil python3-numpy xxd && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY card.img /app/card.img
