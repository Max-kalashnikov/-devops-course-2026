# Конфигурация виртуальной машины devops-vm

Это инструкция восстановления целевой конфигурации. Фактические IP, версии пакетов,
даты снимков и результаты запусков запишите после выполнения на своей VM.
Команды Linux выполняются в Bash; команды Windows отмечены отдельно.

## 1. Параметры машины

VirtualBox 7.x, Ubuntu Server 24.04 LTS, RAM 2048 МБ, 1 CPU, диск VDI 25 ГБ
с динамическим выделением. Имя VM и hostname: devops-vm. Начальный пользователь
student. При установке выбрать OpenSSH server, не устанавливать Featured snaps.

Фактически установлена Ubuntu Server 24.04.5 LTS, ядро после установки
6.8.0-147-generic. На данном Windows-хосте активен Hyper-V для Docker Desktop.
Загрузка с двумя CPU получена с провайдером паравиртуализации Hyper-V,
отключённым x2APIC и включённым APIC, но создание живого снимка привело
к потере отклика. Для завершения работ используется одно CPU. Это отклонение
от требования двух CPU указано явно; службы, команды и результаты функциональных
проверок от числа CPU не зависят. В VirtualBox при выключенной VM:

```powershell
& "$env:ProgramFiles/Oracle/VirtualBox/VBoxManage.exe" modifyvm devops-vm --cpus 1 --paravirt-provider hyperv --x86-x2apic off
& "$env:ProgramFiles/Oracle/VirtualBox/VBoxManage.exe" modifyvm devops-vm --apic on
& "$env:ProgramFiles/Oracle/VirtualBox/VBoxManage.exe" storagectl devops-vm --name SATA --hostiocache on
```

Число доступных ядер проверяется командой `nproc`. Снимки далее создаются
после штатного выключения ОС, без сохранения оперативной памяти.
Глобальные настройки Hyper-V в Windows не изменялись.

В консоли VM:

```bash
sudo apt update && sudo apt upgrade -y
ip -brief address
sudo systemctl status ssh --no-pager
```

## 2. Сетевые интерфейсы

Адаптер 1 NAT, обычно адрес 10.0.2.15: выход в интернет.
Адаптер 2 Host-only: доступ с Windows к HTTP/HTTPS и учебным портам.
Фактический адрес Host-only определить через `ip -brief address`.
Ниже 192.168.56.101 - пример, заменить фактическим адресом.
Если второй интерфейс не получил адрес, включить DHCP для него через Netplan
с его фактическим именем; перед применением использовать `sudo netplan try`.

## 3. Правило проброса портов

В VirtualBox: NAT, TCP, имя ssh, адрес хоста 127.0.0.1, порт хоста 2222.
Сначала порт гостя 22. После смены порта sshd изменить порт гостя на 2222.
IP гостя в правиле оставить пустым.

## 4. Учётные записи

В консоли VM или исходной сессии student:

```bash
sudo adduser devops
sudo usermod -aG sudo devops
groups devops
```

На Windows в PowerShell создать отдельную пару ключей. Если файл уже существует,
не перезаписывать его. Задать пароль ключа; для автоматизации загрузить ключ в ssh-agent.

```powershell
ssh-keygen -t ed25519 -C devops-vm-key -f "$env:USERPROFILE/.ssh/devops_vm"
Get-Content "$env:USERPROFILE/.ssh/devops_vm.pub" | ssh -p 2222 devops@127.0.0.1 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
ssh -i "$env:USERPROFILE/.ssh/devops_vm" -p 2222 devops@127.0.0.1
```

Перед первым принятием ключа сверить его с выводом в консоли VM:
`sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.
Добавить блок из `config/ssh-client.conf` в `~/.ssh/config`, сохранив другие записи.
Проверить `ssh devops`; в VM выполнить `stat -c '%a %n' ~/.ssh ~/.ssh/authorized_keys`.
Ожидается 700 и 600. Снять 02-keys-configured.

## 5. Служба SSH

Сохранить действующую сессию. Передать конфигурацию с хоста:

```bash
scp config/99-hardening.conf devops:99-hardening.conf
```

В VM:

```bash
sudo cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo install -m 644 ~/99-hardening.conf /etc/ssh/sshd_config.d/99-hardening.conf
sudo grep -R -nE '^(Port|PasswordAuthentication|PermitRootLogin|KbdInteractiveAuthentication|MaxAuthTries|AllowUsers)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/
```

В файлах с более ранним именем, например `50-cloud-init.conf`, закомментировать
конфликтующие значения. OpenSSH использует первое найденное значение большинства
директив; файл 99-hardening.conf не гарантирует переопределение.

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries|allowusers) '
sudo systemctl disable --now ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh
sudo ss -tlnp | grep sshd
```

