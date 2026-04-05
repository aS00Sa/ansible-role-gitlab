# Пример топологии btnx (HAProxy/Traefik + LDAP + OmniAuth). В плейбуке используйте шаблон gitlab.rb.all.j2
# и переменные: gitlab_reverse_proxy_ssl_termination, gitlab_nginx_listen_addresses, gitlab_ldap_servers_ruby,
# gitlab_omniauth_ruby, gitlab_gitlab_shell_ssh_port, gitlab_registry_*, и т.д. (см. defaults/main.yml).
#
## Public URL (users access this via HAProxy/Traefik)
external_url 'https://gitlab.btnxlocal.ru'

## GitLab bundled NGINX listens internally (HTTP only) on GitLab node
nginx['listen_addresses'] = ['192.168.25.125', '127.0.0.1']
nginx['listen_port'] = 8443
nginx['listen_https'] = false
nginx['listen_http']  = true

# TLS terminates on reverse proxy (HAProxy/Traefik). Omnibus must not load local certs for nginx/registry.
# See https://docs.gitlab.com/omnibus/settings/ssl/#configure-a-reverse-proxy-or-load-balancer-ssl-termination
letsencrypt['enable'] = false
nginx['redirect_http_to_https'] = false
registry_nginx['listen_https'] = false
registry_nginx['redirect_http_to_https'] = false

### GitLab Shell settings for GitLab
gitlab_rails['gitlab_shell_ssh_port'] = 2222
gitlab_rails['gitlab_shell_git_timeout'] = 10800

## Trust reverse proxies in chain: HAProxy edge + Traefik managers
nginx['real_ip_header'] = 'X-Forwarded-For'
nginx['real_ip_recursive'] = 'on'
nginx['real_ip_trusted_addresses'] = [
    '192.168.25.22',
    '72.56.1.35',      # HAProxy edge
    '127.0.0.1'
]

## Rails-level trust for proxy chain
gitlab_rails['trusted_proxies'] = [
    '192.168.25.22',
    '72.56.1.35',
    '127.0.0.1'
]

## Optional: registry through same public host
registry_external_url 'https://gitlab.btnxlocal.ru'
gitlab_rails['registry_enable'] = true
gitlab_rails['registry_host'] = 'gitlab.btnxlocal.ru'
gitlab_rails['registry_path'] = '/var/opt/gitlab/gitlab-rails/shared/registry'

## IMPORTANT:
## Do NOT set custom nginx['proxy_set_headers'] here for this topology.
### LDAP Configuration ###
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = {
  'main' => {
    'label' => 'BTNX LDAP',
    'host' => '192.168.25.134',
    'port' => 636,
    'uid' => 'uid',
    'encryption' => 'simple_tls',
    'verify_certificates' => false,
    'bind_dn' => 'cn=admin,dc=btnx,dc=internal',
    'password' => 'LDAPadm1n2026',
    'base' => 'ou=People,dc=btnx,dc=internal',
    'active_directory' => false,
    'allow_username_or_email_login' => true,
    'block_auto_created_users' => false,
    'attributes' => {
      'username' => ['uid'],
      'email' => ['mail'],
      'name' => 'cn',
      'first_name' => 'givenName',
      'last_name' => 'sn'
    }
  }
}
#
### OmniAuth (Keycloak SSO) ###
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_auto_link_ldap_user'] = true
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_providers'] = [
  {
    name: 'openid_connect',
    label: 'Keycloak',
    args: {
      name: 'openid_connect',
      scope: ['openid', 'profile', 'email'],
      response_type: 'code',
      issuer: 'https://keycloak.bmd.su/realms/master',
      discovery: true,
      client_auth_method: 'query',
      uid_field: 'preferred_username',
      pkce: true,
      client_options: {
        identifier: 'gitlab',
        secret: 'gXWQ29oZ0Bs0uW4BZavjM5ujq2ZjY7h1',
        redirect_uri: 'https://gitlab.btnxlocal.ru/users/auth/openid_connect/callback'
      }
    }
  }
]
gitlab_rails['prevent_ldap_sign_in'] = true
#

# Disable auto-ban/lock side effects on repeated bad credentials (browser/IDE stale passwords).
# # These are GitLab application settings applied during reconfigure.
gitlab_rails['initial_application_settings'] = {
  'failed_authentication_ban_for_git_and_api_enabled' => false,
  'max_login_attempts' => 99999,
  'failed_login_attempts_unlock_period_in_minutes' => 1
}
#