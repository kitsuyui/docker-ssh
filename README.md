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

| Path | Purpose | Permission |
|---|---|---|
| `home_ssh/` | Host directory mounted as `/home/sshuser/.ssh` | `700` |
| `id_ed25519` (or `id_rsa`) | Private key for public-key authentication | `600` |
| `known_hosts` | Trusted host fingerprints (avoids interactive prompt on first connect) | `644` |
| `config` | Per-host SSH settings (optional) | `600` |

The Dockerfile creates `/home/sshuser/.ssh` with secure ownership and mode bits,
but a bind mount replaces that directory at runtime. OpenSSH therefore sees the
host-side owner and permissions for `./home_ssh`.

On Linux hosts, make the directory and private files readable only by the
container user before starting the container:

```sh
sudo chown -R 100:100 home_ssh
chmod 700 home_ssh
for key in home_ssh/id_ed25519 home_ssh/id_rsa; do
  [ ! -e "$key" ] || chmod 600 "$key"
done
[ ! -e home_ssh/config ] || chmod 600 home_ssh/config
[ ! -e home_ssh/known_hosts ] || chmod 644 home_ssh/known_hosts
```

All files must be owned by the user running the container (`sshuser`, uid 100).
If Docker Desktop for macOS or Windows reports `UNPROTECTED PRIVATE KEY FILE!`
even after `chmod`, the host file sharing layer may not be preserving the POSIX
mode bits that OpenSSH requires. In that case, use a Docker volume or a Linux
filesystem that preserves Unix ownership and permissions for private keys.

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
