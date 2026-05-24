FROM alpine:3.21@sha256:48b0309ca019d89d40f670aa1bc06e426dc0931948452e8491e3d65087abc07d
# Alpine uses 9.9_p2-r0 for OpenSSH 9.9p2, package revision r0.
# OpenSSH 9.9p2 is a security fix release:
# https://www.openssh.com/txt/release-9.9p2
# renovate: datasource=repology depName=alpine_3_21/openssh versioning=loose
ARG OPENSSH_CLIENT_VERSION=9.9_p2-r0
RUN apk add --no-cache openssh-client=${OPENSSH_CLIENT_VERSION} && \
printf 'BatchMode yes\n' >> /etc/ssh/ssh_config && \
addgroup -S -g 200 sshuser && \
adduser -S -u 200 -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
