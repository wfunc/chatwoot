# Chatwoot 一键搭建

这个目录可以单独复制到新服务器，例如 `/data/chatwoot`。不需要上传源码或在服务器编译。

默认镜像 `myuwhn/chatwoot:local`，默认中文、关闭邮箱确认（`ENABLE_EMAIL_CONFIRMATION=false`）、关闭公众注册。首个管理员通过安装引导创建；关闭邮箱确认不会自动配置邮件发送。

## 全新 Ubuntu 服务器

支持 Ubuntu 22.04 / 24.04、x86_64/amd64。建议 4 核、8 GB 内存、60 GB 以上磁盘。

先把真实域名的 DNS 记录指向服务器，并开放 80、443 和你使用的 SSH 端口。若配置了 AAAA 记录，也需要正确指向可访问此服务的服务器。

上传整个目录后执行（替换真实域名和邮箱）：

```bash
cd /data/chatwoot
sudo bash install.sh --domain chat.your-domain.com --email admin@your-domain.com
```

一次执行会准备 `.env`、安装缺少的 Docker/Compose、拉取镜像、启动 PostgreSQL/Redis、初始化数据库、启动应用、配置系统 Nginx、申请 HTTPS 证书、启用自动续期并验证访问。证书申请依赖 DNS 和公网 80/443 正常可用。

完成后访问 `https://chat.your-domain.com/installation/onboarding` 创建管理员。

新建账号默认使用 Bell 提醒音，开启全部三类会话声音提醒、每 30 秒重复提醒和全部推送通知事件；电子邮件通知偏好保持原默认值。浏览器推送偏好默认开启，但每个浏览器仍需用户点击允许通知，授权入口在个人设置的通知偏好中。

新建收件箱默认关闭电子邮件收集。添加协作者时，如果其中只有一个商户且收件箱尚无所属商户，会自动绑定该商户；已有归属不会被覆盖。只有一个收件箱的商户点击“设置 / 收件箱”会直接进入该收件箱设置，管理员继续显示列表。

## 已有宝塔或反向代理

```bash
sudo bash install.sh --domain chat.your-domain.com --external-proxy
```

脚本只管理 Docker 应用栈，不安装或修改代理、证书。应用端口仅绑定 `127.0.0.1:3000`。在宿主机的宝塔/Nginx 中，把该 HTTPS 域名代理到 `http://127.0.0.1:3000`，启用 WebSocket，在实际 `proxy_pass` 所在的 location 中保留：

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Ssl $https;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

这里的 Nginx 应直接负责 HTTPS。如果代理运行在另一个容器中，需要自行配置其到应用的容器网络，不能用代理容器的 `127.0.0.1` 访问 Rails。

Rails 默认启用 `FORCE_SSL=true`；代理缺少原始 HTTPS 协议头时会发生重定向循环。外部代理模式仅确认容器就绪，域名和证书需要自己配置与验收。

## `.env` 配置

`.env.example` 是可提交的模板，不含真实密码。首次执行自动生成同目录 `.env`，权限为 `600`，实际密码不会提交到 Git。

也可以先只生成配置，再编辑：

```bash
bash install.sh --prepare-only --domain chat.your-domain.com --external-proxy
nano .env
sudo bash install.sh
```

使用自动 Nginx 模式时，在上面的准备命令中改用 `--email admin@your-domain.com`，不要传 `--external-proxy`。

| 配置                           | 默认值 / 用途                                          |
| ------------------------------ | ------------------------------------------------------ |
| `ENABLE_EMAIL_CONFIRMATION`    | `false`，无需点击邮件确认即可登录                      |
| `ENABLE_ACCOUNT_SIGNUP`        | `false`，关闭公众注册；要测试普通注册可自行改为 `true` |
| `DEFAULT_LOCALE`               | `zh_CN`，新安装默认中文                                |
| `FRONTEND_URL`                 | 自动生成 `https://你的域名`                            |
| `MANAGE_NGINX`                 | `true` 自动配置系统 Nginx；`false` 使用已有代理        |
| `APP_PORT`                     | `3000`，宿主机本地端口，初次安装前可修改               |
| `CHATWOOT_IMAGE`               | `myuwhn/chatwoot:local`，也可指定已验证的 digest       |
| 数据库、Redis、应用和 MFA 密钥 | 首次自动生成；后续保留已有非空值                       |

再次执行保留已有 `.env` 设置，不会强制把你主动改为 `true` 的邮箱确认改回 `false`。修改 `.env` 后需要重建应用容器才生效。

SMTP 配置在模板末尾注释中。需要邀请、找回密码和邮件通知时再配置 SMTP，不要把密码发到聊天或提交到 Git。

## 再次执行和更新

```bash
cd /data/chatwoot
sudo bash install.sh
```

会拉取新镜像、保留数据库和上传附件、暂停应用执行迁移，再启动应用。执行期间有短暂服务中断。正式给客户部署前应先备份，再更新。

数据库和 Redis 密码只在首次初始化卷时设置；有数据后不要仅修改 `.env` 中的密码。更换域名或端口时需要同步调整现有代理；脚本不会覆盖已配置好证书的站点。

Compose 项目名固定为 `chatwoot`，用于独立服务器上的单套安装。不要在已运行另一套同名 Compose 项目的服务器上直接执行。已有系统迁移应单独规划备份和恢复。

## 查看运行状态

```bash
docker compose ps
docker compose logs -f --tail=100 rails sidekiq
```

三个持久化卷：`chatwoot_postgres_data`、`chatwoot_redis_data`、`chatwoot_storage_data`。备份需包含数据库、上传附件和 `.env`；只复制部署目录不会带走数据库。不要执行 `docker compose down -v`，该命令会删除数据卷。

## 文件说明

| 文件                  | 用途                                             |
| --------------------- | ------------------------------------------------ |
| `.env.example`        | 统一部署配置模板                                 |
| `.env`                | 实际配置和密钥，自动生成、不提交                 |
| `install.sh`          | 一键安装及再次部署入口                           |
| `configure.py`        | 验证参数、生成或保留密钥，不执行 `.env` 中的内容 |
| `compose.yaml`        | Rails、Sidekiq、PostgreSQL 和 Redis              |
| `nginx.conf.template` | 自动 HTTPS 配置之前使用的代理模板                |

参考 [Docker Ubuntu 安装说明](https://docs.docker.com/engine/install/ubuntu/) 和 [Chatwoot Docker 部署说明](https://developers.chatwoot.com/self-hosted/deployment/docker)，数据库准备使用 `db:chatwoot_prepare`。
