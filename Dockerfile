FROM --platform=$BUILDPLATFORM debian:bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive

ENV SOURCEURL=https://github.com/squid-cache/squid/archive/refs/tags/SQUID_6_14.tar.gz
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
    libdb5.3, \
    libdbi-perl, \
    libecap3, \
    libexpat1, \
    libgnutls30, \
    libgssapi-krb5-2, \
    libkrb5-3, \
    libldap-2.5-0, \
    libltdl7, \
    libnetfilter-conntrack3, \
    libnettle8, \
    libpam0g, \
    libsasl2-2, \
    libstdc++6, \
    libxml2, \
    netbase, \
    openssl \
    "

RUN echo "deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian bookworm main" > /etc/apt/sources.list.d/source.list \
 && echo "deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian bookworm-updates main" >> /etc/apt/sources.list.d/source.list \
 && apt-get -qy update \
 && apt-get -qy install ${builddeps} \
 && apt-get -qy build-dep squid \
 && mkdir /build

WORKDIR /build
RUN curl -L -o /build/squid-source.tar.gz ${SOURCEURL} \
 && curl -L -o /build/squid-langpack.tar.gz ${LANGPACKURL} \
 && tar --strip=1 -xf squid-source.tar.gz

RUN autoreconf --install --force

RUN ./configure --prefix=/usr \
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
        --enable-auth-basic="DB,fake,getpwnam,LDAP,NCSA,PAM,POP3,RADIUS,SASL,SMB" \
        --enable-auth-digest="file,LDAP" \
        --enable-auth-negotiate="kerberos,wrapper" \
        --enable-auth-ntlm="fake,SMB_LM" \
        --enable-external-acl-helpers="file_userip,kerberos_ldap_group,LDAP_group,session,SQL_session,time_quota,unix_group,wbinfo_group" \
        --enable-security-cert-validators="fake" \
        --enable-storeid-rewrite-helpers="file" \
        --enable-url-rewrite-helpers="fake" \
        --enable-eui \
        --enable-esi \
        --enable-icmp \
        --enable-zph-qos \
        --enable-ecap \
        --disable-translation \
        --with-swapdir=/var/spool/squid \
        --with-filedescriptors=65536 \
        --with-large-files \
        --enable-linux-netfilter \
        --enable-ssl --enable-ssl-crtd --with-openssl \
 && make -j$(awk '/^processor/{n+=1}END{print n}' /proc/cpuinfo) \
 && checkinstall -y -D --install=no --fstrans=no --requires="${requires}" \
        --pkgname="squid"

FROM --platform=$BUILDPLATFORM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

COPY --from=builder /build/squid_0-1_amd64.deb /tmp/squid.deb

RUN apt update \
 && apt -qy install ca-certificates libssl3 /tmp/squid.deb \
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
