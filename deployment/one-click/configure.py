#!/usr/bin/env python3
"""Prepare the deployment dotenv without executing it as shell code."""

import argparse
import os
from pathlib import Path
import re
import secrets
import sys

ROOT = Path(__file__).resolve().parent
ENV_FILE = ROOT / '.env'


def read_values(text):
    values = {}
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        key, separator, value = line.partition('=')
        if not separator:
            raise ValueError(f'无效的 .env 配置行：{key}')
        values[key.strip()] = value.strip().strip('\"\'')
    return values


def prepare(args):
    template = (ROOT / '.env.example').read_text()
    text = ENV_FILE.read_text() if ENV_FILE.exists() else template
    existing = read_values(text)
    defaults = read_values(template)
    values = {**defaults, **existing}
    changes = {key: value for key, value in defaults.items() if key not in existing}
    if args.domain:
        changes['DOMAIN'] = args.domain
    if args.email:
        changes['CERTBOT_EMAIL'] = args.email
    if args.external_proxy:
        changes['MANAGE_NGINX'] = 'false'
    values.update(changes)
    domain = values.get('DOMAIN', '')
    if domain == 'chat.example.com' or not re.fullmatch(
        r'(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+'
        r'[a-zA-Z]{2,63}', domain
    ):
        raise ValueError('请使用 --domain 传入真实域名，或先修改 .env 中的 DOMAIN；不要包含 https:// 或路径')
    if values.get('MANAGE_NGINX') not in ('true', 'false'):
        raise ValueError('MANAGE_NGINX 必须为 true 或 false')
    if values['MANAGE_NGINX'] == 'true':
        email = values.get('CERTBOT_EMAIL', '')
        if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email) or email == 'admin@example.com':
            raise ValueError('自动申请证书需要真实邮箱，请通过 --email 传入')
    port = values.get('APP_PORT', '3000')
    if not port.isdigit() or not 1024 <= int(port) <= 65535:
        raise ValueError('APP_PORT 必须为 1024 到 65535 之间的端口')
    expected_url = f'https://{domain}'
    if values.get('FRONTEND_URL') and values['FRONTEND_URL'].rstrip('/') != expected_url:
        raise ValueError('FRONTEND_URL 与 DOMAIN 不一致；改域名时请同步修改 FRONTEND_URL')
    changes['FRONTEND_URL'] = expected_url
    for key, size in {
        'SECRET_KEY_BASE': 64,
        'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY': 16,
        'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY': 16,
        'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT': 16,
        'POSTGRES_PASSWORD': 32,
        'REDIS_PASSWORD': 32,
    }.items():
        if not values.get(key):
            changes[key] = secrets.token_hex(size)
    for key, value in changes.items():
        pattern = rf'^{re.escape(key)}=.*$'
        if re.search(pattern, text, flags=re.MULTILINE):
            text = re.sub(pattern, lambda match: f'{key}={value}', text, flags=re.MULTILINE)
        else:
            text += f'\n{key}={value}\n'
    # Refuse duplicate keys so the installer and Compose use the same values.
    active_keys = [line.partition('=')[0].strip() for line in text.splitlines()
                   if line.strip() and not line.lstrip().startswith('#')]
    if len(active_keys) != len(set(active_keys)):
        raise ValueError('.env 中存在重复配置项，请合并后重试')
    os.umask(0o077)
    ENV_FILE.write_text(text)
    ENV_FILE.chmod(0o600)
    print('已准备 .env：保留现有配置，仅补齐缺少的密钥；未输出密码。')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--domain')
    parser.add_argument('--email')
    parser.add_argument('--external-proxy', action='store_true')
    parser.add_argument('--get', help='Read one non-secret deployment setting')
    args = parser.parse_args()
    try:
        if args.get:
            allowed = {'DOMAIN', 'CERTBOT_EMAIL', 'APP_PORT', 'MANAGE_NGINX', 'FRONTEND_URL'}
            if args.get not in allowed:
                raise ValueError('此命令不能输出密钥或密码')
            print(read_values(ENV_FILE.read_text()).get(args.get, ''))
        else:
            prepare(args)
    except (ValueError, OSError) as error:
        print(f'配置错误：{error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
