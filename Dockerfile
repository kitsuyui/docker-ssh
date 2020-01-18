FROM alpine:3.11@sha256:ddba4d27a7ffc3f86dd6c2f92041af252a1f23a8e742c90e6e1297bfa1bc0c45
RUN apk --update add --no-cache openssh-client && \
addgroup -S sshuser && \
adduser -S -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
