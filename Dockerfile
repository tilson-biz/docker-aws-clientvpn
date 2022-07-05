# build openvpn with patched buffer sizes
# build saml2aws
FROM ubuntu:22.04 as build

ARG OVPN_VER=2.5.7
COPY openvpn-${OVPN_VER}-aws.patch /app/
WORKDIR /app

RUN apt-get update -y \
 && apt-get install patch make curl gcc liblzo2-dev liblz4-dev libssl-dev openssl -y \
 && curl -LO https://swupdate.openvpn.org/community/releases/openvpn-${OVPN_VER}.tar.gz \
 && tar -zxf openvpn-${OVPN_VER}.tar.gz \
 && cd openvpn-${OVPN_VER} \
 && cat /app/openvpn-${OVPN_VER}-aws.patch | patch -f -p 1 \
 # possible flags : ./configure IFCONFIG=/sbin/ifconfig ROUTE=/sbin/route NETSTAT=/bin/netstat IPROUTE=/sbin/ip --enable-iproute2
 && ./configure --enable-static --disable-shared --disable-debug --disable-plugins \
      OPENSSL_CFLAGS="-I/usr/include" OPENSSL_LIBS="-L/usr/lib -lssl -lcrypto" \
      LZO_CFLAGS="-I/usr/include" LZO_LIBS="-L/usr/lib -llzo2" \
      LZ4_CFLAGS="-I/usr/include" LZ4_LIBS="-L/usr/lib -llz4" \
 && make LIBS="-all-static" \
 && make install \
 && strip /usr/local/sbin/openvpn \
 && cd .. \
 && mkdir -p etc/openvpn \
 && cp openvpn-${OVPN_VER}/contrib/pull-resolv-conf/client.* etc/openvpn/ \
 && sed -i -e 's#cp /etc/resolv.conf.ovpnsave /etc/resolv.conf.*#cat /etc/resolv.conf.ovpnsave > /etc/resolv.conf#' etc/openvpn/client.down \
 && chmod +x etc/openvpn/client.* \
 && SAML2AWS_VERSION=$(curl -Ls https://api.github.com/repos/Versent/saml2aws/releases/latest | grep 'tag_name' | cut -d"\"" -f4 | sed -e 's/v//') \
 && curl -LO https://github.com/Versent/saml2aws/releases/download/v${SAML2AWS_VERSION}/saml2aws_${SAML2AWS_VERSION}_linux_amd64.tar.gz \
 && tar -xzvf saml2aws_${SAML2AWS_VERSION}_linux_amd64.tar.gz -C /usr/local/bin \
 && chmod u+x /usr/local/bin/saml2aws


FROM alpine:3.16.0

ARG OVPN_CONF=./ovpn.conf
ENV OVPN_CONF=$OVPN_CONF

ARG RESP_FILE=./resp.txt
ENV RESP_FILE=$RESP_FILE

WORKDIR /app
RUN apk add --no-cache --update aws-cli bash bind-tools ca-certificates curl openssl shadow shadow-login tini tzdata \
 && echo "alias ll='ls -la'" >> ~/.bashrc \
 && addgroup -S vpn \
 && rm -rf /var/cache/apk/* /tmp/*

COPY --from=build /usr/local/sbin/openvpn /usr/local/sbin/openvpn
COPY --from=build /app/etc/openvpn /etc/openvpn
RUN echo -e "openvpn version:\n" && openvpn --version

COPY --from=build /usr/local/bin/saml2aws /usr/local/bin/saml2aws
RUN echo -e "saml2aws version:\n" && saml2aws --version

RUN echo -e "aws-cli version:\n" && aws --version

COPY README.md ./
COPY /scripts ./

HEALTHCHECK \
  --interval=60s \
  --timeout=15s \
  --start-period=120s \
  CMD curl -LSs 'https://api.ipify.org'

ENTRYPOINT ["/sbin/tini", "--", "/app/connect"]
