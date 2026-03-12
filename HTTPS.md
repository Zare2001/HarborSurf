# Configure HTTPS on Harbor (no `insecure-registries`)

When Harbor serves **HTTPS on 443** with a certificate your clients trust, `docker login` uses normal TLS and you **do not** need `insecure-registries`.

**Where to edit:** On the **server**, in the directory where Harbor was installed — usually:

```text
~/HarborSurf/harbor-install/harbor/harbor.yml
```

(or wherever you ran `./prepare` / `./install.sh`).

Your repo’s `harbor.yml` already has the block — uncomment it and set **absolute paths**:

```yaml
hostname: 145.38.204.113   # or your FQDN — must match cert SAN

http:
  port: 80                 # optional: keep for redirect or comment out per docs

https:
  port: 443
  certificate: /data/cert/server.crt
  private_key: /data/cert/server.key
```

Paths must exist **on the host** before `./prepare`; the installer mounts them into the nginx container.

**Valid full example:** see **`harbor.yml.https.example`** in the repo — copy it only after `server.crt` and `server.key` exist under `/data/cert/`.

---

## Recovery: `prepare` failed + `docker compose up` → env not found

If `./prepare` crashed with **YAML ParserError** and you already ran **`docker compose down`**, the generated configs under `common/config/` are missing. **Do not** run `docker compose up -d` alone.

1. **Fix `harbor.yml`** — must be valid YAML. Typical mistakes:
   - Uncommented `https:` but left `certificate:` / `private_key:` commented → broken mapping.
   - Duplicate `http:` or `https:` keys.
   - Tabs instead of spaces.

2. **Quick restore HTTP-only** (get Harbor back up), then re-apply HTTPS carefully:

   ```bash
   cd ~/HarborSurf
   # Restore from repo (HTTP only)
   cat harbor.yml | sed 's/YOUR_SERVER_IP/145.38.204.113/g' | sudo tee ~/HarborSurf/harbor-install/harbor/harbor.yml
   cd ~/HarborSurf/harbor-install/harbor
   sudo ./install.sh
   ```

   `install.sh` runs `prepare` and starts all containers.

3. **When certs are ready**, edit `harbor-install/harbor/harbor.yml` using **`harbor.yml.https.example`** as reference, then:

   ```bash
   cd ~/HarborSurf/harbor-install/harbor
   sudo ./prepare
   sudo ./install.sh
   ```

---

## 1. Get a certificate and key

### Option A — Domain + Let’s Encrypt (best for “normal” HTTPS)

If you have a **DNS name** pointing to the server (e.g. `registry.example.com`):

```bash
sudo apt install -y certbot
sudo certbot certonly --standalone -d registry.example.com
```

Certs are typically:

- `/etc/letsencrypt/live/registry.example.com/fullchain.pem` → use as **certificate**
- `/etc/letsencrypt/live/registry.example.com/privkey.pem` → use as **private_key**

Set `hostname: registry.example.com` in `harbor.yml` to match the cert.

Renewal: renew certs then `docker compose restart` (or re-run `prepare` if nginx config embeds paths that change).

### Option B — Self-signed (dev only; clients must trust your CA)

Harbor docs use OpenSSL to create a CA and a **server cert whose SAN matches how clients connect** (FQDN or IP).

**If clients connect by IP**, the cert must include that IP in Subject Alternative Name, e.g.:

```bash
sudo mkdir -p /data/cert
cd /data/cert

# 1) CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 \
  -subj "/CN=Harbor Dev CA" -key ca.key -out ca.crt

# 2) Server key + CSR (replace IP)
openssl genrsa -out server.key 4096
openssl req -new -sha512 -key server.key -out server.csr \
  -subj "/CN=145.38.204.113"

# 3) SAN file — include IP (and DNS if you use hostname)
cat > v3.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
IP.1 = 145.38.204.113
# DNS.1 = registry.example.com
EOF

openssl x509 -req -sha512 -days 3650 -extfile v3.ext \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -in server.csr -out server.crt
```

Then in `harbor.yml`:

```yaml
hostname: 145.38.204.113
https:
  port: 443
  certificate: /data/cert/server.crt
  private_key: /data/cert/server.key
```

**Self-signed caveat:** Browsers and Docker will not trust the cert until you install **ca.crt** as trusted (or use `/etc/docker/certs.d/` — see below). For **no** client-side hacks, use Let’s Encrypt or a corporate CA.

---

## 2. Docker daemon trust (self-signed or private CA)

Official layout when the registry cert is **not** from a public CA:

```bash
# On each machine that runs docker login/push/pull
sudo mkdir -p /etc/docker/certs.d/145.38.204.113
sudo cp /data/cert/server.crt /etc/docker/certs.d/145.38.204.113/ca.crt
# Or copy your CA:
# sudo cp ca.crt /etc/docker/certs.d/145.38.204.113/ca.crt
```

If Harbor listens on a **non-default HTTPS port**:

```text
/etc/docker/certs.d/145.38.204.113:8443/ca.crt
```

Then:

```bash
sudo systemctl restart docker   # Linux
# Docker Desktop: restart from GUI
```

With **Let’s Encrypt**, you usually **skip** `certs.d` — the system trust store is enough.

---

## 3. Apply config and restart Harbor

On the **server**, in the Harbor install directory:

```bash
cd ~/HarborSurf/harbor-install/harbor   # adjust if different

# Edit harbor.yml: hostname + https.certificate + https.private_key
sudo nano harbor.yml

sudo ./prepare
sudo docker compose down    # down -v only if you intend to wipe volumes
sudo docker compose up -d
```

Official doc uses `docker compose down -v` when **reconfiguring** — that **removes named volumes**; use **without `-v`** if you want to keep Harbor DB/data.

Open **`https://<hostname>`** (or `https://IP` if cert SAN includes IP). Login as before.

---

## 4. Client usage after HTTPS

```bash
docker login 145.38.204.113
# or
docker login registry.example.com
```

Image tags stay **without** `https://`:

```bash
docker build -t 145.38.204.113/demo/myimage:latest .
docker push 145.38.204.113/demo/myimage:latest
docker pull 145.38.204.113/demo/myimage:latest
```

Remove that host from **`insecure-registries`** in `/etc/docker/daemon.json` once HTTPS works with a trusted cert.

---

## 5. HarborSurf `setup-harbor.sh` note

Fresh install from the script **comments out** the `https` block when no custom `harbor.yml` is present (to avoid `ssl_cert is not set`). To use HTTPS:

1. Put certs on the server under fixed paths (e.g. `/data/cert/`).
2. Edit **`HarborSurf/harbor.yml`** in the repo: uncomment `https:` and set `certificate` / `private_key`.
3. Run `./setup-harbor.sh <hostname>` again **or** copy that `harbor.yml` into `harbor-install/harbor/` and run `./prepare` + `docker compose up -d`.

---

## Reference

- [Configure HTTPS Access to Harbor](https://goharbor.io/docs/2.14.0/install-config/configure-https/)
- [Configure the Harbor YML File](https://goharbor.io/docs/2.14.0/install-config/configure-yml-file/)
