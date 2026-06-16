# Base image
FROM eclipse-temurin:25.0.1_8-jdk-jammy

LABEL org.opencontainers.image.source="https://github.com/Lynnariss/Dockertale"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      wget unzip curl bash ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /hytale

COPY start.sh /usr/local/bin/hytale-start
RUN chmod +x /usr/local/bin/hytale-start

RUN wget -O hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip && \
    unzip hytale-downloader.zip && \
    rm hytale-downloader.zip && \
    mv hytale-downloader-linux-amd64 /usr/local/bin/hytale-downloader && \
    chmod +x /usr/local/bin/hytale-downloader

RUN useradd -m -d /hytale -u 1000 hytale && \
    mkdir -p /hytale/Server /hytale/backups && \
    chown -R hytale:hytale /hytale

USER hytale
WORKDIR /hytale

ENTRYPOINT ["/usr/local/bin/hytale-start"]