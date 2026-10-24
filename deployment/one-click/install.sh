#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$DEPLOY_DIR"
ENV_ARGS=()
PREPARE_ONLY=false

die() { echo "错误：$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
用法：
  sudo bash install.sh --domain chat.your-domain.com --email admin@your-domain.com
  sudo bash install.sh --domain chat.your-domain.com --external-proxy
  bash install.sh --prepare-only --domain chat.your-domain.com --external-proxy
  sudo bash install.sh                     # 使用已有 .env，再次部署

--external-proxy  已有宝塔/Nginx 时使用，不安装或修改代理和证书
--prepare-only    只生成 .env，不安装软件、不启动容器
EOF
}

while (($#)); do
  case "$1" in
    --domain|--email)
      (($# >= 2)) || die "$1 缺少参数"
      ENV_ARGS+=("$1" "$2"); shift 2 ;;
    --external-proxy) ENV_ARGS+=("$1"); shift ;;
    --prepare-only) PREPARE_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1；运行 bash install.sh --help 查看用法" ;;
  esac
done

if [[ "$PREPARE_ONLY" == false ]]; then
  [[ "$EUID" == 0 ]] || die '安装需要 root 权限，请使用 sudo bash install.sh ...'
  [[ $(uname -m) == x86_64 ]] || die '当前应用镜像仅支持 x86_64/amd64'
  [[ -r /etc/os-release ]] || die '自动安装支持 Ubuntu 22.04 / 24.04'
  # shellcheck disable=SC1091
  . /etc/os-release
  case "$ID:$VERSION_ID" in
    ubuntu:22.04|ubuntu:24.04) ;;
    *) die '自动安装支持 Ubuntu 22.04 / 24.04；其他系统请自行安装 Docker 和代理' ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
  if ! command -v python3 >/dev/null; then
    apt-get update
    apt-get install -y python3
  fi
fi

command -v python3 >/dev/null || die '生成配置需要 Python 3'
if ((${#ENV_ARGS[@]})); then
  python3 configure.py "${ENV_ARGS[@]}"
else
  python3 configure.py
fi
if [[ "$PREPARE_ONLY" == true ]]; then
  echo '仅准备配置完成；未安装软件、未启动或更新服务。'
  exit 0
fi

DOMAIN=$(python3 configure.py --get DOMAIN)
CERTBOT_EMAIL=$(python3 configure.py --get CERTBOT_EMAIL)
APP_PORT=$(python3 configure.py --get APP_PORT)
MANAGE_NGINX=$(python3 configure.py --get MANAGE_NGINX)
FRONTEND_URL=$(python3 configure.py --get FRONTEND_URL)

if [[ "$MANAGE_NGINX" == true && -d /www/server/nginx ]]; then
  die '检测到宝塔 Nginx，请使用 --external-proxy，并在宝塔中配置反向代理'
fi

echo '[1/6] 准备 Docker 和 Compose'
apt-get update
apt-get install -y ca-certificates curl
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat > /etc/apt/sources.list.d/docker-chatwoot.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $VERSION_CODENAME
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif ! docker compose version >/dev/null 2>&1; then
  apt-get install -y docker-compose-plugin
fi
systemctl enable --now docker
docker compose version
docker compose config --quiet
EXISTING_DIRS=$(docker ps -a --filter label=com.docker.compose.project=chatwoot \
  --format '{{.Label "com.docker.compose.project.working_dir"}}' | sort -u)
while IFS= read -r existing_dir; do
  if [[ -n "$existing_dir" && "$existing_dir" != "$DEPLOY_DIR" ]]; then
    die "已有 chatwoot 项目位于 $existing_dir，请在原部署目录操作，避免接管另一套安装"
  fi
done <<< "$EXISTING_DIRS"

echo '[2/6] 拉取镜像，启动 PostgreSQL 和 Redis'
docker compose pull
docker compose up -d --wait --wait-timeout 180 postgres redis

echo '[3/6] 准备数据库结构和初始配置'
docker compose stop rails sidekiq
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

echo '[4/6] 启动 Rails 和 Sidekiq'
docker compose up -d --no-deps rails sidekiq
ready=false
for ((attempt=1; attempt<=90; attempt++)); do
  if curl -fsS --max-time 5 -H 'X-Forwarded-Proto: https' "http://127.0.0.1:$APP_PORT/" -o /dev/null 2>/dev/null; then
    ready=true
    break
  fi
  sleep 2
done
if [[ "$ready" != true ]]; then
  docker compose logs --tail=80 rails sidekiq
  die '应用未在等待时间内就绪；检查上述日志，修正配置后可再次运行脚本'
fi
if ! docker compose exec -T sidekiq sh -c 'kill -0 1'; then
  docker compose logs --tail=80 sidekiq
  die 'Sidekiq 未正常运行，请检查上述日志'
fi

if [[ "$MANAGE_NGINX" == true ]]; then
  echo '[5/6] 配置 Nginx 和 HTTPS'
  apt-get install -y nginx certbot python3-certbot-nginx
  SITE="/etc/nginx/sites-available/chatwoot-one-click-$DOMAIN"
  ENABLED_SITE="/etc/nginx/sites-enabled/chatwoot-one-click-$DOMAIN"
  if [[ -e "$SITE" ]]; then
    grep -q '^# Managed by Chatwoot deployment/one-click\.' "$SITE" || die "不覆盖非本脚本管理的站点：$SITE"
  else
    sed -e "s/__DOMAIN__/$DOMAIN/g" -e "s/__APP_PORT__/$APP_PORT/g" nginx.conf.template > "$SITE"
  fi
  if [[ -e "$ENABLED_SITE" || -L "$ENABLED_SITE" ]]; then
    [[ -L "$ENABLED_SITE" && $(readlink "$ENABLED_SITE") == "$SITE" ]] || die "不覆盖现有站点：$ENABLED_SITE"
  else
    ln -s "$SITE" "$ENABLED_SITE"
  fi
  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
  certbot --nginx --non-interactive --agree-tos --email "$CERTBOT_EMAIL" \
    --domain "$DOMAIN" --redirect --keep-until-expiring
  systemctl enable --now certbot.timer
  nginx -t
  systemctl reload nginx
  echo '[6/6] 检查 HTTPS 访问和重定向'
  curl -fsSL --max-redirs 5 --max-time 30 "$FRONTEND_URL/" -o /dev/null
else
  echo '[5/6] 外部代理模式：未安装或修改 Nginx 和证书'
  echo "请将 $DOMAIN 的 HTTPS 站点代理到 http://127.0.0.1:$APP_PORT。"
  echo '在负责 HTTPS 的反向代理 location 中设置：'
  cat <<'NGINX_HEADERS'
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Forwarded-Ssl $https;
NGINX_HEADERS
  echo '[6/6] 容器侧已就绪；域名访问需在完成外部代理配置后验证。'
fi

docker compose ps
echo "部署完成。访问 $FRONTEND_URL/installation/onboarding 创建首个管理员。"
echo '邮箱确认默认关闭；是否需要公众注册由 .env 中 ENABLE_ACCOUNT_SIGNUP 控制。'
echo "配置和密钥保存在 $DEPLOY_DIR/.env，后续部署保留该文件及三个数据卷。"
