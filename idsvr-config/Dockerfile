 #
 #  Copyright 2024 Curity AB
 #
 #  Licensed under the Apache License, Version 2.0 (the "License");
 #  you may not use this file except in compliance with the License.
 #  You may obtain a copy of the License at
 #
 #  http://www.apache.org/licenses/LICENSE-2.0
 #
 #  Unless required by applicable law or agreed to in writing, software
 #  distributed under the License is distributed on an "AS IS" BASIS,
 #  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 #  See the License for the specific language governing permissions and
 #  limitations under the License.
 #

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
