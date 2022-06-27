## OpenVPN client to authenticate to `AWS Client VPN` via SAML

### About ###

* [Docker image](https://hub.docker.com/repository/docker/tilsonbiz/aws-clientvpn) of [OpenVPN client](https://openvpn.net) to connect to [AWS Client VPN endpoint](https://aws.amazon.com/vpn/client-vpn/) via SAML 2.0 protocol using various IdPs for authentication and authorization in unattended way
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

``` bash
user@docker$ export SAML_USER="username"
user@docker$ export SAML_PASS="password"
user@docker$ docker run \
  -d \
  --rm \
  -e SAML_USER=$SAML_USER \
  -e SAML_PASS=$SAML_PASS \
  -v"$(pwd)/aws-client-vpn.ovpn":"/app/ovpn.conf" \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --name clientvpn \
  tilsonbiz/aws-clientvpn
```
