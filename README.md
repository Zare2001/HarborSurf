# Harbor Container Registry Setup

Deploy [Harbor](https://goharbor.io/) to host Docker images on your own server. Harbor is an open-source, enterprise-grade container registry with vulnerability scanning, RBAC, and replication.

## Quick Start

### Option 1: Shell Script (Docker Compose / Bash)

1. **Edit `harbor.yml`** – Replace `YOUR_SERVER_IP` with your server IP or hostname:
   ```yaml
   hostname: 192.168.1.100  # Your server IP
   ```

2. **Run the setup script** on your server:
   ```bash
   chmod +x setup-harbor.sh
   ./setup-harbor.sh 192.168.1.100
   ```

3. **Configure Docker** (for HTTP access) – Add to `/etc/docker/daemon.json`:
   ```json
   {
     "insecure-registries": ["192.168.1.100"]
   }
   ```
   Then: `sudo systemctl restart docker`

4. **Access Harbor** at `http://YOUR_SERVER_IP` – Login: `admin` / `Harbor12345`

### Option 2: Ansible Playbook

1. Copy and edit inventory:
   ```bash
   cp inventory.ini.example inventory.ini
   # Edit inventory.ini with your server IP and SSH user
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory.ini ansible-playbook.yml -e "harbor_hostname=192.168.1.100"
   ```

## Script Type Selection

When your system asks for script type, use:

| Type | Use Case |
|------|----------|
| **Docker Compose** | Harbor is deployed via Docker Compose. The setup script downloads the official installer, which generates `docker-compose.yml` and starts all services. |
| **Ansible Playbook** | Use `ansible-playbook.yml` to deploy Harbor to remote Linux servers. |
| **Docker** | Not applicable – Harbor runs as multiple containers, not a single Dockerfile. |

## Files

| File | Description |
|------|-------------|
| `harbor.yml` | Main Harbor configuration – set `hostname` to your server IP |
| `setup-harbor.sh` | Downloads Harbor installer, configures, and installs |
| `ansible-playbook.yml` | Ansible playbook for remote deployment |
| `harbor.yml.j2` | Jinja2 template for Ansible |
| `inventory.ini.example` | Example Ansible inventory |

## Push Images to Harbor

```bash
# Login
docker login YOUR_SERVER_IP

# Create a project in Harbor UI first (e.g., "library" or "myproject")

# Tag and push
docker tag myimage:latest YOUR_SERVER_IP/myproject/myimage:latest
docker push YOUR_SERVER_IP/myproject/myimage:latest
```

## Production: HTTPS

For production, use HTTPS:

1. Obtain SSL certificates (e.g., Let's Encrypt or your CA).
2. In `harbor.yml`, comment out `http` and enable `https`:
   ```yaml
   # http:
   #   port: 80

   https:
     port: 443
     certificate: /path/to/certificate.crt
     private_key: /path/to/private.key
   ```
3. Re-run `./prepare` and restart: `docker compose down && docker compose up -d`

## Requirements

- Docker 20.10+
- Docker Compose v2+
- 4GB+ RAM, 40GB+ disk
- Ports 80 (HTTP) and/or 443 (HTTPS)

## Links

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor GitHub](https://github.com/goharbor/harbor)
- [Harbor Releases](https://github.com/goharbor/harbor/releases)


Your machine                    Server (with Harbor)
     |                                    |
     |  1. Run setup-harbor.sh            |
     |  (or Ansible playbook)             |
     |----------------------------------->|  Harbor installed
     |                                    |
     |  2. docker login SERVER_IP         |
     |----------------------------------->|  Authenticate
     |                                    |
     |  3. docker push SERVER_IP/project/image:tag
     |----------------------------------->|  Images stored
     |                                    |
     |  4. docker pull SERVER_IP/project/image:tag
     |<-----------------------------------|  Retrieve images