Ожидается порт 2222; root и оба интерактивных способа входа запрещены,
AllowUsers devops, MaxAuthTries 3. Остальные значения приведены в конфигурации.
Изменить правило NAT согласно разделу 3 и в новом терминале проверить:

```bash
ssh devops
ssh -p 2222 root@127.0.0.1
ssh -p 2222 -o PubkeyAuthentication=no devops@127.0.0.1
```

Два последних подключения должны быть отклонены. На VM собрать журнал
`sudo journalctl -u ssh --since '10 min ago' --no-pager`.
Только после успешного нового входа закрывать исходную сессию. Снять 03-ssh-hardened.

## 6. Правила межсетевого экрана

В VM, не закрывая исходную сессию:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw enable
sudo ufw logging medium
sudo ufw status verbose
```

Если уже есть правило ALLOW для 2222, заменить его на LIMIT по методичке.
Проверить новый вход. С хоста выполнить `curl -m 3 http://192.168.56.101:8080`;
на VM найти `sudo grep 'UFW BLOCK' /var/log/ufw.log | tail -5`.
Если отдельного файла журнала нет, проверить `sudo journalctl -k --since '5 min ago'`.
Разобрать SRC, DST, PROTO, DPT.

В Windows hosts с правами администратора добавить строку с реальным адресом:
`192.168.56.101 devops.local`. Проверить `ping devops.local` и
`ssh devops.local`. Имя SSH-псевдонима `devops` и DNS-имя `devops.local`
различны: в конфигурации клиента для них предусмотрены отдельные блоки,
поэтому оба используют devops, ключ devops_vm и порт 2222. Первый адресует
NAT 127.0.0.1, второй разрешает имя в адрес Host-only. Без блока для доменного
имени понадобятся явные параметры `-p 2222 -i ~/.ssh/devops_vm`.

В VM:

```bash
sudo hostnamectl set-hostname devops-vm
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 devops-vm.devops.local devops-vm/' /etc/hosts
hostname -f
```

Если строки 127.0.1.1 не было, добавить её вручную. Передать `scripts/audit.sh`
на VM и выполнить `bash audit.sh 5`. Для негативного опыта изменить MaxAuthTries
в drop-in на 10, выполнить аудит, вернуть 3. Для чтения `sshd -T` перезапуск
не нужен; не оставлять экспериментальное значение в файле.

## 7. Снимки состояния

- 01-clean-install: ОС обновлена, OpenSSH работает, защита ещё не настроена.
- 02-keys-configured: создан devops, проверен ключ и псевдоним.
- 03-ssh-hardened: порт 2222, root и пароль запрещены.
- 04-nginx-https: сайт работает по HTTPS.
- 05-docker-compose: приложение и PostgreSQL запущены.

Фактические снимки создаются в VirtualBox; имена в документе их не создают.
Даты и снимки экрана менеджера снимков приложить к отчётам.

## 8. Веб-сервер

На VM установить `sudo apt install -y nginx rsync`. Зафиксировать вывод
`ps -o user,pid,ppid,cmd -C nginx` и исходный стандартный сайт (200 по HTTP).

```bash
sudo install -d -o devops -g devops -m 755 /var/www/devops-site
echo '<h1>devops.local: placeholder</h1>' > /var/www/devops-site/index.html
chmod 644 /var/www/devops-site/index.html
namei -l /var/www/devops-site/index.html
sudo -u www-data cat /var/www/devops-site/index.html
sudo -u www-data touch /var/www/devops-site/test.html
```

Последняя команда должна завершиться отказом. Сначала выполнить HTTP-этап
по разделу 4.1 исходной методички и собрать его доказательства. Затем создать TLS:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt \
  -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'
sudo chown root:root /etc/ssl/private/devops.key /etc/ssl/certs/devops.crt
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
```

С хоста передать `config/nginx-devops-site.conf` через scp. В VM установить:

```bash
sudo install -m 644 ~/nginx-devops-site.conf /etc/nginx/sites-available/devops-site
sudo ln -sfn /etc/nginx/sites-available/devops-site /etc/nginx/sites-enabled/devops-site
sudo unlink /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

