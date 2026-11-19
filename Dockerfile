FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
# Alpine 3.24 currently provides OpenSSH 10.3p1, package revision r2.
# renovate: datasource=repology depName=alpine_3_24/openssh versioning=loose
ARG OPENSSH_CLIENT_VERSION=10.3_p1-r2
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
