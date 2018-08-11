FROM alpine:3.7@sha256:56e2f91ef15847a2b02a5a03cbfa483949d67a242c37e33ea178e3e7e01e0dfd
RUN apk --update add --no-cache openssh-client && \
addgroup -S sshuser && \
adduser -S -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
