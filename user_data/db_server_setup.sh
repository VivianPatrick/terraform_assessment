#!/bin/bash
# db_server_setup.sh
# Installs PostgreSQL 14 on Amazon Linux 2 and creates a techcorp database + user.
# Templated variable: ${password} is injected by Terraform templatefile()

set -euxo pipefail

# ── 1. Enable password authentication for ec2-user ──────────────────────────
echo "ec2-user:${password}" | chpasswd
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# ── 2. Install PostgreSQL 14 via the official PGDG repo ─────────────────────
yum update -y
amazon-linux-extras enable postgresql14
yum install -y postgresql-server postgresql

# ── 3. Initialise the database cluster ───────────────────────────────────────
postgresql-setup initdb

# ── 4. Allow password-based (md5) connections from the VPC ───────────────────
PG_HBA="/var/lib/pgsql/data/pg_hba.conf"

# Replace the default ident/peer entries with md5 for local TCP connections
sed -i 's/^host.*all.*all.*127.0.0.1\/32.*ident/host    all             all             127.0.0.1\/32            md5/' "$PG_HBA"
sed -i 's/^host.*all.*all.*::1\/128.*ident/host    all             all             ::1\/128                 md5/' "$PG_HBA"

# Allow connections from the entire VPC CIDR (10.0.0.0/16)
echo "host    all             all             10.0.0.0/16             md5" >> "$PG_HBA"

# Tell PostgreSQL to listen on all interfaces (needed for VPC access)
PG_CONF="/var/lib/pgsql/data/postgresql.conf"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

# ── 5. Start and enable PostgreSQL ───────────────────────────────────────────
systemctl start postgresql
systemctl enable postgresql

# ── 6. Create application database and user ───────────────────────────────────
sudo -u postgres psql <<SQL
-- Create the application database
CREATE DATABASE techcorp_db;

-- Create a dedicated app user
CREATE USER techcorp_user WITH ENCRYPTED PASSWORD '${password}';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE techcorp_db TO techcorp_user;

-- Verify
\l
SQL

echo "PostgreSQL setup complete. Connect with:"
echo "  psql -h localhost -U techcorp_user -d techcorp_db"
