#!/usr/bin/env bash
# Short helper script with common deployment commands for TempMail.

set -euo pipefail

echo "Use this script from the project root: /home/TempMail/tempmail"

case ${1-} in
  restart)
    sudo systemctl restart tempmail-web.service
    sudo systemctl restart tempmail-smtp.service
    sudo nginx -t && sudo systemctl restart nginx
    ;;

  status)
    sudo systemctl status tempmail-web.service --no-pager
    sudo systemctl status tempmail-smtp.service --no-pager
    sudo systemctl status nginx --no-pager
    ;;

  logs)
    sudo journalctl -u tempmail-web.service -f
    ;;

  migrate)
    /home/TempMail/tempmail/.venv/bin/python /home/TempMail/tempmail/src/manage.py migrate --no-input
    /home/TempMail/tempmail/.venv/bin/python /home/TempMail/tempmail/src/manage.py collectstatic --no-input
    ;;

  setup-db)
    echo "Create Postgres DB and user (run as postgres user):"
    echo "sudo -u postgres psql -c \"CREATE USER tempmail WITH PASSWORD 'YOUR_DB_PASSWORD';\""
    echo "sudo -u postgres psql -c \"CREATE DATABASE \"TempMail\" OWNER tempmail;\""
    ;;

  cert)
    sudo certbot --nginx -d mail.geniusgsm.com
    ;;

  git-push)
    echo "Recommended: git pull --rebase origin main before pushing."
    git pull --rebase origin main || true
    git push -u origin main
    ;;

  *)
    echo "Usage: $0 {restart|status|logs|migrate|setup-db|cert|git-push}"
    exit 2
    ;;
esac
