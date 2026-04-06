#!/bin/bash
# web_server_setup.sh
# Installs Apache, enables it, and serves a simple page showing the instance ID.
# Templated variable: ${password} is injected by Terraform templatefile()

set -euxo pipefail

# ── 1. Enable password authentication for ec2-user ──────────────────────────
echo "ec2-user:${password}" | chpasswd
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# ── 2. Install and start Apache ──────────────────────────────────────────────
yum update -y
yum install -y httpd

systemctl start httpd
systemctl enable httpd

# ── 3. Fetch the instance ID from the metadata service ───────────────────────
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# ── 4. Create a simple HTML page ─────────────────────────────────────────────
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>TechCorp Web Server</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f6f9; display: flex;
           justify-content: center; align-items: center; height: 100vh; margin: 0; }
    .card { background: white; padding: 2rem 3rem; border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1); text-align: center; }
    h1    { color: #2563eb; }
    p     { color: #374151; font-size: 1.1rem; }
    .badge { display: inline-block; background: #dbeafe; color: #1d4ed8;
             padding: 0.3rem 0.8rem; border-radius: 20px; font-weight: bold; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🚀 TechCorp Web Server</h1>
    <p>Instance ID: <span class="badge">$INSTANCE_ID</span></p>
    <p>Availability Zone: <span class="badge">$AZ</span></p>
    <p>Powered by Apache on Amazon Linux 2</p>
  </div>
</body>
</html>
HTML

# Ensure Apache owns the file
chown apache:apache /var/www/html/index.html
