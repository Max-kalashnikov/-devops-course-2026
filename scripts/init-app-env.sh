#!/usr/bin/env bash
# Выполнять ТОЛЬКО на учебной Ubuntu VM после доставки app/ в ~/app/.
set -euo pipefail
cd "${HOME}/app"
[[ ! -e .env ]] || { echo '.env уже существует; сохранён без изменений' >&2; exit 1; }
umask 077
password="$(openssl rand -hex 16)"
printf 'POSTGRES_DB=app\nPOSTGRES_USER=app\nPOSTGRES_PASSWORD=%s\nDB_HOST=db\nSTUDENT_SURNAME=Калашников\n' "$password" > .env
chmod 600 .env
echo 'Создан ~/app/.env с правами 600'
