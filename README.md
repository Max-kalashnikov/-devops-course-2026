# Практические работы 5–7 по DevOps

Общий проект: SSH и UFW → Nginx и HTTPS → Docker Compose и PostgreSQL.

## Содержимое

- `config/`: конфигурации SSH, клиента SSH и Nginx.
- `scripts/audit.sh [5|6|7]`: аудит соответствующего этапа, коды 0/1.
- `scripts/deploy.sh [--dry-run]`: доставка сайта одним SSH-соединением.
- `scripts/init-app-env.sh`: создание секрета только на VM.
- `site/`: статический сайт и собственная страница 404.
- `app/`: Flask, Dockerfile, PostgreSQL и Compose.
- `docs/server-setup.md`: порядок восстановления учебного сервера.
- `docs/practice-5.md`, `docs/practice-6.md`, `docs/practice-7.md`: выполнение и теория.
- `docs/evidence-checklist.md`: необходимые реальные результаты и снимки экрана.

Рабочая папка подготовлена для переноса в `devops-course-2026`. Наличие файлов
не означает, что виртуальная машина уже настроена. ФИО, группа, фактические адреса,
ссылка на репозиторий и Pull Request заполняются по собственной конфигурации.

Сначала выполните ПР 5, затем ПР 6, затем ПР 7 по `docs/server-setup.md`.
Все `*.sh` запускаются в Linux на указанной в инструкции стороне, не в PowerShell.
Под Windows для rsync подходит WSL 1; системный WSL и настройки виртуализации
в этом проекте автоматически не изменяются.

На этом компьютере хостовые Linux-команды можно выполнять через существующий
Docker Desktop, без установки WSL. Из PowerShell в корне репозитория:

```powershell
.\scripts\host-tools.ps1 -Command 'bash scripts/deploy.sh --dry-run'
.\scripts\host-tools.ps1 -Command 'bash scripts/deploy.sh'
```

При первом запуске собирается образ с rsync, OpenSSH, Git и curl. Используются
ключ `~/.ssh/devops_vm`, доверенные ключи хоста из `~/.ssh/known_hosts` и
публичный `~/devops.crt`. Ключ VM должен быть проверен по её консоли и записан
также для `[host.docker.internal]:2222`. Приватный SSH-ключ подключается только
на чтение и внутри контейнера хранится в tmpfs с правами 600.
Фактический адрес Host-only можно передать параметром `-VmIp`.

Перед деплоем изменения нужно зафиксировать в Git. `.env` создаётся только на VM,
никогда не переносится с неё и исключён из Git и контекста Docker.


## Windows без Hyper-V

Для этого выполнения использовались Git for Windows и rsync из официального MSYS2.
Установить rsync локально (пакеты сверяются по SHA256), затем запустить доставку:

```powershell
powershell -ExecutionPolicy Bypass -File tools/windows/install-rsync.ps1
powershell -ExecutionPolicy Bypass -File scripts/host-tools.ps1 -Command 'bash scripts/deploy.sh --dry-run'
powershell -ExecutionPolicy Bypass -File scripts/host-tools.ps1 -Command 'bash scripts/deploy.sh'
```

При наличии локальной rsync обёртка использует Git Bash, иначе — указанный выше
вариант с Docker Desktop. Для Git Bash публичный сертификат находится в Windows
профиле пользователя (~/devops.crt); алиас SSH берётся из ~/.ssh/config.
