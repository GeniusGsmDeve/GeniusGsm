# Deploy folder

This folder contains reusable deployment artifacts for TempMail.

- `nginx.tempmail.conf` — nginx site configuration (place in `/etc/nginx/sites-available/` and symlink to `/etc/nginx/sites-enabled/`).
- `tempmail-web.service` — systemd unit for gunicorn (place in `/etc/systemd/system/`).
- `tempmail-smtp.service` — systemd unit for the SMTP receiver (place in `/etc/systemd/system/`).
- `env.example` — example `.env` file. Copy to `/home/TempMail/tempmail/src/.env` and set secrets.
- `run_commands.sh` — helper script for common admin tasks.

Notes:
- Replace `User=tempmail` in the systemd unit files with the system user you created to run the services.
- Do not commit `.env` with real secrets to a public repository.
- After placing the service files, run:

  sudo systemctl daemon-reload
  sudo systemctl enable --now tempmail-web.service tempmail-smtp.service
  sudo ln -s /etc/nginx/sites-available/nginx.tempmail.conf /etc/nginx/sites-enabled/tempmail
  sudo nginx -t && sudo systemctl restart nginx
