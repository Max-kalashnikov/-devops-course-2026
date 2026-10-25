#!/usr/bin/env bash
# На VM: bash scripts/audit.sh [5|6|7]. По умолчанию проверяются все три работы.
set -uo pipefail
export LC_ALL=C
PASS=0; FAIL=0
STAGE="${1:-7}"
case "$STAGE" in 5|6|7) ;; *) echo 'Использование: audit.sh [5|6|7]' >&2; exit 1;; esac
[[ $# -le 1 ]] || exit 1
check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        printf '[OK] %s\n' "$desc"; PASS=$((PASS+1))
    else
        printf '[FAIL] %s (ожидалось %s, получено %s)\n' "$desc" "$expected" "$actual"
        FAIL=$((FAIL+1))
    fi
}
echo "Аудит $(hostname -f) $(date '+%Y-%m-%d %H:%M')"
echo '[1] Служба SSH'
sshd_config="$(sudo sshd -T 2>/dev/null)" || sshd_config='ERROR'
value() { awk -v key="$1" '$1==key {print $2; exit}' <<< "$sshd_config"; }
check 'Вход root запрещён' no "$(value permitrootlogin)"
check 'Парольная аутентификация отключена' no "$(value passwordauthentication)"
port="$(value port)"
port_ok=no
if [[ "$port" =~ ^[0-9]+$ ]] && (( port > 0 && port <= 65535 && port != 22 )); then port_ok=yes; fi
check 'Порт SSH корректен и отличается от 22' yes "$port_ok"
check 'MaxAuthTries' 3 "$(value maxauthtries)"

echo '[2] Межсетевой экран'
ufw_status="$(sudo ufw status verbose 2>/dev/null)" || ufw_status='ERROR'
check 'UFW активен' active "$(awk '/^Status:/{print $2}' <<< "$ufw_status")"
incoming="$(sed -n 's/^Default: \([^ ]*\) (incoming).*/\1/p' <<< "$ufw_status")"
check 'Входящий трафик по умолчанию запрещён' deny "$incoming"
limit_ok=no
if grep -Eq '^2222/tcp[[:space:]]+LIMIT' <<< "$ufw_status"; then limit_ok=yes; fi
check 'SSH защищён правилом LIMIT' yes "$limit_ok"

echo '[3] Учётные записи'
awk -F: '$3>=1000 && $3<65534 {printf "    %s (uid=%s)\n",$1,$3}' /etc/passwd

if (( STAGE >= 6 )); then
    echo '[4] Веб-сервер'
    nginx_state="$(systemctl is-active nginx 2>/dev/null)" || nginx_state="${nginx_state:-unknown}"
    check 'Nginx активен' active "$nginx_state"
    nginx_ok=no
    if sudo nginx -t >/dev/null 2>&1; then nginx_ok=yes; fi
    check 'Синтаксис Nginx' yes "$nginx_ok"
    cert_ok=no
    if openssl x509 -in /etc/ssl/certs/devops.crt -noout \
        -checkend "${CERT_MIN_SECONDS:-2592000}" >/dev/null 2>&1; then cert_ok=yes; fi
    check 'Сертификат действителен ещё 30 дней' yes "$cert_ok"
    permissions_ok=no
    writable="$(find /var/www/devops-site -perm -o+w -print 2>/dev/null)"
    find_code=$?
    key_mode="$(sudo stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)" || key_mode=ERROR
    if [[ $find_code -eq 0 && -z "$writable" && "$key_mode" == 600 ]]; then permissions_ok=yes; fi
    check 'Нет записи для всех и права TLS-ключа 600' yes "$permissions_ok"
fi

if (( STAGE >= 7 )); then
    echo '[5] Контейнеризация'
    docker_state="$(systemctl is-active docker 2>/dev/null)" || docker_state="${docker_state:-unknown}"
    check 'Docker активен' active "$docker_state"
    # Стандартный контейнер проекта ~/app; можно явно указать DB_CONTAINER.
    health="$(docker inspect -f '{{.State.Health.Status}}' "${DB_CONTAINER:-app-db-1}" 2>/dev/null)" || health=ERROR
    check 'PostgreSQL healthy' healthy "$health"
    listeners="$(ss -H -tln 2>/dev/null)"
    ss_code=$?
    bindings_ok=no
    # Проверяем IPv4, IPv6, wildcard и конкретные внешние адреса.
    if [[ $ss_code -eq 0 ]] && awk '
        $4 ~ /:(5000|5432)$/ && $4 !~ /^127\.0\.0\.1:/ {bad=1}
        END {exit bad ? 1 : 0}' <<< "$listeners"; then bindings_ok=yes; fi
    # Docker может публиковать порт через NAT без процесса docker-proxy в ss.
    docker_ports="$(docker ps --format '{{.Ports}}' 2>/dev/null)"
    docker_code=$?
    if [[ $docker_code -ne 0 ]]; then
        bindings_ok=no
    elif ! awk '
        {for (i=1;i<=NF;i++) {
            item=$i; gsub(/,/, "", item)
            if (item ~ /:(5000|5432)->/ && item !~ /^127\.0\.0\.1:/) bad=1
        }}
        END {exit bad ? 1 : 0}' <<< "$docker_ports"; then bindings_ok=no; fi
    check 'Порты 5000 и 5432 доступны только через 127.0.0.1' yes "$bindings_ok"
    env_mode="$(stat -c '%a' "${HOME}/app/.env" 2>/dev/null)" || env_mode=ERROR
    check 'Права ~/app/.env' 600 "$env_mode"
fi
printf 'Пройдено: %s; не пройдено: %s\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