`unlink` нужен только если ссылка default существует. Для этапа ПР 6 блок `/app/`
можно пока убрать. При отключённом IPv6 убрать обе строки `listen [::]`.
Рабочие процессы читают сертификат, приватный ключ доступен главному процессу root.
Ключ никогда не копировать на хост.

На хосте:

```bash
curl -I http://devops.local
curl -I https://devops.local
curl -k -I https://devops.local
scp devops:/etc/ssl/certs/devops.crt ~/devops.crt
curl --cacert ~/devops.crt -I https://devops.local
```

Ожидаются 301; ошибка доверия; 200; после SCP - 200 с проверкой сертификата.
В PowerShell использовать `curl.exe`, чтобы исключить алиас старого PowerShell.
HSTS в учебном ресурсе не добавляется. Создать 04-nginx-https.

На Linux/WSL с настройкой ключа и config внутри домашнего каталога:

```bash
git switch -c feature/web-deploy
# Заполнить ФИО и группу в site/index.html.
git add site scripts config docs README.md .gitignore .gitattributes
git commit -m 'feat: add HTTPS static site and deployment scripts'
bash scripts/deploy.sh --dry-run
bash scripts/deploy.sh
curl --cacert ~/devops.crt -I https://devops.local/no-such-page
```

Запуски деплоя выполнять на чистой Git-копии. Доверенный сертификат должен
лежать именно в HOME текущей среды (Windows HOME и WSL HOME различны).
Провести пять проверок из `docs/practice-6.md`, эксперименты с правами и журналами.
На VM `bash audit.sh 6`, негативные проверки сертификата и записи всем.
Отправить ветку, создать PR и выполнить слияние перед созданием feature/docker.
URL PR и репозитория сохранить в отчёте.

## 9. Контейнеризация

Docker Engine установить на VM из официального apt-репозитория, не docker.io.
Перед установкой проверить конфликтующие пакеты по официальной инструкции:
https://docs.docker.com/engine/install/ubuntu/

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker devops
```

Открыть новую SSH-сессию; записать `docker version`, `docker compose version`,
`getent group docker`; выполнить `docker run --rm hello-world`.
Группа docker фактически даёт полномочия root; её участник здесь уже имеет sudo.

С хоста, после создания ветки `feature/docker` от main:

```bash
rsync -avz --delete --chmod=D755,F644 --exclude=.env --dry-run app/ devops:app/
rsync -avz --delete --chmod=D755,F644 --exclude=.env app/ devops:app/
scp scripts/init-app-env.sh devops:init-app-env.sh
```

Сначала на VM выполнить сборку и запуск без БД по `docs/practice-7.md`,
собрать ошибку и повторную сборку. После этого:

```bash
bash ~/init-app-env.sh
cd ~/app
docker compose up -d --build
docker compose ps
for i in 1 2 3; do curl -s http://127.0.0.1:5000/; done
docker compose exec app id
docker compose exec app getent hosts db
sudo ss -tlnp | grep -E ':(5000|5432)\b'
```

Проект лежит в `/home/devops/app`, секрет `/home/devops/app/.env` имеет 600.
Пароль генерируется на VM и не выводится. Для персонализации заполнить
STUDENT_SURNAME в .env. Образ postgres:16-alpine, том app_db_data, сеть app_backend.
БД не публикует порт; приложение публикует только 127.0.0.1:5000.
Nginx с HTTPS передаёт `/app/` в `http://127.0.0.1:5000/`.
Проверить на хосте HTTPS для `/`, `/app/`, `/app/health` через `--cacert`.

Обычный `docker compose down` сохраняет том. `down -v` удаляет учебные данные:
опыт выполнять только в этом учебном проекте после фиксации счётчика.
После запуска приложения дождаться готовности БД.
Собрать опыт обхода UFW, опыт 502 и негативный аудит по `docs/practice-7.md`.
Снять 05-docker-compose. Зафиксировать изменения Conventional Commits,
отправить feature/docker, создать PR и слить его в main.

## Источники

Методические указания ПР 5, 6, 7, предоставленные пользователем.
Актуальная установка Docker и описание обхода UFW проверены 25.10.2026:
https://docs.docker.com/engine/install/ubuntu/
https://docs.docker.com/engine/network/packet-filtering-firewalls/
