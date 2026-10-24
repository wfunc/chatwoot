# GitHub runner 构建自用镜像

工作流：`.github/workflows/publish_local_docker.yml`，在 Actions 中显示为 **Build and push myuwhn/chatwoot:local**。

## 一次性配置

1. 在 Docker Hub 创建 Personal Access Token，赋予对 `myuwhn/chatwoot` 推送所需的 Read & Write 权限。
2. 在 GitHub 仓库 **Settings → Secrets and variables → Actions → Secrets → New repository secret** 添加：

   | Secret               | 值                                                     |
   | -------------------- | ------------------------------------------------------ |
   | `DOCKERHUB_USERNAME` | `myuwhn`（或有该镜像仓库推送权限的 Docker Hub 用户名） |
   | `DOCKERHUB_TOKEN`    | 上一步生成的 Docker Hub token                          |

3. 确保仓库已启用 GitHub Actions，并允许使用 `actions/checkout` 和 Docker 官方 actions。Fork 仓库可能需要先在 Actions 页面启用工作流。
4. 将此工作流合入仓库的默认分支，GitHub 才会在网页显示手动运行入口。要构建的分支也必须包含此工作流及需要发布的代码。

无需配置 SSH、服务器密码或本机代理；无需自行安装 runner，使用 GitHub 托管的 Ubuntu x64 runner。私有仓库使用其 Actions 分钟数配额。

## 每次构建

1. 将需要打包的修改提交并推送到 GitHub。Runner 只读取所选分支的已提交代码，不会包含本机未提交文件。
2. 打开 **Actions → Build and push myuwhn/chatwoot:local → Run workflow**。
3. 选择要构建的分支，再点 **Run workflow**。
4. 等待成功，查看运行摘要中的源码 commit、镜像地址和 digest。

构建使用与本地相同的 `docker/Dockerfile`、生产环境及 `linux/amd64` 平台，推送到 `myuwhn/chatwoot:local`。Node 参数使用已在本地成功构建的 4 GiB 堆上限及 16 MiB semi-space，降低资源不足造成构建失败的风险。GitHub 构建不传本机代理参数。依赖层缓存保存在 GitHub Actions 中；第一次通常比后续构建慢。缓存上传失败不会把已经成功发布的镜像判为构建失败。

手动触发用于明确选择发布时机；普通 Git push 不会触发此工作流。发布任务串行执行，避免同时写入 `local` 标签。本流程只负责构建和推送，不会登录服务器、执行数据库迁移或重启服务。

## 与仓库原有发布工作流的关系

原有的 `publish_ee_docker.yml`、`publish_foss_docker.yml` 等工作流仍保留，它们面向上游 `chatwoot/chatwoot` 仓库。如果此 fork 不需要上游发布任务，可在 Actions 中分别停用它们；自用镜像请运行上面指定的工作流。
