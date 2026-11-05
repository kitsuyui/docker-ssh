FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a
# Alpine uses 9.9_p2-r0 for OpenSSH 9.9p2, package revision r0.
# OpenSSH 9.9p2 is a security fix release:
# https://www.openssh.com/txt/release-9.9p2
# renovate: datasource=repology depName=alpine_3_21/openssh versioning=loose
ARG OPENSSH_CLIENT_VERSION=9.9_p2-r0
RUN apk add --no-cache openssh-client=${OPENSSH_CLIENT_VERSION} && \
printf 'BatchMode yes\n' >> /etc/ssh/ssh_config && \
printf 'ServerAliveInterval 15\n' >> /etc/ssh/ssh_config && \
printf 'ServerAliveCountMax 3\n' >> /etc/ssh/ssh_config && \
printf 'ExitOnForwardFailure yes\n' >> /etc/ssh/ssh_config && \
addgroup -S -g 200 sshuser && \
adduser -S -u 200 -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Verify the ssh process is still running. The image defaults enable OpenSSH
# keepalives so broken tunnels should exit and let the container restart.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["pgrep", "-x", "ssh"]
USER 200:200
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
