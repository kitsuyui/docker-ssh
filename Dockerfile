FROM alpine:3.7
RUN apk --update add --no-cache openssh-client && \
addgroup -S sshuser && \
adduser -S -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
