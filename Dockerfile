FROM debian:12-slim

MAINTAINER Rath Pascal <rath@oxl.at>

# source: https://github.com/O-X-L/postfix-relay-dockerized

ARG MAIL_HOSTNAME
ARG MAIL_DKIM_SELECTOR
ARG MAIL_PUBLIC_IP
ARG MAIL_CERT_SUBJECT="/CN=Mail Service"
ARG MAIL_ALLOWED_SRC
ARG MAIL_ALLOWED_DST
ARG MAIL_ALLOWED_NETS='1.1.1.1'
ARG MAIL_RELAY_HOST=smtp-relay.gmail.com
ARG MAIL_RELAY_PORT=25

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN test "$MAIL_ALLOWED_SRC" && \
    test "$MAIL_HOSTNAME" && \
    test "$MAIL_DKIM_SELECTOR" && \
    test "$MAIL_PUBLIC_IP" && \
    test "$MAIL_ALLOWED_DST" && \
    test "$MAIL_CERT_SUBJECT"

RUN apt-get update && \
    apt-get -y --no-install-recommends install systemd systemd-sysv ca-certificates python3 sed postfix libsasl2-modules opendkim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# setup OPENDKIM
RUN python3 -c "for d in '${MAIL_ALLOWED_SRC}'.split(','): print(f'*@{d} {d.replace(\".\", \"-\")}') if d.find('@') == -1 else print(f'{d} {d.replace(\".\", \"-\").replace(\"@\",\"-\")}')" > /etc/dkimkeys/SigningTable && \
    python3 -c "for d in '${MAIL_ALLOWED_SRC}'.split(','): print(f'{d.replace(\".\", \"-\")} {d}:${MAIL_DKIM_SELECTOR}:/etc/dkimkeys/mail.key') if d.find('@') == -1 else print(f'{d.replace(\".\", \"-\").replace(\"@\",\"-\")} {d.split(\"@\",1)[1]}:${MAIL_DKIM_SELECTOR}:/etc/dkimkeys/mail.key')" > /etc/dkimkeys/KeyTable && \
    systemctl enable opendkim.service

COPY --chmod=400 --chown=opendkim dkim.key /etc/dkimkeys/mail.key
COPY --chmod=644 opendkim.conf /etc/opendkim.conf

# setup POSTFIX
COPY --chmod=644 main.cf /etc/postfix/main.cf
COPY --chmod=644 master.cf /etc/postfix/master.cf

RUN openssl req -x509 -newkey rsa:4096 -sha256 -nodes -subj "${MAIL_CERT_SUBJECT}" -addext "subjectAltName = DNS:${MAIL_HOSTNAME},IP:${MAIL_PUBLIC_IP}" -keyout /etc/postfix/mail.key -out /etc/postfix/mail.crt -days 3650 && \
    sed -i "s|_MAIL_HOSTNAME_|${MAIL_HOSTNAME}|g" /etc/postfix/main.cf && \
    sed -i "s|_MAIL_ALLOWED_NETS_|${MAIL_ALLOWED_NETS}|g" /etc/postfix/main.cf && \
    sed -i "s|_MAIL_RELAY_HOST_|${MAIL_RELAY_HOST}|g" /etc/postfix/main.cf && \
    sed -i "s|_MAIL_RELAY_PORT_|${MAIL_RELAY_PORT}|g" /etc/postfix/main.cf && \
    python3 -c "for d in '$MAIL_ALLOWED_DST'.split(','): print(f'.{d} :\n{d} :')" > /etc/postfix/transport && \
    echo '* discard:' >> /etc/postfix/transport && \
    postmap /etc/postfix/transport && \
    systemctl enable postfix.service

# todo: forward application logs to docker
# journalctl -f -u postfix.service -u opendkim.service -u system-postfix.slice &

CMD ["/sbin/init"]
