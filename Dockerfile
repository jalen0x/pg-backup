ARG PG_VERSION=18
FROM postgres:${PG_VERSION}
RUN apt-get update && apt-get install -y --no-install-recommends s3cmd ca-certificates curl && rm -rf /var/lib/apt/lists/*
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh
CMD ["/backup.sh"]
