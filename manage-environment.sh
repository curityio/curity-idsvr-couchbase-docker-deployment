#!/bin/bash

 #  Copyright 2024 Curity AB
 #
 #  Licensed under the Apache License, Version 2.0 (the "License");
 #  you may not use this file except in compliance with the License.
 #  You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 #  Unless required by applicable law or agreed to in writing, software
 #  distributed under the License is distributed on an "AS IS" BASIS,
 #  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 #  See the License for the specific language governing permissions and
 #  limitations under the License.
 
##########################################################################################################################
# A script to manage a docker compose based curity identity server installation including an external couchbase database
##########################################################################################################################

set -eo pipefail

cp ./hooks/pre-commit ./.git/hooks

display_help() {
  echo -e "Usage: $(basename "$0") [-h | --help] [-i | --install] [--start] [--stop]  [-d | --delete] [-b | --backup] \n" >&2
  echo "** DESCRIPTION **"
  echo -e "This script can be used to manage a docker compose based curity identity server installation including an external couchbase database. \n"
  echo -e "OPTIONS \n"
  echo " --help      show this help message and exit                                                  "
  echo " --install   installs the Curity Identity Server environment                                  "
  echo " --start     starts the Curity Identity Server environment                                    "
  echo " --stop      stops the Curity Identity Server environment                                     "
  echo " --delete    deletes the docker compose environment                                           "
  echo " --backup    backup Curity Identity Server configuration                                      "
}

startup_message() {
  echo "|------------------------------------------------------------------|"
  echo "|  Docker compose based Curity Identity Server Installation        |"
  echo "|------------------------------------------------------------------|"
  echo "| Following components are going to be installed :                 |"
  echo "|------------------------------------------------------------------|"
  echo "| [1] NGINX REVERSE PROXY                                          |"
  echo "| [2] CURITY IDENTITY SERVER ADMIN NODE                            |"
  echo "| [3] CURITY IDENTITY SERVER RUNTIME NODE                          |"
  echo "| [4] COUCHBASE DATABASE                                           |"
  echo "| [5] COUCHBASE DATASOURCE PLUGIN                                  |"
  echo "|------------------------------------------------------------------|"
  echo -e "\n"
}

pre_requisites_check() {
  # Verify docker & docker-compose installation
  if ! [[ $(docker --version) && $(docker-compose --version) ]]; then
    echo "Error: Please install docker and docker-compose to continue with the deployment .."
    exit 1
  fi

  # Verify Java version is 17 since the couchbase datasource plugin expects JAVA 17
  if command -v java &>/dev/null; then
    # Get the Java version
    java_version=$(JAVA -version 2>&1 | sed -E -n 's/.* version "([^.-]*).*"/\1/p' | cut -d' ' -f1)

    # Check if the Java version is 17
    if [[ "$java_version" != "21" ]]; then
      echo "Error: Java 21 is required to package the couchbase data source plugin"
      echo "Current Java major version set is : $java_version"
      exit 1
    fi
  else
    echo "Error: Java is not installed or 'java' command is not in the PATH."
    exit 1
  fi

  # Verify license file availability
  if [ ! -f './idsvr-config/license.json' ]; then
    echo "Error: Please copy a license.json file in the idsvr-config directory to continue with the deployment. License could be downloaded from https://developer.curity.io/"
    exit 1
  fi
}

is_pki_already_available() {
  echo -e "Verifying whether self-signed certificates are already available .."
  if [[ -f ./certs/curity.local.ssl.key && -f ./certs/curity.local.ssl.pem ]]; then
    echo -e "curity.local.ssl.key & curity.local.ssl.pem certificates already exist.., skipping regeneration of certificates\n"
    true
  else
    echo -e "curity.local.ssl.key & curity.local.ssl.pem certificates are not available, going to be generated..\n"
    false
  fi
}

generate_self_signed_certificates() {
  if ! is_pki_already_available; then
    echo -e "Generating necessary self-signed certificates for secure communication ..\n"
    bash ./create-self-signed-certs.sh
  fi
}

package_couchbase_datasource_plugin() {
  echo -e "Running ./gradlew createPluginDir in 'couchbase-data-access-provider' directory\n"
  cd couchbase-data-access-provider
  ./gradlew createPluginDir
  cp -r build/curity-couchbase-plugin ../idsvr-config/lib
  cd ..
}

build_environment() {
  echo -e "Building docker images and bringing up the environment ...\n"
  # Build & start the environment
  docker-compose up --build -d
  echo -e "\n"
}

start_environment() {
  echo -e "Starting the environment ...\n"
  docker-compose start
  docker-compose ps
}

stop_environment() {
  echo -e "Stopping the environment ...\n"
  docker-compose stop
}

idsvr_backup() {
  # Create backups directory to hold backup xml files
  mkdir -p backups

  if [[ "$(docker ps -q -f status=running -f name=curity-idsvr-admin)" ]]; then
    backup_file_name="server-config-backup-$(date +"%Y-%m-%d-%H-%M-%S").xml"
    echo "Backing up server configuration in to a file named => $backup_file_name"

    docker exec curity-idsvr-admin idsvr -d >./backups/"$backup_file_name"
    echo "Backup completed and stored in a file => ./backups/$backup_file_name "
  else
    echo "Backup couldn't be taken since the 'curity-idsvr-admin' container is not running.."
  fi

}

tear_down_environment() {
  read -p "containers & images would be deleted, Are you sure ? [Y/y N/n] :" -n 1 -r
  echo -e "\n"

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Take backup before deletion if the containers are running
    idsvr_backup || true
    echo -e "\n"
    docker-compose down --rmi all || true
  else
    echo "Aborting the operation .."
    exit 1
  fi
}

environment_info() {
  echo "Environment Installation Status :"
  echo -e "\n"
  docker-compose ps
  echo -e "\n\n"

  echo "|-------------------------------------------------------------------------------------------------------|"
  echo "|                                Environment URLS & Endpoints                                           |"
  echo "|-------------------------------------------------------------------------------------------------------|"
  echo "|                                                                                                       |"
  echo "| [ADMIN UI]          https://admin.curity.local/admin                                                  |"
  echo "| [OIDC METADATA]     https://login.curity.local/~/.well-known/openid-configuration                     |"
  echo "| [COUCHBASE DB UI]   http://localhost:8091/ui/index.html                                               |"
  echo "|                                                                                                       |"
  echo "| * Curity administrator username is 'admin' and password is 'password1'                                  |"
  echo "| * Remember to add certs/curity.local.ca.pem to operating systems certificate trust store  &           |"
  echo "|   127.0.0.1  admin.curity.local login.curity.local entry to /etc/hosts                                |"
  echo "|-------------------------------------------------------------------------------------------------------|"
  echo -e "\n"
}

# ==========
# entrypoint
# ==========

case $1 in
-i | --install)
  startup_message
  pre_requisites_check
  generate_self_signed_certificates
  package_couchbase_datasource_plugin
  build_environment
  environment_info
  ;;
--start)
  start_environment
  ;;
--stop)
  stop_environment
  ;;
-d | --delete)
  tear_down_environment
  ;;
-b | --backup)
  idsvr_backup
  ;;
-h | --help)
  display_help
  ;;
*)
  echo "[ERROR] Unsupported options"
  display_help
  exit 1
  ;;
esac
