# Postfix Mail-Relay Dockerized

**Disclaimer**: This container utilizes [debian12 with systemd](https://serverfault.com/questions/1053187/systemd-fails-to-run-in-a-docker-container-when-using-cgroupv2-cgroupns-priva) which will be seen as *unclean* setup by some!

----

## Contribute

Feel free to open Issues/Discussions or provide PRs!

A non-systemd (unprivileged) setup may be added later on. If you have input on such a setup => help is welcome.

----

## Features / Config

* Using a DKIM Key for all sender adresses
* Only allow specific receiver domains (see `/etc/postfix/transport`)
* No authentication for now - only filtering by IP/Network
* Listening on port 2525 (see `/etc/postfix/master.cf`)
* StartTLS with Snakeoil Certificate that has FQDN and IP in SAN

### Roadmap

* [Inbound SASL authentication](https://serverfault.com/questions/547282/postfix-how-to-use-simple-file-for-sasl-authentication)
* Option for Outbound Relay + SASL authentication
* Forward mail-service logs to `docker logs`

----

## KnowHow & Security

This mail relay can be unsafe, if you misconfigure it!

**Make sure**:

* You [understand the basics of E-Mail security](https://docs.o-x-l.com/mail/security.html)!
* To only allow IPs to access it, that you have control over
* Utilize the send/receive filters
* Add firewall-filters to limit the access to the relay

----

## Build

### Variables

* **MAIL_HOSTNAME** => You full-qualified mailserver-hostname
* **MAIL_DKIM_SELECTOR** => The DKIM selector you want to use (*needs to be used in the DNS record*)
* **MAIL_PUBLIC_IP** => Public IP the mail-server will use for outbound traffic

  Note: You should also make sure that a PTR (*reverse DNS*) points to this IP and resolves to your FQDN hostname

* **MAIL_CERT_SUBJECT** => TLS Certificate subject-name in openssl-format (*Default: /CN=Mail Service*)
* **MAIL_ALLOWED_SRC** => Comma-separated list of domains or e-mail addresses that will be signed with your DKIM key
* **MAIL_ALLOWED_DST** => Comma-separated list of receiver-domains that are allowed. Other E-mails will be dropped (*to limit impact if someone would be able to send spam over this relay*)

* **MAIL_ALLOWED_NETS** => Space-separated Networks in CIDR-format that are allowed to send over this mail-relay.

  **Warning**: If you are using docker in bridge-mode - this filter might not work as the source-IPs get NATed


### Generate DKIM Key-Pair

```bash
openssl genrsa -out mail.key 2048
chmod 600 mail.key
openssl rsa -in mail.key -pubout > mail.crt
cat mail.crt | tr -d '\n'
```

Copy the Public-Key (*without headers*) and create a DNS record for your chosen selector:

`<SELECTOR>._domainkey.<DOMAIN>.<TLD> TXT "v=DKIM1; k=rsa; p=<PUBLIC-KEY>"`

Example:

`test._domainkey.oxl.at TXT "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0BtDBbXYRNcft4d6LeTGkybsxc1JVXxZ2hJHDteHhU7TUfQGq2MqcsegVU97l6THb8VZxv7hWKCFSXwLh1QHRAVB9bxVFbu08cI9OMPpfvjq2XyVdY6D1lRD36emn4Mk9F6kIb5apP6QQtFPvMsX/15NZLZ/pr+G2DHl3TfG7vQIDAQAB"`

## Example

Add your `dkim.key` file before to the same directory as the Dockerfile!

`docker build -f Dockerfile_postfix --no-cache --build-arg MAIL_ALLOWED_SRC=service@oxl.at --build-arg MAIL_HOSTNAME=xyz.oxl.at --build-arg MAIL_PUBLIC_IP=1.1.1.1 --build-arg MAIL_CERT_SUBJECT="/CN=My Mail Service" --build-arg MAIL_ALLOWED_DST=oxl.at --build-arg MAIL_ALLOWED_NETS="192.168.10.0/24 1.1.1.1/32" --build-arg MAIL_DKIM_SELECTOR=test -t postfix .`

----

# Run

## Host Mode

`docker run -d --net host --restart always --privileged --name postfix postfix:latest /sbin/init --tmpfs /tmp --tmpfs /run --tmpfs /run/lock`

## Bridged Mode

Not recommended because of Source-NAT.

`docker run -d -p 2525:25/tcp --restart always --privileged --name postfix postfix:latest /sbin/init --tmpfs /tmp --tmpfs /run --tmpfs /run/lock`

----

## Test

* Enter the container: `docker exec -it postfix /bin/bash`
* Send a test-mail: `echo 'Subject: Test-Mail' | sendmail -F 'TEST_FROM' -f 'TEST_FROM' -t 'TEST_TO'`
* Check the logs: `journalctl -n 20`
