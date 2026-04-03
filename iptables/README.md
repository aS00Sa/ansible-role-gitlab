## Скрипт защиты GitLab iptables

sudo apt install iptables-persistent

Этот каталог содержит скрипт `apply-iptables-gitlab.sh`, который настраивает строгие правила firewall для хоста с GitLab.

### Что делает скрипт

- Устанавливает политику по умолчанию:
  - `INPUT` и `FORWARD` → `DROP`
  - `OUTPUT` → `ACCEPT`
- Разрешает:
  - весь трафик на интерфейсе `lo` (loopback);
  - состояния `ESTABLISHED,RELATED` (ответы на уже установленные соединения);
  - **полный** входящий трафик только с доверенных «белых» IPv4 (по умолчанию `72.56.1.35`);
  - **новые** TCP на `PORTS_TCP` **только** с «серых» подсетей RFC1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`); с остального интернета к этим портам доступа нет;
  - ICMP/ICMPv6 (ping и служебные сообщения) — по умолчанию включено.
- Применяет эквивалентные правила для IPv4 (`iptables`) и IPv6 (`ip6tables`).
- Тюнинг PMTUD (по умолчанию включён): `net.ipv4.tcp_mtu_probing=1` в `/etc/sysctl.d/99-tcp-mtu-probing.conf` и правила `mangle` `TCPMSS --clamp-mss-to-pmtu` для `FORWARD`/`OUTPUT` (IPv4 и IPv6).
- Доверенные IPv4 и приватные подсети настраиваются переменными `TRUSTED_IPV4_SOURCES` и `PRIVATE_IPV4_CIDRS` (см. ниже).
- Пытается сохранить правила через `netfilter-persistent` (пакет `iptables-persistent` на Debian/Ubuntu).

Перед изменениями текущая конфигурация iptables/ip6tables сохраняется в `/root/iptables-backups/`.

### Использование

1. Скопируйте каталог `iptables/` (или сам скрипт) на хост с GitLab.
2. Выполните скрипт от root:

   ```bash
   sudo ./iptables/apply-iptables-gitlab.sh
   ```

3. Проверьте, что:
   - вы подключаетесь либо **из серой сети** (RFC1918), либо с адреса из `TRUSTED_IPV4_SOURCES`, иначе сервисные порты будут недоступны;
   - веб-интерфейс GitLab доступен по ожидаемым портам с нужной стороны сети.

### Настройка портов и ICMP

Скрипт настраивается через переменные окружения:

- `PORTS_TCP` — список TCP-портов (через запятую), на которые пускаются **только** новые соединения с `PRIVATE_IPV4_CIDRS` / `PRIVATE_IPV6_CIDRS`.
  - Пример: открыть только `22` и `443`:

    ```bash
    sudo PORTS_TCP="22,443" ./iptables/apply-iptables-gitlab.sh
    ```

- `ALLOW_ICMP` — `1` или `0`, разрешать ли ICMP (IPv4), по умолчанию `1`.
- `ALLOW_ICMPV6` — `1` или `0`, разрешать ли ICMPv6, по умолчанию `1`.
- `ENABLE_MTU_TUNING` — `1` или `0`, применять ли sysctl MTU probing и `TCPMSS` в `mangle`, по умолчанию `1`.
- `TRUSTED_IPV4_SOURCES` — через запятую IPv4, с которых разрешён **весь** входящий трафик; по умолчанию `72.56.1.35`. Пустая строка — отключить.
- `PRIVATE_IPV4_CIDRS` — через запятую IPv4-подсети (CIDR), с которых разрешён NEW TCP на `PORTS_TCP`; по умолчанию RFC1918. Пустая строка — не пускать сервисные порты ни с одной «серой» сети (останется только `TRUSTED_IPV4_SOURCES` и ICMP).
- `PRIVATE_IPV6_CIDRS` / `TRUSTED_IPV6_SOURCES` — то же для IPv6 (по умолчанию ULA и link-local для TCP; доверенные IPv6 пустые).

Отключить ICMP/ICMPv6:

```bash
sudo ALLOW_ICMP=0 ALLOW_ICMPV6=0 ./iptables/apply-iptables-gitlab.sh
```

### Замечания по безопасности

- Выполняйте изменения firewall из **отдельной SSH-сессии**, чтобы в случае ошибки не потерять доступ.
- Рекомендуется предварительно протестировать правила, не сохраняя их, а затем убедиться, что всё работает корректно, прежде чем включать постоянное сохранение (`iptables-persistent` / `netfilter-persistent`).

