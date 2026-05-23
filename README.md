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
sudo chown -R 200:200 home_ssh
chmod 700 home_ssh
for key in home_ssh/id_ed25519 home_ssh/id_rsa; do
  [ ! -e "$key" ] || chmod 600 "$key"
done
[ ! -e home_ssh/config ] || chmod 600 home_ssh/config
[ ! -e home_ssh/known_hosts ] || chmod 644 home_ssh/known_hosts
```

All files must be owned by the user running the container (`sshuser`, uid 200).
If Docker Desktop for macOS or Windows reports `UNPROTECTED PRIVATE KEY FILE!`
even after `chmod`, the host file sharing layer may not be preserving the POSIX
mode bits that OpenSSH requires. In that case, use a Docker volume or a Linux
filesystem that preserves Unix ownership and permissions for private keys.

## Non-interactive (batch) mode

The image sets `BatchMode yes` in `/etc/ssh/ssh_config`. In batch mode, SSH
exits immediately with an error instead of waiting for interactive input such as
a passphrase prompt or a password prompt. This ensures the container never hangs
in a CI/CD pipeline.

If you need an interactive SSH session, override the setting at the command line:

```sh
docker run --rm -it -v ./home_ssh:/home/sshuser/.ssh kitsuyui/docker-ssh \
  ssh -o BatchMode=no user@host
```

## Host key verification

The container runs non-interactively (no TTY). If `known_hosts` does not contain
the target host's fingerprint, SSH exits with an error instead of hanging.

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

The `keygen` service in `docker-compose.yml` runs as a one-shot setup task and
writes an Ed25519 key pair to `./home_ssh`:

```sh
mkdir -p home_ssh
docker compose --profile setup run --rm keygen
```

This places `id_ed25519` and `id_ed25519.pub` in `./home_ssh` with ownership and
permissions suitable for the container user. If either key file already exists,
the setup task exits instead of overwriting it. Remove the existing key pair, or
restore the missing half of a partial key pair, before running key generation
again.

Copy the public key to the remote host, then start one forwarding example at a
time:

```sh
docker compose --profile forwarding up example_left_forward_8080
```

Keep key generation separate from the forwarding services so tunnels never start
before the mounted SSH directory has been prepared.

# LICENSE

The 3-Clause BSD License. See also LICENSE file.

But this is quite simple Dockerfile.
So it might have no novelty.
