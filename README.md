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

## Port forwarding and Docker network isolation

SSH local forwarding (`-L`) and remote forwarding (`-R`) behave differently
inside a Docker container.

### Local forward (`-L`)

```
ssh -N -L 8080:127.0.0.1:8080 examplehost
```

`-L` binds the tunnel's local endpoint inside the **container**. With Docker's
default bridge network, the container's `127.0.0.1` is not reachable from the
Docker host. Running this command inside the container creates a tunnel that is
only accessible from within the container, not from the host OS.

To reach the tunnel from the Docker host, use one of the following approaches:

**Option A — host network mode** (`network_mode: host` in `docker-compose.yml`)

The container shares the host's network stack. The tunnel binds to host
`127.0.0.1:8080` directly. Simple, but the container loses network isolation.

**Option B — port mapping with all-interface bind**

Change the bind address to `0.0.0.0` and add a `ports:` mapping:

```yaml
ports:
  - "127.0.0.1:8080:8080"
command: ssh ... -N -L 0.0.0.0:8080:127.0.0.1:8080 examplehost
```

Docker proxies `host:8080` → `container:8080`. The tunnel must listen on all
container interfaces (`0.0.0.0`) rather than only on `127.0.0.1` for the proxy
to reach it. Network isolation is preserved; the port is exposed only on the
specified host address.

### Remote forward (`-R`)

```
ssh -N -R 0.0.0.0:8080:127.0.0.1:8080 examplehost
```

`-R` binds the port on the **remote host** (examplehost), not locally. Docker
network isolation does not affect which ports are reachable on the remote side,
so `network_mode: host` is not required for remote forwarding.

> **Server prerequisite**: binding to a non-loopback address (`0.0.0.0`) requires
> `GatewayPorts clientspecified` (or `GatewayPorts yes`) in examplehost's
> `/etc/ssh/sshd_config`. With the default `GatewayPorts no`, OpenSSH silently
> falls back to loopback-only binding regardless of the requested address.

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
# Local forward: expose examplehost:8080 on the Docker host
docker compose --profile forwarding up example_left_forward_8080

# Remote forward: expose localhost:8080 on examplehost:8080
# Requires GatewayPorts clientspecified in examplehost's sshd_config
docker compose --profile forwarding up example_right_forward_8080
```

Keep key generation separate from the forwarding services so tunnels never start
before the mounted SSH directory has been prepared.

## Development

Install [lefthook](https://github.com/evilmartians/lefthook) and register the hooks:

```sh
lefthook install
```

The hooks run two fast static checks before every commit and push:

- **hadolint** — lints the `Dockerfile` for best-practice issues
- **shellcheck** — analyses `entrypoint.sh` for shell script bugs

These checks are intentionally lightweight and run entirely locally so problems
surface before they reach CI. The full `docker build` is left to CI because it
requires a Docker daemon and takes considerably longer.

### Updating `.gitignore`

Do not edit `.gitignore` directly. It is generated from `.gitignore.in` with
[`gitignore.in`](https://github.com/gitignore-in/gitignore-in).

Install the tool from its releases page or with Homebrew:

```sh
brew tap gitignore-in/gitignore-in
brew install gitignore-in
```

Add ignore entries to `.gitignore.in` with one supported template command per
line, then rebuild `.gitignore`:

```sh
gitignore.in
```

This repository's `.gitignore.in` currently uses `echo home_ssh/` to emit the
local SSH credential mount directory. The scheduled `gitignore-in.yml` workflow
also refreshes the generated `.gitignore` automatically.

## Release criteria

Docker Hub publishing is driven by GitHub Releases. The
`docker-release.yml` workflow builds images for pull requests and prereleases,
but it pushes Docker Hub tags only when a non-prerelease GitHub Release is
published.

Cut a new release when a merged change should be available through
`docker pull kitsuyui/docker-ssh:latest`, including:

- security fixes in the image, Dockerfile, entrypoint, or SSH defaults
- runtime behavior changes for SSH invocation, tunneling, logging, or health
  checks
- dependency or base-image updates that affect the published image contents
- documentation-only changes that do not change the image can wait for the next
  runtime or security release

Before publishing, make sure the pull-request Docker build has passed on
`main`, choose the next semantic version tag, and publish a GitHub Release for
that tag. The release workflow creates the multi-platform image and tags it with
the release version, the major/minor alias, and `latest`.

# LICENSE

The 3-Clause BSD License. See also LICENSE file.

But this is quite simple Dockerfile.
So it might have no novelty.
