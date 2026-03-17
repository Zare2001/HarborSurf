## HarborSurf (minimal)

Minimal files to deploy a Harbor Docker registry on a server.

- `ansible-playbook.yml`: Ansible playbook that installs Harbor using the official installer.
- `inventory.ini.example`: Copy to `inventory.ini` and set your server host, SSH user and key.
- `harbor.yml`: Base Harbor configuration (set the `hostname` here).
- `setup-harbor.sh`: Shell script to run the installer directly on the server.
- `templates/harbor.yml.j2`: Jinja template used by the playbook to generate `harbor.yml`.

### 1. SSH / inventory

First, make sure you can SSH into the server manually. For example:

```bash
ssh -i ~/.ssh/your-rc-key ubuntu@YOUR_SERVER_IP
```

Then configure Ansible to use the **same** user and key:

```ini
# inventory.ini
[harbor_servers]
harbor-server ansible_host=YOUR_SERVER_IP ansible_user=ubuntu

[all:vars]
ansible_ssh_private_key_file=~/.ssh/your-rc-key
```

### 2. Install Harbor via Ansible

```bash
cp inventory.ini.example inventory.ini    # or edit directly
ansible-playbook -i inventory.ini ansible-playbook.yml -e "harbor_hostname=YOUR_SERVER_IP"
```

After the playbook completes, open in a browser:

```text
http://YOUR_SERVER_IP
```

Login: `admin` / `Harbor12345` (change immediately in the UI).

### 3. Install Harbor via shell script (alternative)

Run directly on the server (after editing `harbor.yml` and setting `hostname`):

```bash
chmod +x setup-harbor.sh
./setup-harbor.sh YOUR_SERVER_IP
```

Then open `http://YOUR_SERVER_IP` in a browser.

