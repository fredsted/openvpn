FROM kylemanna/openvpn:latest

ARG K8S_VERSION=v1.5.1

ARG S6_OVERLAY_VERSION=1.17.2.0
ARG OPENVPN_API_VERSION=0.4

ENV MFA_PROVIDER=

ENV DUO_IKEY=
ENV DUO_SKEY=
ENV DUO_HOST=
ENV DUO_FAILMODE=secure
ENV DUO_AUTOPUSH=yes
ENV DUO_PROMPTS=1

ENV OVPN_RENEG_SEC=0

ADD https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

RUN apk --update add linux-pam ca-certificates libintl gettext && \
    update-ca-certificates && \
    ln -s /lib /lib64

# Install s6-overlay
RUN set -ex \
    && apk update \
    && apk add --no-cache --virtual .build-deps \
          curl \
    && curl https://s3.amazonaws.com/wodby-releases/s6-overlay/v${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz | tar xz -C / \
    && apk del .build-deps;

ENTRYPOINT ["/init"]


RUN apk add --virtual .build-deps build-base automake autoconf libtool git linux-pam-dev openssl-dev wget unzip && \
    mkdir -p /usr/src && \
    cd /usr/src && \
    ( wget -O duo_unix-latest.zip https://github.com/goruha/duo_unix/archive/master.zip && \
      unzip duo_unix-latest.zip && \
      rm -f  duo_unix-latest.zip && \
      cd duo_unix-* && \
      ./bootstrap && \
      ./configure --with-pam --prefix=/usr && \
      make && \
      make install && \
      cd ../.. && \
      rm -rf duo_unix-* \
    ) && \
    rm -rf /usr/src && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/*


ADD rootfs /

ADD https://raw.githubusercontent.com/cloudposse/build-harness/master/templates/Makefile.build-harness Makefile

RUN set -ex \
      && apk update \
      && apk add --no-cache --virtual .build-deps \
          curl \
          jq \
          git \
          make \
      && make \
      && REPO=cloudposse/openvpn-api \
          VERSION=$OPENVPN_API_VERSION \
          FILE=openvpn-api_linux_386 \
          OUTPUT=openvpn-api \
          make github:download-public-release \
      && chmod +x openvpn-api \
      && mv openvpn-api /bin/ \
      && apk del .build-deps

