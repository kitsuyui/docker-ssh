FROM alpine:3.17@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a
RUN apk --update add --no-cache openssh-client && \
addgroup -S sshuser && \
adduser -S -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
