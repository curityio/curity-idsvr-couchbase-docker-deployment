# Get the Curity latest base image
FROM curity.azurecr.io/curity/idsvr:9.0.0

# Copy the license to load at startup
COPY license.json /opt/idsvr/etc/init/license/

# Copy idsvr custom config 
COPY *.xml /opt/idsvr/etc/init/

# Copy couchbase datasource plugin
COPY lib /opt/idsvr/usr/share/plugins/couchbase

# Extra tools - for development troubleshooting only
USER root
RUN apt-get update && \
    apt-get install -y iputils-ping telnet curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
USER idsvr
