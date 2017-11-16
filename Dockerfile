FROM debian:stretch as builder

ARG DEBIAN_FRONTEND=noninteractive

ENV SOURCEURL=http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.27.tar.gz

ENV builddeps="build-essential checkinstall curl devscripts libcrypto++-dev libssl1.0-dev openssl"
ENV requires="libgnutls30,openssl,libc6,libcap2,libcomerr2,libdb5.3,libecap3,libexpat1,libgcc1,libgssapi-krb5-2,libkrb5-3,libldap-2.4-2,libltdl7,libnetfilter-conntrack3,libnettle6,libpam0g,libsasl2-2,libstdc++6,libxml2,netbase,libdbi-perl"

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
 && checkinstall -y -D --install=no --fstrans=no --requires="${requires}" \
        --pkgname="squid"

FROM debian:stretch

label maintainer="Jacob Alberty <jacob.alberty@foundigital.com>"

ARG DEBIAN_FRONTEND=noninteractive

COPY --from=builder /build/squid_0-1_amd64.deb /tmp/squid.deb

RUN apt update \
 && apt -qy install libssl1.0 /tmp/squid.deb \
 && rm -rf /var/lib/apt/lists/*

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["squid", "-NYC", "-f", "/conf/squid.conf"]
