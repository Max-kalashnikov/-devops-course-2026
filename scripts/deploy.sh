#!/usr/bin/env bash
# Запуск: bash scripts/deploy.sh [--dry-run]
set -euo pipefail
die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
dry_run=()
case "${1:-}" in
    '') [[ $# -eq 0 ]] || die 'Лишние аргументы' ;;
    --dry-run) [[ $# -eq 1 ]] || die 'Лишние аргументы'; dry_run=(--dry-run) ;;
    *) die 'Использование: deploy.sh [--dry-run]' ;;
esac
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)" || die 'Не найден Git-репозиторий'
LOCAL_DIR="$ROOT/site/"
REMOTE=devops
REMOTE_DIR=/var/www/devops-site
SITE_URL=https://devops.local
CA_CERT="${HOME}/devops.crt"
[[ -f "$LOCAL_DIR/index.html" ]] || die 'Отсутствует site/index.html'
status="$(git -C "$ROOT" status --porcelain --untracked-files=all)" || die 'Ошибка Git'
[[ -z "$status" ]] || die 'Есть незафиксированные изменения, включая индекс или новые файлы'
commit="$(git -C "$ROOT" rev-parse --short HEAD)" || die 'Нет коммита для доставки'
for tool in rsync ssh; do command -v "$tool" >/dev/null || die "Не найдена утилита $tool"; done
if [[ ${#dry_run[@]} -eq 0 ]]; then
    command -v curl >/dev/null || die 'Не найдена утилита curl'
    [[ -r "$CA_CERT" ]] || die "Недоступен доверенный сертификат $CA_CERT"
fi
# Единственное SSH-соединение открывает rsync; curl использует HTTPS.
rsync -avz --delete --chmod=D755,F644 "${dry_run[@]}" \
    -e 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5' \
    "$LOCAL_DIR" "$REMOTE:$REMOTE_DIR/" || die 'Ошибка синхронизации'
if [[ ${#dry_run[@]} -gt 0 ]]; then
    printf 'План доставки коммита %s готов\n' "$commit"
    exit 0
fi
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 \
    --cacert "$CA_CERT" --output /dev/null "$SITE_URL/" || die 'Сайт недоступен или сертификат не прошёл проверку'
printf 'Доставлен коммит %s\n' "$commit"
