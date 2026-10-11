# Forkop: кандидат XHTTP для sing-box X, 2026-10-08

Готов локальный X 1.0.3 на upstream 1.14.2 с XHTTP HTTP/1.1 и HTTP/2.
Релиз и зеркало не обновлялись. Изменения кандидата 1.0.2 сохранены.

Полный отчёт: [VALIDATION-1.0.3-XHTTP.md](../artifacts/sing-box-x/VALIDATION-1.0.3-XHTTP.md).
Артефакты: `artifacts/sing-box-x/dist`, проверяемое происхождение:
`artifacts/sing-box-x/patches/xhttp/manifest.json` и source archive.

Forkop определяет XHTTP по объявленной возможности ядра и сохраняет поддержку
старых Extended. Пользовательский фильтр белого флага сохраняется: актуально
61 сервер (58 TCP, 1 gRPC, 2 XHTTP) и одна группа URLTest, после фильтра 58 TCP;
два XHTTP проверены изолированно и работают.

Свежая массовая проверка через механизм пинга дашборда (Clash API delay,
HTTPS HEAD через каждый сервер) на 1.0.3: три прохода по 61/61, всего 183
успешных теста, включая TCP REALITY, gRPC REALITY и XHTTP TLS. VM восстановлена.

Unit/race, ARM64/x86_64 builds без QUIC, матрица из 22 сочетаний, start/restart,
DNS, Clash API и списки прошли. UPX прирост к 1.0.2: +65 256 байт x86_64,
+57 828 байт ARM64; package payload вырос на столько же. Обе OpenWrt VM
восстановлены, локальные пакеты на них не устанавливались.

REALITY с Xray 25.8.3 проверена; более новые 26.9.x ограничены наследуемой
совместимостью, воспроизводимой также на штатном X с TCP REALITY. TLS fingerprints
и REALITY client version не менялись. HTTP/3/QUIC отсутствуют; HTTP/3 в кандидате
явно отвергается. ARM64 runtime дополнительно проверен на GL-MT6000:
[отчёт роутера](sing-box-x-xhttp-router90-2026-10-08.md).
