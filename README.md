# Proxmox LXC Templates

Automated weekly builds of minimal Proxmox-compatible LXC container templates with SSH pre-configured.

## Templates

| Template | Base | Architecture |
|----------|------|--------------|
| `debian-13-ssh` | Debian 13 (Trixie) | amd64 |
| `alpine-3.23-ssh` | Alpine 3.23 | x86_64 |
| `alpine-edge-ssh` | Alpine Edge | x86_64 |

All templates include:
- OpenSSH server installed and enabled at boot
- Root login permitted via password
- SSH host keys regenerated on first boot (not pre-baked)

## Default credentials

| User | Password |
|------|----------|
| root | root |

**Change the root password immediately after deployment.**

## Usage

Download a template from the [Releases](../../releases) page and upload it to your Proxmox host:

```bash
# Upload to Proxmox template storage
scp debian-13-ssh_2026.5.3_amd64.tar.xz root@proxmox:/var/lib/vz/template/cache/

# Create a container
pct create 100 /var/lib/vz/template/cache/debian-13-ssh_2026.5.3_amd64.tar.xz \
  --rootfs local:8 --memory 512 --net0 name=eth0,bridge=vmbr0,ip=dhcp

# Start and connect
pct start 100
pct enter 100
```

## Versioning

Releases use the format `year.month.week_of_month`:

- `2026.5.3` — year 2026, May, 3rd week
- `2026.1.1` — year 2026, January, 1st week

Week of month is calculated as `ceil(day / 7)`:
- Days 1–7 → week 1
- Days 8–14 → week 2
- Days 15–21 → week 3
- Days 22–28 → week 4
- Days 29–31 → week 5

## Manual release

Trigger a manual build from the Actions tab using "Run workflow". Optionally provide a `version_override` to set a custom version string.

## Build schedule

Automated builds run every Monday at 02:00 UTC.
