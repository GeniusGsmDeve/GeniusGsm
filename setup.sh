#!/usr/bin/env bash
set -euo pipefail

# TempMail setup script for Ubuntu 22.04.5
# Usage (run as the server user):
#   cd /home/TempMail/tempmail
#   ./setup.sh DOMAIN=mail.example.com DB_PASS=secret EMAIL=you@example.com
# The script will use sudo for privileged operations and will add a sudoers file
# granting the run user passwordless sudo (full) so services can be managed.

PROJECT_DIR="/home/TempMail/tempmail/src"
BASE_DIR="/home/TempMail/tempmail"
VENV_DIR="${BASE_DIR}/.venv"
DOMAIN="${DOMAIN:-mail.geniusgsm.com}"
DB_NAME="${DB_NAME:-TempMail}"
DB_USER="${DB_USER:-tempmail}"
DB_PASS="${DB_PASS:-tempmail}"
ADMIN_EMAIL="${EMAIL:-}"
PYTHON_BIN="/usr/bin/python3"

RUN_USER="${RUN_USER:-$(whoami)}"

echo "Target run user: ${RUN_USER}"

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required but not installed. Installing sudo..."
  apt-get update
  apt-get install -y sudo
fi

echo "The script will use sudo for privileged operations. You may be prompted for your password."

echo "--- Updating packages and installing prerequisites ---"
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip build-essential libpq-dev postgresql postgresql-contrib nginx certbot python3-certbot-nginx git

echo "--- Creating virtualenv ---"
if [ ! -d "${VENV_DIR}" ]; then
  mkdir -p "${BASE_DIR}"
  ${PYTHON_BIN} -m venv "${VENV_DIR}"
fi
export PATH="${VENV_DIR}/bin:${PATH}"

echo "--- Installing Python requirements ---"
pip install --upgrade pip
if [ -f "${PROJECT_DIR}/requirements.txt" ]; then
  pip install -r "${PROJECT_DIR}/requirements.txt"
else
  echo "requirements.txt not found; skipping pip installs."
fi

echo "--- Setting up PostgreSQL user and database ---"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<-SQL || true
DO
\$\$BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
      CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
   END IF;
END\$\$;
SQL
# Create DB if not exists (ignore error if exists)
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" || true

echo "--- Writing .env file ---"
ENV_FILE="${PROJECT_DIR}/.env"
mkdir -p "$(dirname "${ENV_FILE}")"
cat > "${ENV_FILE}" <<EOF
SECRET_KEY=$(python - <<PY
import secrets
print(secrets.token_urlsafe(50))
PY
)
DEBUG=False
ALLOWED_HOSTS=${DOMAIN}
DATABASE_NAME=${DB_NAME}
DATABASE_USER=${DB_USER}
DATABASE_PASSWORD=${DB_PASS}
DATABASE_HOST=localhost
DATABASE_PORT=5432
SMTP_PORT=25
EOF

chown ${RUN_USER}:${RUN_USER} "${ENV_FILE}" || true
chmod 640 "${ENV_FILE}"

echo "--- Django migrations and static files ---"
cd "${PROJECT_DIR}"
${VENV_DIR}/bin/python manage.py makemigrations || true
${VENV_DIR}/bin/python manage.py migrate --no-input
${VENV_DIR}/bin/python manage.py collectstatic --no-input

echo "--- Creating systemd service files (running as ${RUN_USER}) ---"
WEB_SERVICE="/etc/systemd/system/tempmail-web.service"
sudo bash -c "cat > \"${WEB_SERVICE}\" <<'UNIT'
[Unit]
Description=TempMail Gunicorn
After=network.target

[Service]
User=${RUN_USER}
Group=${RUN_USER}
WorkingDirectory=/home/TempMail/tempmail/src
EnvironmentFile=/home/TempMail/tempmail/src/.env
ExecStart=/home/TempMail/tempmail/.venv/bin/gunicorn project.wsgi:application --bind unix:/run/tempmail.sock --workers 3
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
"

SMTP_SERVICE="/etc/systemd/system/tempmail-smtp.service"
sudo bash -c "cat > \"${SMTP_SERVICE}\" <<'UNIT'
[Unit]
Description=TempMail SMTP receiver
After=network.target

[Service]
User=${RUN_USER}
Group=${RUN_USER}
WorkingDirectory=/home/TempMail/tempmail/src
EnvironmentFile=/home/TempMail/tempmail/src/.env
ExecStart=/home/TempMail/tempmail/.venv/bin/python /home/TempMail/tempmail/src/smtp_receiver.py
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
"

echo "--- Reloading systemd and enabling services ---"
sudo systemctl daemon-reload
sudo systemctl enable --now tempmail-web.service || true
sudo systemctl enable --now tempmail-smtp.service || true

echo "--- Configuring nginx ---"
NGINX_SITE="/etc/nginx/sites-available/tempmail"
sudo bash -c "cat > \"${NGINX_SITE}\" <<NGCONF
server {
    listen 80;
    server_name ${DOMAIN};

    location /static/ {
        alias ${PROJECT_DIR}/static/;
    }

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://unix:/run/tempmail.sock;
    }
}
NGCONF
"

sudo ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/tempmail
sudo nginx -t
sudo systemctl restart nginx

