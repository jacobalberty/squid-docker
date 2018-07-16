FROM debian:stretch as builder
MAINTAINER Jacob Alberty <jacob.alberty@foundigital.com>

ARG DEBIAN_FRONTEND=noninteractive

ENV SOURCEURL=http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.28.tar.gz

ENV builddeps="build-essential checkinstall curl devscripts libcrypto++-dev libssl1.0-dev openssl"
ENV requires="openssl"

RUN echo "deb-src http://deb.debian.org/debian stretch main" > /etc/apt/sources.list.d/source.list \
 && echo "deb-src http://deb.debian.org/debian stretch-updates main" >> /etc/apt/sources.list.d/source.list \
 && echo "deb-src http://security.debian.org stretch/updates main" >> /etc/apt/sources.list.d/source.list \
 && apt-get -qy update \
 && apt-get -qy install ${builddeps} \
 && apt-get -qy build-dep squid \
 && mkdir /build \
 && curl -o /build/squid-source.tar.gz ${SOURCEURL} \
 && cd /build \
 && tar --strip=1 -xf squid-source.tar.gz \
 && ./configure --prefix=/usr \
        --localstatedir=/var \
        --libexecdir=/usr/lib/squid \
        --datadir=/usr/share/squid \
        --sysconfdir=/etc/squid \
        --with-default-user=proxy \
        --with-logdir=/var/log/squid \
        --with-pidfile=/var/run/squid.pid \
        --enable-ssl --enable-ssl-crtd --with-openssl \
 && make \
 && checkinstall -y -D --install=no --fstrans=no --requires="${requires}"
        --pkgname="squid"

FROM debian:jessie

COPY --from=builder /build/squid_0-1_amd64.deb /tmp/squid.deb

RUN apt update \
 && apt install /tmp/squid.deb \
 && rm -rf /var/lib/apt/lists/*

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["squid", "-NYC", "-f", "/conf/squid.conf"]
