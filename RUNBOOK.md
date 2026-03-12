# HarborSurf — Runbook (manual server install + push/pull)

End-to-end steps to run Harbor **without** the Research Cloud plugin, then **push** and **pull** images.

Replace **`145.38.205.248`** with your server’s IP or DNS name everywhere it appears.

---

## 1. Prerequisites

- **Linux server** (e.g. Ubuntu 22.04) with **sudo**
- **Docker** + **Docker Compose v2**
- **Inbound TCP 80** (and **443** if you use HTTPS later)
- **Outbound** internet (installer pulls images from Docker Hub)

---

## 2. Get HarborSurf on the server

**Option A — Git**

```bash
ssh user@YOUR_SERVER_IP
sudo apt update && sudo apt install -y git curl
git clone https://github.com/Zare2001/HarborSurf.git
cd HarborSurf
```

**Option B — Copy from your Mac**

```bash
scp -r /path/to/HarborSurf user@YOUR_SERVER_IP:~/
ssh user@YOUR_SERVER_IP
cd ~/HarborSurf
```

---

## 3. Install Docker (if needed)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# log out and back in
docker compose version
```

If `docker-compose-plugin` is missing on Ubuntu, use [Docker’s apt repo](https://docs.docker.com/engine/install/ubuntu/).

---

## 4. Allow HTTP registry on this host

Docker defaults to **HTTPS** for registries. Harbor is **HTTP** on port **80** until you configure HTTPS. Without this step, `docker login` tries **port 443** and fails.

```bash
cd ~/HarborSurf
sudo chmod +x init.sh setup-harbor.sh
sudo HARBOR_HOSTNAME=145.38.205.248 ./init.sh
```

Use the **same** address you will open in the browser (not `127.0.0.1`).

---

## 5. Install Harbor

```bash
cd ~/HarborSurf
nano harbor.yml
# set: hostname: 145.38.205.248
# keep https: commented out unless you have cert paths
./setup-harbor.sh 145.38.205.248
```

Wait until **Harbor has been installed and started successfully.**

- **UI:** `http://145.38.205.248`
- **Login:** `admin` / `Harbor12345` → change password in UI

---

## 6. Undo / redo

**Stop only (keep data):**

```bash
cd ~/HarborSurf/harbor-install/harbor
sudo docker compose down
sudo docker compose up -d
```

**Wipe Harbor data and reinstall:**

```bash
cd ~/HarborSurf/harbor-install/harbor
sudo docker compose down -v
cd ~/HarborSurf
rm -rf harbor-install
./setup-harbor.sh 145.38.205.248
```

---

## 7. Change hostname later

```bash
cd ~/HarborSurf/harbor-install/harbor
sudo nano harbor.yml
# hostname: NEW_IP_OR_DNS
sudo ./prepare
sudo docker compose down
sudo docker compose up -d
```

If the **host** string changed, run **`init.sh`** again with the new value:

```bash
cd ~/HarborSurf
sudo HARBOR_HOSTNAME=NEW_IP_OR_DNS ./init.sh
```

---

## 8. Projects — UI (recommended)

Harbor does **not** require a `harbor` CLI for normal use.

1. Open `http://145.38.205.248`
2. Log in as **admin**
3. **Projects → New Project**
4. Name: **`demo`** (or any name)
5. Access: **Private** or **Public**
6. Your user needs **Developer** or **Maintainer** to **push**

If you use a **Harbor CLI** (`harbor login` / `harbor project create`), it must target the **registry host without `http://`** where the tool supports it — many tools expect:

```text
145.38.205.248
```

not `http://145.38.205.248/`.

---

## 9. Push / pull — **correct Docker syntax**

Image references are **not URLs**. Do **not** use `http://` in tags.

**Format:**

```text
HOST/PROJECT/REPOSITORY:TAG
```

- **HOST** = `145.38.205.248` (no scheme, no trailing `/`)
- **PROJECT** = Harbor project name (e.g. `demo`)
- **REPOSITORY** = image name (e.g. `20klogregchallenge`)
- **TAG** = e.g. `latest`

**Wrong:**

```bash
docker login http://145.38.205.248/
docker push http://145.38.205.248/harbor/demo/20klogregchallenge:latest
```

**Right:**

```bash
docker login 145.38.205.248
docker build --platform linux/amd64 -t 145.38.205.248/demo/20klogregchallenge:latest .
docker push 145.38.205.248/demo/20klogregchallenge:latest
```

There is no extra `harbor/` segment unless you literally created a project named `harbor` and a repo path under it. Standard layout is **`HOST/demo/20klogregchallenge:latest`**.

### On the Harbor server (after `init.sh`)

```bash
docker login 145.38.205.248
# username: admin (or robot account), password from UI
docker pull hello-world
docker tag hello-world 145.38.205.248/demo/hello:latest
docker push 145.38.205.248/demo/hello:latest
docker pull 145.38.205.248/demo/hello:latest
```

### From your Mac (Colima / Docker Desktop)

If `docker login 145.38.205.248` fails with **connection refused on 443**, either:

- Add **`145.38.205.248`** to **`insecure-registries`** in the **daemon** that runs your `docker` commands (Colima: inside the VM’s `/etc/docker/daemon.json`), **or**
- Use **push-via-ssh** from the repo:

```bash
cd ~/HarborSurf   # on Mac
HARBOR_PROJECT=demo HARBOR_REPO=20klogregchallenge REGISTRY_HOST=145.38.205.248 SSH_USER_HOST=zpalanciya@145.38.205.248 ./push-via-ssh.sh /path/to/Dockerfile/dir
```

---

## 10. Read-only / no push access

If **push** returns **denied** / **unauthorized**:

- In Harbor UI: **Project → Members** → your user must be **Developer** or **Maintainer**
- Create your own **project** and push there, or ask an admin for a project with push rights

---

## 11. Quick reference

| Task | Command / location |
|------|---------------------|
| UI | `http://HOST` |
| Login (docker) | `docker login HOST` |
| Tag | `HOST/project/repo:tag` |
| Push | `docker push HOST/project/repo:tag` |
| Pull | `docker pull HOST/project/repo:tag` |
| HTTP on client | `insecure-registries: ["HOST"]` + restart docker |
| Server prep | `sudo HARBOR_HOSTNAME=HOST ./init.sh` |
| Install | `./setup-harbor.sh HOST` |

---

## 12. If you still use `harbor` CLI

If your environment provides `harbor login` / `harbor project create`, use the **registry host only** when the CLI asks for a server:

```bash
harbor login 145.38.205.248
harbor project create demo --public=false
```

Avoid `http://` unless the tool’s docs explicitly require it. Docker **build/push** always use **`HOST/project/repo:tag`** without `http://`.
