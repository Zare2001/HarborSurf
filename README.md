# Harbor Container Registry Setup

Deploy [Harbor](https://goharbor.io/) so you get a **server with a URL and a web interface** (Harbor Portal) to manage and host Docker images.

## Which Harbor docs apply?

| Doc section | Purpose |
|-------------|--------|
| **[Installation and Configuration](https://goharbor.io/docs/2.14.0/install-config/)** | **Use this** – deploy Harbor, get the web UI at `http(s)://your-hostname` |
| [Run the Installer Script](https://goharbor.io/docs/2.14.0/install-config/run-installer-script/) | After `install.sh`, open a browser at the **hostname** you set in `harbor.yml` |
| [Configure the Harbor YML File](https://goharbor.io/docs/2.14.0/install-config/configure-yml-file/) | `hostname` = address where you access the **Harbor Portal and registry** |
| [Configure HTTPS](https://goharbor.io/docs/2.14.0/install-config/configure-https/) | Production: HTTPS so the link is `https://your-domain` |
| [Build, Customize, Contribute](https://goharbor.io/docs/2.14.0/build-customize-contribute/) | **Not for deployment** – building from source, customizing look/feel |

The **web interface** is the Harbor Portal. Official flow:

1. Set **`hostname`** in `harbor.yml` to your server IP or FQDN (this becomes the link).
2. Run **`./install.sh`** (after `./prepare`).
3. **Open a browser** at `http://<hostname>` (HTTP) or `https://<hostname>` (HTTPS).
4. Log in with **`admin`** / **`Harbor12345`** (change after first login).

See [Run the Installer Script](https://goharbor.io/docs/2.14.0/install-config/run-installer-script/): *“you can open a browser to visit the Harbor interface at `http://reg.yourdomain.com`, changing `reg.yourdomain.com` to the hostname that you configured in `harbor.yml`.”*

---

## Quick Start

### Option 1: Shell Script

1. **Edit `harbor.yml`** – set `hostname` to the address users will open in the browser (IP or FQDN):
   ```yaml
   hostname: 192.168.1.100   # or reg.yourdomain.com
   ```
   Do **not** use `localhost` or `127.0.0.1` – clients must reach Harbor from outside.

2. **Run on the server:**
   ```bash
   chmod +x setup-harbor.sh
   ./setup-harbor.sh 192.168.1.100
   ```

3. **HTTP only (dev/test):** Add to `/etc/docker/daemon.json` on clients:
   ```json
   { "insecure-registries": ["192.168.1.100"] }
   ```
   Then `sudo systemctl restart docker`.

4. **Open the interface:** `http://YOUR_SERVER_IP` → Harbor Portal.

### Option 2: Ansible Playbook

```bash
cp inventory.ini.example inventory.ini
ansible-playbook -i inventory.ini ansible-playbook.yml -e "harbor_hostname=192.168.1.100"
```

Then open `http://<harbor_hostname>` in a browser.

---

## Research Cloud / component type

| Type | Use |
|------|-----|
| **Ansible Playbook** | `ansible-playbook.yml` |
| **Docker Compose** | Installer generates `docker-compose.yml`; no static compose in repo |

---

## Push / pull images

**Image reference format — no `http://`:**

```text
YOUR_HOSTNAME/<project>/<repository>:<tag>
```

Example: `145.38.205.248/demo/20klogregchallenge:latest`

```bash
docker login YOUR_HOSTNAME
docker build --platform linux/amd64 -t YOUR_HOSTNAME/myproject/myimage:latest .
docker push YOUR_HOSTNAME/myproject/myimage:latest
```

Create the project in the **Harbor Portal** first.

### HTTP registry + Docker always tries HTTPS first

If `docker login` hits **port 443** and gets **connection refused**, the daemon must allow insecure HTTP for that host.

- **On the Harbor server:** `/etc/docker/daemon.json`:
  ```json
  { "insecure-registries": ["YOUR_HOSTNAME"] }
  ```
  then `sudo systemctl restart docker`.
- **Colima on Mac:** Colima overwrites `/etc/docker/daemon.json` on start. Either merge `insecure-registries` **inside** the VM after each `colima start`, or use **push-via-ssh** below.

### Push without fixing Colima (save | ssh | load | push)

On the server, set `insecure-registries` once, then:

```bash
chmod +x push-via-ssh.sh
HARBOR_PROJECT=demo HARBOR_REPO=20klogregchallenge ./push-via-ssh.sh /path/to/Dockerfile/dir
```

Or manually:

```bash
docker build --platform linux/amd64 -t YOUR_HOSTNAME/demo/myimage:latest .
docker save YOUR_HOSTNAME/demo/myimage:latest | ssh user@YOUR_HOSTNAME 'docker load && docker push YOUR_HOSTNAME/demo/myimage:latest'
```

### setup-harbor.sh fixes (same-file cp / ssl_cert error)

- **Install dir** is always `$SCRIPT_DIR/harbor-install` so extract tree is not confused with `harbor.yml` in the repo.
- **harbor.yml** is written with `cat > harbor.yml` so `cp` never hits “same file”.
- **127.0.0.1 / localhost** as hostname is rejected.
- If the template is used, the **https** block is commented so **prepare** does not fail with `ssl_cert is not set`.

---

## Production: HTTPS (recommended link)

So the link is **`https://your-domain`** without browser warnings (or with a trusted CA):

1. Follow [Configure HTTPS Access to Harbor](https://goharbor.io/docs/2.14.0/install-config/configure-https/) (cert + key paths in `harbor.yml`).
2. In `harbor.yml`, use `https:` with `certificate` and `private_key`; comment out or adjust `http:` as per docs.
3. Run `./prepare`, then `docker compose down -v` and `docker compose up -d`.

---

## Requirements

- Docker 20.10+, Docker Compose v2+
- 4GB+ RAM, 40GB+ disk
- Ports **80** (HTTP) and/or **443** (HTTPS) – NGINX serves the Portal on these ports

---

## Official links (2.14.0)

- [Installation and Configuration](https://goharbor.io/docs/2.14.0/install-config/)
- [Configure the Harbor YML File](https://goharbor.io/docs/2.14.0/install-config/configure-yml-file/)
- [Run the Installer Script](https://goharbor.io/docs/2.14.0/install-config/run-installer-script/)
- [Configure HTTPS](https://goharbor.io/docs/2.14.0/install-config/configure-https/)
- [Harbor Releases](https://github.com/goharbor/harbor/releases) – if `v2.14.0` is not available yet, use e.g. `HARBOR_VERSION=v2.13.5 ./setup-harbor.sh ...`

---

## Flow diagram

```
harbor.yml hostname  →  NGINX (port 80/443)  →  Harbor Portal (web UI)
                              ↓
                    docker login / push / pull
```

Your setup script/playbook follows the same path as the official installer; the **link** is always `http(s)://<hostname>` from `harbor.yml`.
