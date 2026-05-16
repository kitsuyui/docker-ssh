# docker-ssh

[![Docker Hub Pulls](https://img.shields.io/docker/pulls/kitsuyui/docker-ssh.svg)](https://hub.docker.com/r/kitsuyui/docker-ssh/)

OpenSSH client in Docker.
Host OS is Alpine Linux.

# Usage

Mount a directory containing your SSH credentials at `/home/sshuser/.ssh`:

```sh
docker run --rm -v ./home_ssh:/home/sshuser/.ssh kitsuyui/docker-ssh ssh user@host
```

## What to place in the mounted directory

| File | Purpose | Permission |
|---|---|---|
| `id_ed25519` (or `id_rsa`) | Private key for public-key authentication | `600` |
| `known_hosts` | Trusted host fingerprints (avoids interactive prompt on first connect) | `644` |
| `config` | Per-host SSH settings (optional) | `600` |

All files must be owned by the user running the container (`sshuser`, uid 100).

## Host key verification

The container runs non-interactively (no TTY). If `known_hosts` does not contain
the target host's fingerprint, SSH will wait for interactive input that never arrives
and the container will appear to hang.

**First-time setup — populate `known_hosts` before starting the tunnel:**

```sh
ssh-keyscan -H examplehost >> ./home_ssh/known_hosts
```

Alternatively, the example `docker-compose.yml` services use
`-o StrictHostKeyChecking=accept-new`, which automatically trusts and records
the host key on the first connection (TOFU model). This is convenient for
development but should be replaced with a pre-populated `known_hosts` in
environments where the remote host's identity must be verified.

## Generate a key pair

The commented-out `keygen` service in `docker-compose.yml` runs `ssh-keygen` inside
the container and writes the output to `./home_ssh`:

```sh
mkdir -p home_ssh
docker compose run --rm keygen
```

This places `id_ed25519` and `id_ed25519.pub` in `./home_ssh` with the correct
permissions. Copy the public key to the remote host, then use the composed services
for port forwarding or any other SSH command.

# LICENSE

The 3-Clause BSD License. See also LICENSE file.

But this is quite simple Dockerfile.
So it might have no novelty.
