# Ansible Role: GitLab

**Deprecated**: In September 2023, I deprecated this role as I am no longer maintaining any GitLab instances, and use Gitea instead for my personal work. Please consider forking this role or use someone else's GitLab role.

[![CI](https://github.com/aS00Sa/ansible-role-gitlab/workflows/CI/badge.svg?event=push)](https://github.com/aS00Sa/ansible-role-gitlab/actions?query=workflow%3ACI)

Installs GitLab, a Ruby-based front-end to Git, on any RedHat/CentOS or Debian/Ubuntu linux system.

GitLab's default administrator account details are below; be sure to login immediately after installation and change these credentials!

    root
    initial_root_password

## Requirements

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -U pip
   pip install -r requirements.txt
   # Дальше либо оставьте venv активным, либо вызывайте .venv/bin/ansible-playbook явно.

   ssh-copy-id -i /mnt/c/Users/x-shu/.ssh/id_rsa.pub debian@gitlab
   
   ANSIBLE_STDOUT_CALLBACK=yaml ANSIBLE_CONFIG="$PWD/ansible.cfg" .venv/bin/ansible-playbook -i inventory.ini install.yml -u debian --private-key ~/.ssh/id_rsa 2>&1 | tee deploy-$(date +%Y%m%d-%H%M).log

   # Удаление пакета Omnibus (данные по умолчанию не трогаем):
   # .venv/bin/ansible-playbook -i inventory.ini remove.yml -u debian --private-key ~/.ssh/id_rsa
   # Полное стирание /etc/gitlab, /var/opt/gitlab и т.д.:
   # .venv/bin/ansible-playbook -i inventory.ini remove.yml -e gitlab_remove_purge_data=true
   ```

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

    gitlab_domain: ""  # задайте в inventory / group_vars / -e (в роли без FQDN по умолчанию)
    gitlab_external_url: "http://{{ gitlab_domain }}:{{ gitlab_ext_port }}/"

The FQDN (`gitlab_domain`) must be set outside the role (inventory host vars, `group_vars`, or `-e`). There is no hardcoded production hostname in `defaults/main.yml`. The URL is the Omnibus `external_url`; set `gitlab_ext_port` and switch to `https://` when using TLS on HAProxy/Traefik. For a non-default HTTP port, include it in the URL (e.g. port 8443 behind a reverse proxy).

**CI / автодеплой (Linux на ВМ):** роль создаёт системного пользователя `gitlab-ci` с паролем из `gitlab_ci_deploy_password` (по умолчанию `CHANGE_ME` — смените через Ansible Vault или `-e`). Пароль обновляется только при создании пользователя; чтобы принудительно обновить: `gitlab_ci_deploy_password_update: true`. Отключить создание пользователя: `gitlab_ci_deploy_user_enabled: false`.

    gitlab_git_data_dir: "/var/opt/gitlab/git-data"

The `gitlab_git_data_dir` is the location where all the Git repositories will be stored. You can use a shared drive or any path on the system.

    gitlab_signup_enabled: false

Whether to allow open registration (Sign-up). For public instances it's recommended to keep this set to `false`.

    gitlab_2fa_mandatory: true

Whether to require all users to enable two-factor authentication (2FA). For public instances it is recommended to set this to `true`.

    gitlab_2fa_grace_period_hours: 48

Grace period (in hours) users have to enable 2FA after sign-in when `gitlab_2fa_mandatory` is `true`.

    gitlab_backup_path: "/var/opt/gitlab/backups"

The `gitlab_backup_path` is the location where Gitlab backups will be stored.

    gitlab_edition: "gitlab-ce"

The edition of GitLab to install. Usually either `gitlab-ce` (Community Edition) or `gitlab-ee` (Enterprise Edition).

    gitlab_version: ''

If you'd like to install a specific version, set the version here (e.g. `11.4.0-ce.0` for Debian/Ubuntu, or `11.4.0-ce.0.el7` for RedHat/CentOS).

    gitlab_config_template: "gitlab.rb.all.j2"

The `gitlab.rb.j2` template packaged with this role is meant to be very generic and serve a variety of use cases. However, many people would like to have a much more customized version, and so you can override this role's default template with your own, adding any additional customizations you need. To do this:

  - Create a `templates` directory at the same level as your playbook.
  - Create a `templates\mygitlab.rb.j2` file (just choose a different name from the default template).
  - Set the variable like: `gitlab_config_template: mygitlab.rb.j2` (with the name of your custom template).

### SSL Configuration.

    gitlab_redirect_http_to_https: true
    gitlab_ssl_certificate: "/etc/gitlab/ssl/{{ gitlab_domain }}.crt"
    gitlab_ssl_certificate_key: "/etc/gitlab/ssl/{{ gitlab_domain }}.key"

GitLab SSL configuration; tells GitLab to redirect normal http requests to https, and the path to the certificate and key (the default values will work for automatic self-signed certificate creation, if set to `true` in the variable below).

    # SSL Self-signed Certificate Configuration.
    gitlab_create_self_signed_cert: true
    gitlab_self_signed_cert_subj: "/C=US/ST=Missouri/L=Saint Louis/O=IT/CN={{ gitlab_domain }}"

Whether to create a self-signed certificate for serving GitLab over a secure connection. Set `gitlab_self_signed_cert_subj` according to your locality and organization.

### LetsEncrypt Configuration.

    gitlab_letsencrypt_enable: false
    gitlab_letsencrypt_contact_emails: ["gitlab@example.com"]
    gitlab_letsencrypt_auto_renew_hour: 1
    gitlab_letsencrypt_auto_renew_minute: 30
    gitlab_letsencrypt_auto_renew_day_of_month: "*/7"
    gitlab_letsencrypt_auto_renew: true

GitLab LetsEncrypt configuration; tells GitLab whether to request and use a certificate from LetsEncrypt, if `gitlab_letsencrypt_enable` is set to `true`. Multiple contact emails can be configured under `gitlab_letsencrypt_contact_emails` as a list.

    # LDAP Configuration.
    gitlab_ldap_enabled: false
    gitlab_ldap_host: "example.com"
    gitlab_ldap_port: "389"
    gitlab_ldap_uid: "sAMAccountName"
    gitlab_ldap_method: "plain"
    gitlab_ldap_bind_dn: "CN=Username,CN=Users,DC=example,DC=com"
    gitlab_ldap_password: "password"
    gitlab_ldap_base: "DC=example,DC=com"

GitLab LDAP configuration; if `gitlab_ldap_enabled` is `true`, the rest of the configuration will tell GitLab how to connect to an LDAP server for centralized authentication.

    gitlab_dependencies:
      - openssh-server
      - postfix
      - curl
      - openssl
      - tzdata

Dependencies required by GitLab for certain functionality, like timezone support or email. You may change this list in your own playbook if, for example, you would like to install `exim` instead of `postfix`.

    gitlab_time_zone: "UTC"

Gitlab timezone.

    gitlab_backup_keep_time: "604800"

How long to keep local backups (useful if you don't want backups to fill up your drive!).

    gitlab_download_validate_certs: true

Controls whether to validate certificates when downloading the GitLab installation repository install script.

    # Email configuration.
    gitlab_email_enabled: false
    gitlab_email_from: "gitlab@example.com"
    gitlab_email_display_name: "Gitlab"
    gitlab_email_reply_to: "gitlab@example.com"

Gitlab system mail configuration. Disabled by default; set `gitlab_email_enabled` to `true` to enable, and make sure you enter valid from/reply-to values.

    # SMTP Configuration
    gitlab_smtp_enable: false
    gitlab_smtp_address: "smtp.server"
    gitlab_smtp_port: "465"
    gitlab_smtp_user_name: "smtp user"
    gitlab_smtp_password: "smtp password"
    gitlab_smtp_domain: "example.com"
    gitlab_smtp_authentication: "login"
    gitlab_smtp_enable_starttls_auto: true
    gitlab_smtp_tls: false
    gitlab_smtp_openssl_verify_mode: "none"
    gitlab_smtp_ca_path: "/etc/ssl/certs"
    gitlab_smtp_ca_file: "/etc/ssl/certs/ca-certificates.crt"

Gitlab SMTP configuration; of `gitlab_smtp_enable` is `true`, the rest of the configuration will tell GitLab how to send mails using an smtp server.

    gitlab_nginx_listen_port: 8080

If you are running GitLab behind a reverse proxy, you may want to override the listen port to something else.

    gitlab_nginx_listen_https: false

If you are running GitLab behind a reverse proxy, you may wish to terminate SSL at another proxy server or load balancer

    gitlab_nginx_ssl_verify_client: ""
    gitlab_nginx_ssl_client_certificate: ""

If you want to enable [2-way SSL Client Authentication](https://docs.gitlab.com/omnibus/settings/nginx.html#enable-2-way-ssl-client-authentication), set `gitlab_nginx_ssl_verify_client` and add a path to the client certificate in `gitlab_nginx_ssl_client_certificate`.

    gitlab_default_theme: 2

GitLab includes a number of themes, and you can set the default for all users with this variable. See [the included GitLab themes to choose a default](https://github.com/gitlabhq/gitlabhq/blob/master/config/gitlab.yml.example#L79-L85).

    gitlab_extra_settings:
      - gitlab_rails:
          - key: "trusted_proxies"
            value: "['foo', 'bar']"
          - key: "env"
            type: "plain"
            value: |
              {
              "http_proxy" => "https://my_http_proxy.company.com:3128",
              "https_proxy" => "https://my_http_proxy.company.com:3128",
              "no_proxy" => "localhost, 127.0.0.1, company.com"
              }
      - unicorn:
          - key: "worker_processes"
            value: 5
          - key: "pidfile"
            value: "/opt/gitlab/var/unicorn/unicorn.pid"

Gitlab have many other settings ([see official documentation](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)), and you can add them with this special variable `gitlab_extra_settings` with the concerned setting and the `key` and `value` keywords.

## Dependencies

None.

## Example Playbook

    - hosts: servers
      vars_files:
        - vars/main.yml
      roles:
        - { role: ansible-role.gitlab }

*Inside `vars/main.yml`*:

    gitlab_external_url: "https://gitlab.example.com/"

## License

MIT / BSD

Кратко, что сделано в iptables/apply-iptables-gitlab.sh:

Логика IPv4
TRUSTED_IPV4_SOURCES (по умолчанию 72.56.1.35) — с этих адресов INPUT -j ACCEPT: любой порт, весь «белый» доступ, который вы хотите оставить.
PRIVATE_IPV4_CIDRS (по умолчанию 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16) — только с этих сетей разрешён новый TCP на PORTS_TCP. С любого другого публичного IP к 22/80/443/… не пустит (политика INPUT DROP).
IPv6
PRIVATE_IPV6_CIDRS по умолчанию fc00::/7,fe80::/10 — то же ограничение NEW TCP на PORTS_TCP.
TRUSTED_IPV6_SOURCES по умолчанию пусто; при необходимости — список через запятую для полного INPUT, как у IPv4.
Важно
ICMP по-прежнему можно оставить глобально (ALLOW_ICMP=1) — это не TCP-порты, нужно для PMTUD; при желании отключите переменными.
Если GitLab с интернета должен видеть только edge (например HAProxy) с публичным IP — этот IP нужно добавить в TRUSTED_IPV4_SOURCES, иначе с «белых» адресов сервисные порты будут закрыты.
Переменные и описание обновлены в iptables/README.md.
