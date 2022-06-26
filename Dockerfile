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
 && SAML2AWS_VERSION=$(curl -Ls https://api.github.com/repos/Versent/saml2aws/releases/latest | grep 'tag_name' | cut -d"\"" -f4 | sed -e 's/v//') \
 && curl -LO https://github.com/Versent/saml2aws/releases/download/v${SAML2AWS_VERSION}/saml2aws_${SAML2AWS_VERSION}_linux_amd64.tar.gz \
 && tar -xzvf saml2aws_${SAML2AWS_VERSION}_linux_amd64.tar.gz -C /usr/local/bin \
 && chmod u+x /usr/local/bin/saml2aws

# main stage
FROM alpine:latest
ARG EXPOSE_PORT=35001

ARG OVPN_CONF=./ovpn.conf
ENV OVPN_CONF=$OVPN_CONF

ARG RESP_FILE=./resp.txt
ENV RESP_FILE=$RESP_FILE

RUN \
    apk add --no-cache --update aws-cli bash bind-tools ca-certificates curl openssl tzdata && \
    echo "alias ll='ls -la'" >> ~/.bashrc && \
    rm -rf /var/cache/apk/*

COPY --from=build /usr/local/sbin/openvpn /usr/local/sbin/openvpn
RUN echo -e "openvpn version:\n" && openvpn --version

COPY --from=build /usr/local/bin/saml2aws /usr/local/bin/saml2aws
RUN echo -e "saml2aws version:\n" && saml2aws --version

RUN echo -e "aws-cli version:\n" && aws --version

WORKDIR /app
COPY /scripts/connect ./
COPY /scripts/help ./

CMD ["/bin/bash", "-c", "/app/help"]
