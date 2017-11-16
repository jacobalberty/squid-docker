FROM debian:stretch
MAINTAINER Jacob Alberty <jacob.alberty@foundigital.com>

ARG DEBIAN_FRONTEND=noninteractive
ENV SOURCEURL=http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.27.tar.gz

RUN echo "deb-src http://deb.debian.org/debian stretch main" > /etc/apt/sources.list.d/source.list \
 && echo "deb-src http://deb.debian.org/debian stretch-updates main" >> /etc/apt/sources.list.d/source.list \
 && echo "deb-src http://security.debian.org stretch/updates main" >> /etc/apt/sources.list.d/source.list \
 && apt-get -qy update \
 && apt-get -qy install curl libssl1.0-dev openssl devscripts build-essential libcrypto++-dev  \
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
 && make install \
 && cd / \
 && rm -rf /build \
 && apt-get -qy purge --auto-remove curl \
 && apt-get -qy purge libssl1.0-dev devscripts build-essential libcrypto++-dev  \
 && rm -rf /var/lib/apt/lists/

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["squid", "-NYC", "-f", "/conf/squid.conf"]
