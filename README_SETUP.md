# TempMail setup (Linux)

This repository includes `setup.sh` to configure a Debian/Ubuntu Linux host to run the TempMail project.

Quick start (run as root):

```bash
cd /home/TempMail/tempmail
sudo ./setup.sh DOMAIN=mail.geniusgsm.com DB_PASS=your_db_password EMAIL=you@example.com
```

What the script does:
- Installs system packages (Python, PostgreSQL, nginx, certbot)
- Creates/activates a Python virtualenv and installs Python dependencies from `requirements.txt`
- Creates a PostgreSQL user and database
- Writes a `.env` file with sensible defaults (you should review it)
- Runs Django migrations and `collectstatic`
- Writes systemd service units for the web and SMTP receiver and enables them
- Writes an nginx site configuration and restarts nginx
- Optionally requests a Let's Encrypt certificate if `EMAIL` is supplied

Notes and post-setup actions:
- Review `/home/TempMail/tempmail/src/.env` to ensure passwords and `ALLOWED_HOSTS` are correct.
- If you already have systemd units or nginx configs, inspect the generated files before overwriting.
- The script assumes Debian/Ubuntu. Adapt package manager commands for other distros.
