## OpenVPN client to authenticate to `AWS Client VPN` via SAML

### About ###

* [Docker image](https://hub.docker.com/r/tilsonbiz/aws-clientvpn) of [OpenVPN client](https://openvpn.net) to connect to [AWS Client VPN endpoint](https://aws.amazon.com/vpn/client-vpn/) via SAML 2.0 protocol using various IdPs for authentication and authorization in unattended way
* To authenticate to IdP via SAML the corresponding `username` and `password` to be provided to the running container as command line parameters (or environment variables)
* OpenVPN client configuration file for `AWS Client VPN endpoint` to be provided to the running container as mount volume

### Note ###

* The main idea is based on [samm-git/aws-vpn-client](https://github.com/samm-git/aws-vpn-client), with respect to [samm-git](https://github.com/samm-git)
* [Versent/saml2aws](https://github.com/Versent/saml2aws) is used to get SAML Asseesment response, with respect to [Versent](https://github.com/Versent)
* Docker image for OpenVPN client is based on [dperson/openvpn-client](https://github.com/dperson/openvpn-client), with respect to [dperson](https://github.com/dperson)
* For [URL Encoding](https://gist.github.com/cdown/1163649) thanks to [cdown](https://github.com/cdown)
* SAML dissection was performed in [mtilson/clientvpn-with-saml](https://github.com/mtilson/clientvpn-with-saml)
* `aws-cli/v1` is available as [Alpine package](https://pkgs.alpinelinux.org/package/edge/community/x86/aws-cli)

### Minimun requirements ###

* An **Identity provider** to be **chosen** and configured as SAML assessor for **registered users** in a **registered group**
* The corresponding **AWS IAM SAML identity provider** to be created and integrated with the **Chosen identity provider**
* **`AWS Client VPN endpoint`** to be created and configured to *Use user-based authentication* -> *Federated authentication* and choosing ARN of the configured **AWS IAM SAML identity provider** as *SAML provider ARN*
* **Authorization rules** to be added to the created **`AWS Client VPN endpoint`** with *Grant access to* -> *Allow access to users in a specific access group* with specifying *Access group ID* as the name of the **registered group** from the **Choosen identity provider**

### Usage ###

* Suppose we would like to run docker container from image `other/docker-image:v1` which should have access to some external resources/services via connection to `AWS Client VPN endpoint` for which we have downloaded and saved configuration file `~/Downloads/downloaded-client-config.ovpn` and set up `username` and `password` in an **Identity provider** integrated with the endpoint via SAML

#### Pure `docker` ####

``` bash
user@docker$ export SAML_USER="username"
user@docker$ export SAML_PASS="password"
user@docker$ cp ~/Downloads/downloaded-client-config.ovpn ./
user@docker$ docker run \
  -d \
  --rm \
  -e SAML_USER=$SAML_USER \
  -e SAML_PASS=$SAML_PASS \
  -v"$(pwd)/downloaded-client-config.ovpn":"/app/ovpn.conf" \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --name clientvpn \
  tilsonbiz/aws-clientvpn

user@docker$ docker run -d -it --net=container:clientvpn other/docker-image:v1
```

#### `docker compose` ####

##### Procedure #####

> **NOTE**: There should be compose file for an **existing_service** which needs to access some external resources/services via connection to `AWS Client VPN endpoint`

* Create a working directory (e.g. `vpn`)
* Place variables for SAML `username`/`password` into `.env` file in the working directory
* Copy **OpenVPN client configuration file for `AWS Client VPN endpoint`** into the working directory
* Copy compose file for the **existing_service** into the working directory as either `compose.yaml` or `docker-compose.yaml`
* Add the following service (e.g. `vpn`) in the compose file
```
services:
  vpn:
    image: tilsonbiz/aws-clientvpn
    cap_add:
      - net_admin
    volumes:
      - /dev/net:/dev/net:z
      - ./downloaded-client-config.ovpn:/app/ovpn.conf
```
* Add the following changes to the to the **existing_service** in the compose file
```
services:
  existing_service:
    depends_on:
      - vpn
    network_mode: "service:vpn"
```
* Use `docker compose run` command to run containers

##### Example #####

* Create and change to the working directory

```bash
user@docker$ mkdir vpn
user@docker$ cd vpn
```

* Place variables for SAML `username`/`password` into `.env` file in the working directory

```bash
user@docker$ cat > /.env << _EOF
SAML_USER="username"
SAML_PASS="password"
_EOF
```

* Copy **OpenVPN client configuration file for `AWS Client VPN endpoint`** into the working directory

```bash
user@docker$ cp ~/Downloads/downloaded-client-config.ovpn ./
```

* Copy compose file for the **existing_service** into the working directory as either `compose.yaml` or `docker-compose.yaml` and make corresponding changes

```bash
user@docker$ cat docker-compose.yaml
version: '3.4'

services:
  vpn:
    image: tilsonbiz/aws-clientvpn
    cap_add:
      - net_admin
    volumes:
      - /dev/net:/dev/net:z
      - ./downloaded-client-config.ovpn:/app/ovpn.conf
    environment:
      TZ: 'UTC'
    networks:
      - default
    tmpfs:
      - /run
      - /tmp
    restart: unless-stopped
    security_opt:
      - label:disable
    stdin_open: true
    tty: true

  existing_service:
    image: other/docker-image
    depends_on:
      - vpn
    network_mode: "service:vpn"
    environment:
      TZ: 'UTC'
    restart: unless-stopped
    stdin_open: true
    tty: true
 
networks:
  default:
```

* Run containers

```bash
docker compose run -d existing_service
```

### TODO ###

* Pass arguments to `getauth` script by creating a file to `source` it within script - this will avoid printing `useername`, `password` in container log
* Add GitHub Action pipeline to build and publish dockeer image (by tagging integration branch) to ghcr.io (and docker hub)
* `aws cli` is not used here, it is probably possible to patch `saml2aws` to build image without `aws-cli` alpne package
