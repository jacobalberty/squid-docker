# squid-docker
This is a squid (http://www.squid-cache.org/) docker image

## Usage

Simply put your squid configuration in /conf with squid.conf located there as well.

## Enabled options

The squid install within this container is built with --enable-ssl, --enable-ssl-crtd and --with-openssl to allow
SSL bumping.

