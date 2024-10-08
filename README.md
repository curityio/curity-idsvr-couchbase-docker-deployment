# Curity Identity Server Docker Deployment 

[![Quality](https://img.shields.io/badge/quality-experiment-red)](https://curity.io/resources/code-examples/status/)
[![Availability](https://img.shields.io/badge/availability-source-blue)](https://curity.io/resources/code-examples/status/)

A docker compose based Curity Identity Server installation for development purposes. It also includes an external couchbase database and deploys a couchbase datasource plugin in to the Curity Identity Server.

## Prepare the Installation

The system can be deployed on a MacOS or Windows workstation via a bash script, and has the following prerequisites:

* [Docker](https://docs.docker.com/get-docker/)
* [Docker compose](https://docs.docker.com/compose/install/)
* [OpenSSL](https://www.openssl.org/)

Please make sure you have above prerequisites installed and then copy a license file to the `idsvr-config/license.json` location.
If needed, you can also get a free community edition license from the [Curity Developer Portal](https://developer.curity.io).


## Installation

 1. Clone the repository
    ```sh
    git clone --recursive git@github.com:curityio/curity-idsvr-couchbase-docker-deployment.git
    cd curity-idsvr-couchbase-docker-deployment
    ```
    > **Note:**
    > git clone should also download a referenced submodule https://github.com/curityio/couchbase-data-access-provider.git
    
 2. Install the environment  
     ```sh
    ./manage-environment.sh --install
    ```
    
 3. Start & Stop 
    ```sh
     ./manage-environment.sh --start
     ./manage-environment.sh --stop
    ```

 4. Identity Server Backup 
    ```sh
     ./manage-environment.sh --backup
    ```

 5. Clean up
    ```sh
     ./manage-environment.sh --delete
    ```

 6. Logs
    ```sh
     docker logs -f curity-idsvr-admin
     docker logs -f curity-idsvr-runtime
    ```


```sh
   ./manage-environment.sh -h
     Usage: manage-environment.sh [-h | --help] [-i | --install] [--start] [--stop] [-d | --delete] [-b | --backup]

   ** DESCRIPTION **
   This script can be used to manage a docker compose based curity identity server installation including an external couchbase datasource.

   OPTIONS

   --help      show this help message and exit
   --install   installs the curity identity server environment
   --start     starts the curity identity server environment
   --stop      stops the curity identity server environment
   --delete    deletes the docker compose environment
   --backup    backup idsvr configuration

```

## Trust self-signed root CA certificate

Add the self signed root ca certificate (certs/curity.local.ca.pem) to operating system trust store.<br>
For mac, please refer to https://support.apple.com/guide/keychain-access/add-certificates-to-a-keychain-kyca2431/mac <br> <br>
![root ca configuration](./docs/ca-trust.png "Root ca trust configuration")

For windows, please refer to https://docs.microsoft.com/en-us/skype-sdk/sdn/articles/installing-the-trusted-root-certificate

## Host Mappings

Add following to hosts file
 ```
  127.0.0.1  admin.curity.local login.curity.local
 ```

## Use the System

After the installation is completed, you will have a fully working system:

- [OAuth and OpenID Connect Endpoints](https://login.curity.local/~/.well-known/openid-configuration) used by applications
- A rich [Admin UI](https://admin.curity.local/admin) for configuring applications and their security behavior
- [Couchbase Admin UI](http://localhost:8091/ui/index.html) for setting up and configuring a couchbase cluster

## Managing the Server Configuration

The default server configuration is stored in the `idsvr-config/server-config.xml` and it is imported in to the server during environment set up. Any updates made to the system configuration would persist identity server restarts, however if the containers are deleted then the updates are lost and system is reset to the default configuration state represented by `idsvr-config/server-config.xml`.

It is recommended take Identity Server configuration back ups when needed. Backed-up configuration could be imported in to the server either by using the Admin UI or by copying the back up configuration xml files to the `idsvr-config` directory and re-building the idsvr docker image.

## Functional test
To test the integration between Curity Identity Server and the Couchbase Data Source plugin, som OAuth/OpenID Connect
flows needs to performed. This can be done using the oauth.tools app, or any OAuth compatible application. Below are
some examples of what can quickly tested with this deployment. This is not a full list of test cases, but can be used to
assert the behavior of the plugin.

### Checkout the plugin branch
Make sure you are testing the latest changes or correct branch of the plugin. The plugin is pulled in as a submodule in this repo which might not have the changes you are testing.

```bash
cd couchbase-data-access-provider 
git checkout main
git pull origin main
cd -
./manage-environment.sh --stop
./manage-environment.sh --install
./manage-environment.sh --start
```

### Client Credentials flow
This flow will create a `Delegation` and `Token` using the Couchbase plugin

```bash
curl -k https://login.curity.local/oauth/v2/oauth-token -d 'grant_type=client_credentials&scope=read&client_id=oauth-tools&client_secret=s3cr3t'
```

### Token introspection
This flow will lookup a specific `Delegation` and `Token` using the Couchbase plugin. use the `access_token` received in
the `client_credentials`request above.
```bash
curl -k https://login.curity.local/oauth/v2/oauth-introspect -d 'client_id=oauth-tools&client_secret=s3cr3t&token=<TOKEN>'
```

### Code flow
This flow will authenticate a user in the browser, and redirect to the provided `redirect_uri` with a code, which will
have to be redeemed in the next request.

* Follow this link in a browser: https://login.curity.local/oauth/v2/oauth-authorize?scope=read&client_id=oauth-tools&response_type=code&redirect_uri=http://localhost/callback

This part tests that its possible to create and use a  `Session` and the creation of a `Nonce` using the Couchbase plugin.

* After performing the authentication (in the default config, just enter any username), the browser will redirect to
http://localhost/callback with a `code` parameter. Use the `code` parameter in the next request. The `code` is only
valid for 30 seconds in the default config.

```bash
curl -k https://login.curity.local/oauth/v2/oauth-token -d 'grant_type=authorization_code&client_id=oauth-tools&client_secret=s3cr3t&redirect_uri=http%3A%2F%2Flocalhost%2Fcallback&code=<CODE>'
```
This request will return an `access_token` and `refresh_token`, make sure both tokens are usable in the token
introspection.

This part tests that its possible to lookup a `Nonce` and the creation of a `Delegation` and `Token` using the Couchbase plugin.

### Refresh token
The `refresh_token` received in the Code flow can be used to obtain new `access_tokens`. Run this command to test it.

```bash
curl -k https://login.curity.local/oauth/v2/oauth-token -d 'grant_type=refresh_token&client_id=oauth-tools&client_secret=s3cr3t&refresh_token=<REFRESH_TOKEN>'
```
The request should return both a new `access_token` and a new `refresh_token`. Repeating the request with the old
`refresh_token` should fail, but the new `refresh_token` should succeed.

This flow tests that its possible to lookup `Token` and `Delegation` using the Couchbase plugin.

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.