FROM debian:trixie AS builder

ARG DEBIAN_FRONTEND=noninteractive

# SQUID_VERSION is the base of the image version: releases are tagged
# v<SQUID_VERSION> with the underscore as a dot (6_14 -> v6.14), then
# v6.14-N for later image changes. Upstream tags are SQUID_<major>_<minor>.
# renovate: datasource=github-tags depName=squid-cache/squid versioning=regex:^(?<major>\d+)_(?<minor>\d+)$ extractVersion=^SQUID_(?<version>\d+_\d+)$
ARG SQUID_VERSION=7_8

ENV SOURCEURL=https://github.com/squid-cache/squid/archive/refs/tags/SQUID_${SQUID_VERSION}.tar.gz
ENV LANGPACKURL=https://www.squid-cache.org/Versions/langpack/squid-langpack-20240307.tar.gz

ENV builddeps=" \
    build-essential \
    checkinstall \
    curl \
    devscripts \
    libcrypto++-dev \
    libssl-dev \
    openssl \
    "
ENV requires=" \
    libatomic1, \
    libc6, \
    libcap2, \
    libdb5.3t64, \
    libdbi-perl, \
    libecap3, \
    libgnutls30t64, \
    libgssapi-krb5-2, \
    libkrb5-3, \
    libldap2, \
    libltdl7, \
    libnetfilter-conntrack3, \
    libnettle8t64, \
    libpam0g, \
    libsasl2-2, \
    libstdc++6, \
    libtdb1, \
    netbase, \
    openssl \
    "

# Trixie ships its apt sources in deb822 format; turn on source packages so
# build-dep can resolve Squid's build dependencies.
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources \
 && apt-get -qy update \
 && apt-get -qy install ${builddeps} \
 && apt-get -qy build-dep squid \
 && mkdir /build

WORKDIR /build
RUN curl -L -o /build/squid-source.tar.gz ${SOURCEURL} \
 && curl -L -o /build/squid-langpack.tar.gz ${LANGPACKURL} \
 && tar --strip=1 -xf squid-source.tar.gz

RUN autoreconf --install --force

# -O2 without the -g configure would add: no debug info is shipped, so
# skip generating it (faster compile and link, smaller image).
RUN CFLAGS="-O2" CXXFLAGS="-O2" ./configure --prefix=/usr \
        --with-build-environment=default \
        --localstatedir=/var \
        --libexecdir=/usr/lib/squid \
        --datadir=/usr/share/squid \
        --sysconfdir=/etc/squid \
        --with-default-user=proxy \
        --with-logdir=/var/log/squid \
        --with-pidfile=/run/squid.pid \
        --mandir=/usr/share/man \
        --enable-inline \
        --disable-arch-native \
        --enable-async-io=8 \
        --enable-storeio="ufs,aufs,diskd,rock" \
        --enable-removal-policies="lru,heap" \
        --enable-delay-pools \
        --enable-cache-digests \
        --enable-icap-client \
        --enable-follow-x-forwarded-for \
        --enable-forw-via-db \
        --enable-x-accelerator-vary \
        --enable-auth-basic="DB,fake,getpwnam,LDAP,NCSA,PAM,POP3,RADIUS,SASL,SMB" \
        --enable-auth-digest="file,LDAP,eDirectory" \
        --enable-auth-negotiate="kerberos,wrapper" \
        --enable-auth-ntlm="fake" \
        --enable-external-acl-helpers="delayer,eDirectory_userip,file_userip,kerberos_ldap_group,kerberos_sid_group,LDAP_group,session,SQL_session,time_quota,unix_group,wbinfo_group" \
        --enable-security-cert-validators="fake" \
        --enable-storeid-rewrite-helpers="file" \
        --enable-url-rewrite-helpers="fake,LFS" \
        --enable-eui \
        --enable-icmp \
        --enable-zph-qos \
        --enable-ecap \
        --disable-translation \
        --with-swapdir=/var/spool/squid \
        --with-filedescriptors=65536 \
        --with-large-files \
        --enable-linux-netfilter \
        --disable-strict-error-checking \
        --enable-ssl-crtd --with-openssl \
 && make -j$(nproc) \
 && checkinstall -y -D --install=no --fstrans=no --requires="${requires}" \
        --pkgname="squid"

FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive

COPY --from=builder /build/squid_0-1_*.deb /tmp/squid.deb

RUN apt update \
 && apt -qy install ca-certificates libssl3t64 /tmp/squid.deb \
 && rm -rf /var/lib/apt/lists/*

# Install language pack
COPY --from=builder /build/squid-langpack.tar.gz /tmp/squid-langpack.tar.gz
RUN cd /usr/share/squid/errors \
  && tar -xf /tmp/squid-langpack.tar.gz \
  && rm -rf /tmp/squid-langpack.tar.gz \
  && /usr/share/squid/errors/alias-link.sh /bin/ln /bin/rm /usr/share/squid/errors /usr/share/squid/errors/aliases

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["squid", "-NYC", "-f", "/conf/squid.conf"]
