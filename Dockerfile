FROM alpine:3.21@sha256:48b0309ca019d89d40f670aa1bc06e426dc0931948452e8491e3d65087abc07d
# renovate: datasource=repology depName=alpine_3_21/openssh versioning=loose
ARG OPENSSH_CLIENT_VERSION=9.9_p2-r0
RUN apk --update add --no-cache openssh-client=${OPENSSH_CLIENT_VERSION} && \
addgroup -S -g 200 sshuser && \
adduser -S -u 200 -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
