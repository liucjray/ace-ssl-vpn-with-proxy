FROM alpine:3.23

WORKDIR /data/

RUN apk update \
    && apk upgrade \
    && apk add automake make autoconf pkgconfig gcc g++ openssl-dev curl ppp-daemon socat iptables wget tar

ADD v1.24.0.tar.gz /data/

RUN cd openfortivpn-1.24.0 \
    && ./autogen.sh \
    && ./configure \
    && make

# Install Gost proxy
RUN wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz \
    && gunzip gost-linux-amd64-2.11.5.gz \
    && mv gost-linux-amd64-2.11.5 /usr/local/bin/gost \
    && chmod +x /usr/local/bin/gost

COPY conf/ /data/vpnclient/
COPY scripts/ /data/scripts/

RUN chmod +x /data/scripts/up.sh
RUN echo "* * * * * sh /data/scripts/keepalive.sh" >> /etc/crontabs/root

CMD ["/data/scripts/up.sh"]