if [ -n "${ADMIN_EMAIL}" ]; then
  echo "--- Obtaining TLS cert with certbot ---"
  sudo certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email "${ADMIN_EMAIL}"
fi

echo "--- Granting ${RUN_USER} passwordless sudo (full) via /etc/sudoers.d/tempmail ---"
sudo bash -c "cat > /etc/sudoers.d/tempmail <<S
${RUN_USER} ALL=(ALL) NOPASSWD:ALL
S
"
sudo chmod 440 /etc/sudoers.d/tempmail

echo "--- Setup complete ---"
sudo systemctl status tempmail-web.service --no-pager -n 5 || true
sudo systemctl status tempmail-smtp.service --no-pager -n 5 || true
echo "Visit: http://${DOMAIN}/ (or https if cert obtained)"

exit 0
#!/usr/bin/env bash
set -euo pipefail

# TempMail setup script for Debian/Ubuntu Linux
# Usage: sudo ./setup.sh DOMAIN=mail.example.com DB_PASS=secret EMAIL=you@example.com

PROJECT_DIR="/home/TempMail/tempmail/src"
BASE_DIR="/home/TempMail/tempmail"
VENV_DIR="${BASE_DIR}/.venv"
DOMAIN="${DOMAIN:-mail.geniusgsm.com}"
DB_NAME="${DB_NAME:-TempMail}"
DB_USER="${DB_USER:-tempmail}"
DB_PASS="${DB_PASS:-tempmail}"
ADMIN_EMAIL="${EMAIL:-}"
PYTHON_BIN="/usr/bin/python3"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "--- Updating packages and installing prerequisites ---"
apt-get update
apt-get install -y python3 python3-venv python3-pip build-essential libpq-dev postgresql postgresql-contrib nginx certbot python3-certbot-nginx git

echo "--- Creating virtualenv ---"
if [ ! -d "${VENV_DIR}" ]; then
  mkdir -p "${BASE_DIR}"
  ${PYTHON_BIN} -m venv "${VENV_DIR}"
fi
export PATH="${VENV_DIR}/bin:${PATH}"

echo "--- Installing Python requirements ---"
pip install --upgrade pip
pip install -r "${PROJECT_DIR}/requirements.txt"

echo "--- Setting up PostgreSQL user and database ---"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<-SQL || true
DO
\$\$BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
      CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
   END IF;
END\$\$;
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
SQL

echo "--- Writing .env file ---"
ENV_FILE="${PROJECT_DIR}/.env"
cat > "${ENV_FILE}" <<EOF
SECRET_KEY=$(python - <<PY
import secrets
print(secrets.token_urlsafe(50))
PY
)
DEBUG=False
ALLOWED_HOSTS=${DOMAIN}
DATABASE_NAME=${DB_NAME}
DATABASE_USER=${DB_USER}
DATABASE_PASSWORD=${DB_PASS}
DATABASE_HOST=localhost
DATABASE_PORT=5432
SMTP_PORT=25
EOF

chown -R root:root "${ENV_FILE}"
chmod 640 "${ENV_FILE}"

echo "--- Django migrations and static files ---"
cd "${PROJECT_DIR}"
${VENV_DIR}/bin/python manage.py makemigrations || true
${VENV_DIR}/bin/python manage.py migrate --no-input
${VENV_DIR}/bin/python manage.py collectstatic --no-input

echo "--- Creating systemd service files ---"
WEB_SERVICE="/etc/systemd/system/tempmail-web.service"
cat > "${WEB_SERVICE}" <<'UNIT'
[Unit]
Description=TempMail Gunicorn
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/home/TempMail/tempmail/src
EnvironmentFile=/home/TempMail/tempmail/src/.env
ExecStart=/home/TempMail/tempmail/.venv/bin/gunicorn project.wsgi:application --bind unix:/run/tempmail.sock --workers 3
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

SMTP_SERVICE="/etc/systemd/system/tempmail-smtp.service"
cat > "${SMTP_SERVICE}" <<'UNIT'
[Unit]
Description=TempMail SMTP receiver
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/home/TempMail/tempmail/src
EnvironmentFile=/home/TempMail/tempmail/src/.env
ExecStart=/home/TempMail/tempmail/.venv/bin/python /home/TempMail/tempmail/src/smtp_receiver.py
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

echo "--- Reloading systemd and enabling services ---"
systemctl daemon-reload
systemctl enable --now tempmail-web.service || true
systemctl enable --now tempmail-smtp.service || true

echo "--- Configuring nginx ---"
NGINX_SITE="/etc/nginx/sites-available/tempmail"
cat > "${NGINX_SITE}" <<NGCONF
server {
    listen 80;
    server_name ${DOMAIN};

    location /static/ {
        alias ${PROJECT_DIR}/static/;
    }

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://unix:/run/tempmail.sock;
    }
}
NGCONF

ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/tempmail
nginx -t
systemctl restart nginx

if [ -n "${ADMIN_EMAIL}" ]; then
  echo "--- Obtaining TLS cert with certbot ---"
  certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email "${ADMIN_EMAIL}"
fi

echo "--- Setup complete ---"
systemctl status tempmail-web.service --no-pager -n 5 || true
systemctl status tempmail-smtp.service --no-pager -n 5 || true
echo "Visit: http://${DOMAIN}/ (or https if cert obtained)"

exit 0
