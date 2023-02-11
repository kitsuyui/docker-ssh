FROM alpine:3.17@sha256:c8deccde20bcc319a17c28ce674b80b9b7e945a8b460a11272b7f0a3e0d6a746
RUN apk --update add --no-cache openssh-client && \
addgroup -S sshuser && \
adduser -S -G sshuser sshuser && \
mkdir -p /home/sshuser/.ssh && \
chown sshuser:sshuser /home/sshuser/.ssh && \
chmod 700 /home/sshuser/.ssh
USER sshuser
WORKDIR /home/sshuser
VOLUME /home/sshuser/.ssh
