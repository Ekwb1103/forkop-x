# Подготовка tachyon-core для Forkop X

Дата: 2026-10-10. Создан GitHub-форк https://github.com/Screamshow/tachyon-core.
Локальный checkout: `artifacts/tachyon-core`, ветка `main`.
`origin` — наш форк; `upstream` — https://github.com/Dushnilin/tachyon-core.git.
Исходный commit: `7084dedd161016f74a6068f4ebddefcc9cd5974b`.
Исходная версия workspace: `0.0.1`; минимальный Rust: `1.89`, edition 2024.
Лицензия: GPL-3.0-only; сохранять LICENSE и авторство upstream.

## Границы подготовки

Форк и полный локальный Git checkout готовы. Производственный код Forkop,
пакеты, зеркало и VM в рамках этой подготовки не изменялись.
Rust/cargo не обнаружены в PATH; сборка и тесты исходников здесь не запускались.
Форк пока сохраняет исходные имена и настройки сборки. Адаптация не завершена.

Tachyon — отдельное Rust-ядро; существующий sing-box X остаётся отдельной
Go-сборкой. Не выдавать версию Tachyon за версию X. Решение о продуктовом имени
и включении нового ядра в компоненты нужно принять до публикации пакетов.

## Приоритетный план

1. Зафиксировать контракт CLI и возможностей: `version`, `check -c`, `run`,
   реальные build tags (включая XHTTP), формат Clash API. Разделить версию
   Tachyon, baseline совместимости sing-box и ревизию нашего пакета.
2. Исправить и проверить интеграцию процесса: basename `sing-box`, procd,
   ownership/readiness/watchdog, остановка и перезапуск без второго процесса.
3. Подготовить воспроизводимые musl-сборки x86_64 и aarch64_cortex-a53 с
   Cargo.lock, точным SHA исходников и SHA-256 артефактов. Проверить feature
   profile до сокращения протоколов; upstream CLI по умолчанию включает full.
4. Разработать APK/IPK-пакеты и явное переключение компонента с точным
   rollback. Upstream openwrt/Makefile устанавливает собственные init/UCI/config
   и symlink sing-box; такой рецепт требует адаптации к текущему Forkop.
   Сохранять UCI и `/etc/sing-box/config.json`, учитывать конфликты владельцев
   файлов и package database. Не подменять бинарник в пакете sing-box-x.
5. Проверить на существующих VM 24/25: DNS/FakeIP, TCP/UDP interception,
   selectors/urltest/Clash API, удалённые SRS, reload, reboot, rollback;
   затем реальные REALITY/Vision, XHTTP, gRPC и длительную нагрузку.
   Перед мутациями снять package/service state и обозначить изменения.
6. Измерить flash по распакованному payload, RAM и CPU на одинаковых
   конфигурациях с X; результаты upstream не считать замерами Forkop.
7. После тестов подготовить отдельную публикацию на нашем зеркале с manifest,
   архитектурой, форматом пакета, длиной и SHA-256. Не помещать Tachyon в
   каталог sing-box-x без отдельного решения о схеме и идентичности пакета.

## Уже имеющиеся свидетельства

- `docs/tachyon-core-vm-smoke-2026-10-10.md`: опубликованный бинарник прошёл
  базовые direct/DNS/FakeIP/Clash проверки на обеих VM.
- `docs/tachyon-core-primary-vm25-2026-10-10.md`: VM25 запускала полный Forkop
  config через экспериментальный wrapper; один реальный gRPC/REALITY узел
  прошёл HTTPS, REALITY/Vision и XHTTP остаются неразобранными.
- На VM25 package database продолжает учитывать sing-box-x: существующая
  ручная установка не является образцом корректной пакетной интеграции.
- Upstream COMPAT.md прямо помечен как устаревший. Возможности проверять по
  исходникам, актуальным документам и runtime-тестам, а не по этой таблице.

## Работа с upstream

Получать обновления через `git fetch upstream`, изучать diff и интегрировать
в main после проверки. Сохранять историю форка и точный исходный SHA для
каждого артефакта. Не запускать release workflow до адаптации публикации.
