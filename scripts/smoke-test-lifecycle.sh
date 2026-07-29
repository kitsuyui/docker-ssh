#!/bin/sh
set -eu

image_tag="${1:-docker-ssh-test}"
network_name="docker-ssh-smoke-test-$$"
server_name="docker-ssh-test-server"
tunnel_name="docker-ssh-test-tunnel"
tmpdir="$(mktemp -d)"

cleanup() {
  docker unpause "$server_name" >/dev/null 2>&1 || true
  docker rm -f "$tunnel_name" "$server_name" >/dev/null 2>&1 || true
  docker network rm "$network_name" >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}

trap cleanup EXIT INT TERM

# The image runs as the unprivileged "sshuser" (uid/gid 200), so the private
# key mounted into it must be owned by that uid: if it stayed owned by the
# host user, ssh could not open it (EACCES), and widening its mode instead
# would make ssh refuse it as an "unprotected private key". Generate the key
# pair as uid 200 inside the image itself so ownership matches from the start.
chmod 777 "$tmpdir"
docker run --rm -u 200:200 -v "$tmpdir:/keys" "$image_tag" \
  ssh-keygen -q -t ed25519 -N '' -f /keys/id_ed25519 >/dev/null
cp "$tmpdir/id_ed25519.pub" "$tmpdir/authorized_keys"

docker network create "$network_name" >/dev/null
docker run -d --name "$server_name" --network "$network_name" \
  -v "$tmpdir/authorized_keys:/authorized_keys:ro" alpine:3.21 sh -eu -c '
    apk add --no-cache openssh-server >/dev/null
    ssh-keygen -A >/dev/null
    mkdir -p /root/.ssh /run/sshd
    cp /authorized_keys /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    cat > /etc/ssh/sshd_config <<EOF
Port 2222
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
AuthorizedKeysFile /root/.ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PermitRootLogin yes
PidFile /run/sshd.pid
LogLevel VERBOSE
EOF
    exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
  ' >/dev/null

ready=0
for _ in $(seq 1 30); do
  if docker run --rm --network "$network_name" -v "$tmpdir:/keys:ro" "$image_tag" \
    ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i /keys/id_ed25519 -p 2222 root@"$server_name" true >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "temporary ssh server did not become ready" >&2
  docker logs "$server_name" >&2 || true
  exit 1
fi

ssh_config_check="$(docker run --rm "$image_tag" ssh -G examplehost)"
printf '%s\n' "$ssh_config_check" | grep -Fx 'serveraliveinterval 15' >/dev/null
printf '%s\n' "$ssh_config_check" | grep -Fx 'serveralivecountmax 3' >/dev/null
printf '%s\n' "$ssh_config_check" | grep -Fx 'exitonforwardfailure yes' >/dev/null

docker run -d --name "$tunnel_name" --network "$network_name" -v "$tmpdir:/keys:ro" "$image_tag" \
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /keys/id_ed25519 -p 2222 -N root@"$server_name" >/dev/null

pid1_is_ssh=0
for _ in $(seq 1 15); do
  if [ "$(docker exec "$tunnel_name" cat /proc/1/comm 2>/dev/null || true)" = "ssh" ]; then
    pid1_is_ssh=1
    break
  fi
  sleep 1
done

if [ "$pid1_is_ssh" -ne 1 ]; then
  echo "expected PID 1 to be ssh inside the tunnel container" >&2
  docker logs "$tunnel_name" >&2 || true
  exit 1
fi

docker pause "$server_name" >/dev/null

# ServerAliveInterval(15) * ServerAliveCountMax(3) = 45s worst-case before the
# client even notices the stall, plus up to ~15s until the first probe after
# the last successful one. Give extra margin over that ~60s worst case so the
# assertion isn't flaky on a busy CI runner.
tunnel_exited=0
for _ in $(seq 1 120); do
  if [ "$(docker inspect -f '{{.State.Status}}' "$tunnel_name")" = "exited" ]; then
    tunnel_exited=1
    break
  fi
  sleep 1
done

if [ "$tunnel_exited" -ne 1 ]; then
  echo "ssh tunnel stayed running after the remote endpoint stopped responding" >&2
  docker logs "$tunnel_name" >&2 || true
  exit 1
fi

if [ "$(docker inspect -f '{{.State.ExitCode}}' "$tunnel_name")" -eq 0 ]; then
  echo "expected ssh tunnel to fail closed after the remote endpoint stalled" >&2
  docker logs "$tunnel_name" >&2 || true
  exit 1
fi
