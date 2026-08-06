# How To: Harden a Kamal Server

Checklist for securing a new Kamal deployment on Hetzner Cloud (or similar VPS).

## Steps

### 1. Enable UFW and allow SSH

```bash
ufw allow 22/tcp
ufw enable
```

### 2. Harden SSH

```bash
# Disable password authentication
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Install fail2ban
apt-get install -y fail2ban
systemctl enable --now fail2ban
```

Keep an existing SSH session open when restarting sshd.

### 3. Lock down PostgreSQL

Ensure `deploy.yml` binds to localhost:

```yaml
accessories:
  db:
    port: "127.0.0.1:5432:5432"
```

If the accessory was already deployed with `5432:5432`, reboot it:

```bash
kamal accessory reboot db
```

Block externally via firewall:

```bash
ufw deny from any to any port 5432
```

### 4. Set up Cloudflare

1. Add domain to Cloudflare (free tier)
2. Update nameservers at registrar
3. Set SSL mode to **Full (Strict)**
4. Enable **Bot Fight Mode**

### 5. Restrict HTTP/HTTPS to Cloudflare IPs

```bash
# IPv4 (from https://www.cloudflare.com/ips-v4/)
ufw allow from 173.245.48.0/20 to any port 80,443 proto tcp
ufw allow from 103.21.244.0/22 to any port 80,443 proto tcp
ufw allow from 103.22.200.0/22 to any port 80,443 proto tcp
ufw allow from 103.31.4.0/22 to any port 80,443 proto tcp
ufw allow from 141.101.64.0/18 to any port 80,443 proto tcp
ufw allow from 108.162.192.0/18 to any port 80,443 proto tcp
ufw allow from 190.93.240.0/20 to any port 80,443 proto tcp
ufw allow from 188.114.96.0/20 to any port 80,443 proto tcp
ufw allow from 197.234.240.0/22 to any port 80,443 proto tcp
ufw allow from 198.41.128.0/17 to any port 80,443 proto tcp
ufw allow from 162.158.0.0/15 to any port 80,443 proto tcp
ufw allow from 104.16.0.0/13 to any port 80,443 proto tcp
ufw allow from 104.24.0.0/14 to any port 80,443 proto tcp
ufw allow from 172.64.0.0/13 to any port 80,443 proto tcp
ufw allow from 131.0.72.0/22 to any port 80,443 proto tcp

# IPv6 (from https://www.cloudflare.com/ips-v6/)
ufw allow from 2400:cb00::/32 to any port 80,443 proto tcp
ufw allow from 2606:4700::/32 to any port 80,443 proto tcp
ufw allow from 2803:f800::/32 to any port 80,443 proto tcp
ufw allow from 2405:b500::/32 to any port 80,443 proto tcp
ufw allow from 2405:8100::/32 to any port 80,443 proto tcp
ufw allow from 2a06:98c0::/29 to any port 80,443 proto tcp
ufw allow from 2c0f:f248::/32 to any port 80,443 proto tcp

# Block everything else on 80/443
ufw deny to any port 80 proto tcp
ufw deny to any port 443 proto tcp
```

**Verify order** with `ufw status numbered` — allows must come before denies.

**Important:** UFW alone does NOT protect Docker-published ports. Docker's iptables chains run before ufw. You must also add rules to the `DOCKER-USER` chain:

```bash
# Allow Cloudflare IPs to Docker ports
iptables -I DOCKER-USER -s 173.245.48.0/20 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 103.21.244.0/22 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 103.22.200.0/22 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 103.31.4.0/22 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 141.101.64.0/18 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 108.162.192.0/18 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 190.93.240.0/20 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 188.114.96.0/20 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 197.234.240.0/22 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 198.41.128.0/17 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 162.158.0.0/15 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 104.16.0.0/13 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 104.24.0.0/14 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 172.64.0.0/13 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -I DOCKER-USER -s 131.0.72.0/22 -p tcp -m multiport --dports 80,443 -j ACCEPT

# Allow internal Docker bridge traffic
iptables -I DOCKER-USER -s 172.18.0.0/16 -j ACCEPT

# Drop external traffic only (eth0) — don't block Docker-to-Docker or outbound
# Without -i eth0, this breaks Docker buildx, image pulls, etc.
iptables -A DOCKER-USER -i eth0 -p tcp -m multiport --dports 80,443 -j DROP
iptables -A DOCKER-USER -i eth0 -p tcp --dport 5432 -j DROP

# Persist across reboots
apt-get install -y iptables-persistent
netfilter-persistent save
```

### 6. Configure Rails

In `config/environments/production.rb`:

```ruby
# Remove direct IP from allowed hosts
config.hosts = [
  "yourdomain.com",
  /.*\.yourdomain\.com/
]

# CDN asset host (add CNAME in Cloudflare: assets -> yourdomain.com, proxied)
config.asset_host = ENV.fetch("ASSET_HOST", "https://assets.yourdomain.com")
```

In `config/deploy.yml`:

```yaml
env:
  clear:
    ASSET_HOST: https://assets.yourdomain.com
```

### 7. Deploy and verify

```bash
kamal deploy

# Through Cloudflare (should return 200)
curl -I https://yourdomain.com/up

# Direct IP (should timeout/refuse)
curl -I --max-time 5 https://YOUR_SERVER_IP/up --insecure
```

## Ongoing Maintenance

- Review `journalctl -u ssh | grep "Failed password"` periodically
- Check `ufw status numbered` after system updates
- Monitor Cloudflare analytics for bot traffic patterns
- Cloudflare IP ranges may change — re-check quarterly at cloudflare.com/ips
