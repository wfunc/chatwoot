# 商户角色设计与执行方案

## 方案目标

新增一个账号内角色 `merchant`，用于付费商户后台运营。商户不是平台管理员，也不是普通客服。商户只能管理管理员分配给自己的资源，并且可以在额度范围内创建自己的客服 `agent`。商户到期后，商户本人和其创建的全部 `agent` 都失效，无法继续使用后台。同时，系统需要在到期前提供明确的续费提醒，例如剩余 3 天时，在后台顶部展示“当前系统使用还有 3 天到期，请及时续费！”。

## 当前系统基线

当前账号内基础角色只有两个：

- `agent`
- `administrator`

定义在 `app/models/account_user.rb`。

当前 inbox 管理是管理员独占：

- `show?` 可查看
- `update?`、`create?`、`destroy?` 是管理员专属

见 `app/policies/inbox_policy.rb`。

因此本方案不是“给 agent 加一点权限”，而是明确新增 `merchant` 角色，并建立商户资源边界。

## 最终角色模型

系统内角色分为四类：

| 角色 | 作用 | 权限边界 |
|---|---|---|
| `SuperAdmin` | 平台级管理 | 管理实例、账号、平台配置，不参与商户日常运营 |
| `administrator` | 主账号管理员 | 管理全部商户、全部 inbox、全部 agent、平台业务配置 |
| `merchant` | 商户管理员 | 只能管理自己名下 inbox 和自己创建的 agent |
| `agent` | 客服坐席 | 只能处理会话，不能做商户级配置 |

## 核心业务规则

以下规则是本方案的硬约束，后续开发和验收都必须满足：

- 一个 `merchant` 可以拥有多个 `agent`
- 一个 `agent` 只能属于一个 `merchant`
- 一个 `merchant` 可以被分配多个 `inbox`
- 一个 `inbox` 只能归属于一个 `merchant`
- `merchant` 不能创建 `inbox`
- `merchant` 只能管理管理员分配给自己的 `inbox`
- `merchant` 可以创建 `agent`，但不能超过管理员设置的上限
- `merchant` 创建的 `agent` 只能访问该 `merchant` 名下资源
- `merchant` 到期后，其本人和其名下全部 `agent` 无法登录后台
- `merchant` 到期前需要显示续费提醒，提醒对象包括 `merchant` 本人和其名下 `agent`
- 到期提醒至少支持“剩余天数”动态展示，剩余 3 天时默认文案为“当前系统使用还有 3 天到期，请及时续费！”
- `administrator` 始终拥有跨商户查看、分配、接管权限

## 功能范围

这一期必须做完的功能如下。

### 一、角色与数据模型

必须新增以下能力：

- 新增账号内角色 `merchant`
- 为 `merchant` 增加状态字段
- 为 `merchant` 增加有效期字段
- 为 `merchant` 增加 agent 数量上限字段
- 为 `agent` 增加所属商户字段
- 为 `inbox` 增加所属商户字段
- 为权限判断链路增加 `merchant?` 判定
- 为前端当前角色判断增加 `merchant` 识别

建议的数据字段设计如下：

`account_users`

- `role`
  新增枚举值：`merchant`
- `merchant_status`
  建议值：`active`、`expired`、`suspended`
- `merchant_expires_at`
- `agent_limit`
  仅 `merchant` 使用
- `parent_merchant_id`
  仅 `agent` 使用，指向所属 `merchant` 的 `account_users.id`

`inboxes`

- `merchant_owner_id`
  指向所属 `merchant` 的 `account_users.id`

如果后续更偏向结构清晰，也可以拆新表：

- `merchant_profiles`
- `merchant_inboxes`

但从 MVP 来看，直接在现有表补字段更快。

### 二、管理员功能

管理员侧必须具备以下功能：

- 创建商户账号
- 编辑商户账号
- 设置商户有效期
- 设置商户 agent 上限
- 停用商户
- 恢复商户
- 查看商户名下 agent 数量和使用情况
- 创建 inbox
- 将 inbox 分配给某个商户
- 变更 inbox 归属商户
- 查看商户名下全部 inbox
- 查看商户名下全部 agent
- 接管商户资源

管理员明确不能缺少的页面：

- 商户列表页
- 商户创建页
- 商户详情页
- 商户编辑页
- 商户名下 agent 列表页
- 商户名下 inbox 列表页
- inbox 分配商户操作入口

### 三、商户功能

商户侧必须具备以下功能：

- 登录后台
- 仅看到自己名下 inbox
- 仅看到自己名下 agent
- 创建 agent
- 编辑自己创建的 agent
- 停用自己创建的 agent
- 将自己名下 agent 分配到自己名下 inbox
- 管理自己名下 inbox 的业务配置

商户可操作的 inbox 功能必须明确包含：

- 修改 inbox 名称
- 修改欢迎页标题
- 修改欢迎页副标题
- 修改欢迎语
- 修改 widget 颜色
- 修改 widget 功能开关
- 修改回复时间
- 修改允许访客结束会话等 widget 行为项
- 修改可见的业务展示配置

商户明确不能做的事：

- 新建 inbox
- 删除 inbox
- 管理其他商户 inbox
- 管理平台账单或订阅
- 访问全局系统设置
- 访问 Super Admin
- 创建超出额度的 agent
- 管理不属于自己的 agent

### 四、Agent 功能

商户创建的 `agent` 必须满足：

- 只能登录在有效商户下
- 只能看到被分配的 inbox 会话
- 只能处理自己权限范围内的 conversation
- 不能创建 inbox
- 不能修改商户级 inbox 配置
- 不能跨商户访问联系人和会话

### 五、到期与停用控制

这部分必须做成系统级约束，不能只靠前端隐藏。

必须实现的逻辑：

- 到期前提醒逻辑
- 登录时校验商户是否过期
- 请求时校验商户是否过期
- 商户过期后禁止商户登录
- 商户过期后禁止其名下全部 agent 登录
- 已登录用户在下一次请求时失效
- 在后台顶部展示即将到期提醒 banner
- 到期提醒对 `merchant` 和其名下 `agent` 都生效
- 到期提醒文案支持动态剩余天数
- 默认提醒阈值按 3 天设计，至少在剩余 3 天时出现提醒
- 剩余 3 天时默认文案为“当前系统使用还有 3 天到期，请及时续费！”
- 页面提示账号已到期
- 管理员续期后恢复使用
- 管理员手动停用时也按同样逻辑失效

## 权限矩阵

后续审查时，以下表就是验收基准。

| 功能 | administrator | merchant | agent |
|---|---|---|---|
| 创建 inbox | 是 | 否 | 否 |
| 删除 inbox | 是 | 否 | 否 |
| 分配 inbox 给 merchant | 是 | 否 | 否 |
| 编辑自己名下 inbox 基础配置 | 是 | 是 | 否 |
| 编辑欢迎页/欢迎语/widget 配置 | 是 | 是 | 否 |
| 查看自己名下 inbox | 是 | 是 | 仅被分配的 |
| 创建 agent | 是 | 是，受额度限制 | 否 |
| 编辑自己名下 agent | 是 | 是 | 否 |
| 查看全部 agent | 是 | 否 | 否 |
| 查看自己名下 agent | 是 | 是 | 否 |
| 处理 conversation | 是 | 是，仅自己资源 | 是，仅自己资源 |
| 查看到期提醒 banner | 否 | 是 | 是，限所属商户未到期但即将到期时 |
| 查看报表 | 保持现状 | 本期不做，默认否 | 否 |
| 管理账单/订阅 | 是 | 否 | 否 |
| 进入全局设置 | 是 | 否 | 否 |

## 开发执行流程

这部分按阶段执行，后续开发必须按顺序推进。

### 阶段 1：数据模型改造

目标是把角色和归属关系落到数据库里。

本阶段任务：

- 给 `AccountUser.role` 增加 `merchant`
- 给 `account_users` 增加 `merchant_status`
- 给 `account_users` 增加 `merchant_expires_at`
- 给 `account_users` 增加 `agent_limit`
- 给 `account_users` 增加 `parent_merchant_id`
- 给 `inboxes` 增加 `merchant_owner_id`
- 补必要索引
- 补基础 model 关联和校验

本阶段完成标准：

- 可以在数据库中创建 `merchant`
- 可以把 `agent` 归属到某个 `merchant`
- 可以把 `inbox` 归属到某个 `merchant`

### 阶段 2：后端权限与查询范围

目标是让后端真正按商户边界裁切资源。

本阶段任务：

- 修改 `AccountUser` 角色判断
- 修改 `InboxPolicy`
- 修改 `ConversationPolicy`
- 修改 `ContactPolicy`
- 修改 agent 管理相关 policy
- 修改 inbox 查询范围
- 修改 agent 查询范围
- 修改 conversation 查询范围
- 修改 contact 查询范围
- 为商户 agent 数量限制增加服务层校验
- 为到期状态增加统一校验入口

涉及的核心代码位置至少包括：

- `app/models/account_user.rb`
- `app/models/user.rb`
- `app/policies/inbox_policy.rb`
- `app/policies/conversation_policy.rb`
- `app/policies/contact_policy.rb`
- `app/controllers/api/v1/accounts/inboxes_controller.rb`
- `agents` 和 `account_users` 相关 controller、finder、serializer

本阶段完成标准：

- 商户只能看到自己资源
- agent 只能看到自己所属商户资源
- 商户无法创建 inbox
- 商户可以更新自己名下 inbox 配置
- 超过 agent 上限时创建失败
- 过期后请求被拒绝

### 阶段 3：管理员后台功能

目标是把商户管理入口补齐。

本阶段任务：

- 新增商户列表页
- 新增商户创建页
- 新增商户编辑页
- 新增商户到期时间设置
- 新增商户 agent 上限设置
- 新增商户状态设置
- 新增 inbox 分配给商户的操作
- 新增商户详情里查看 inbox 和 agent 的能力

本阶段完成标准：

- 管理员可以完整创建一个商户
- 管理员可以把某个 inbox 分配给该商户
- 管理员可以看到商户剩余额度和到期状态

### 阶段 4：商户后台功能

目标是让商户真正可用。

本阶段任务：

- 商户登录后有独立可见菜单
- 商户只能看到自己的 inbox
- 商户可以进入 inbox 设置页
- 商户可以修改欢迎页和 widget 配置
- 商户可以进入 agent 管理页
- 商户可以新增 agent
- 商户可以编辑和停用自己的 agent
- 商户可以把自己的 agent 分配到自己的 inbox

本阶段完成标准：

- 商户在不接触管理员功能的前提下，能独立运营自己的客服系统
- 商户无法看到其他商户数据
- 商户无法越权访问管理员页面

### 阶段 5：到期与失效机制

目标是把付费时效做成可控的商业规则。

本阶段任务：

- 新增即将到期提醒规则
- 新增剩余天数计算逻辑
- 新增后台顶部到期提醒 banner
- 统一 `merchant` 与其名下 `agent` 的到期提醒展示
- 登录前校验商户状态
- 会话内请求校验商户状态
- 过期提示页或错误消息
- 管理员续费恢复逻辑
- 商户停用逻辑
- 商户名下 agent 联动失效逻辑

本阶段完成标准：

- 商户在剩余 3 天时能看到“当前系统使用还有 3 天到期，请及时续费！”提示
- 商户名下 agent 在剩余 3 天时能看到同样的到期提醒
- 商户到期后不能继续登录
- 商户名下 agent 到期后不能继续登录
- 管理员续期后恢复正常使用

### 阶段 6：审查与回归验收

这不是可选项，必须在开发后逐条走。

验收必须覆盖以下场景：

- 管理员能创建商户
- 管理员能设置商户有效期
- 管理员能设置商户 agent 上限
- 管理员能分配 inbox 给商户
- 商户看不到“新建 inbox”
- 商户能编辑自己 inbox 的欢迎页和 widget 配置
- 商户不能编辑非自己 inbox
- 商户能创建 agent
- 商户超过额度后不能继续创建 agent
- 商户创建的 agent 只能访问自己商户范围数据
- 商户在剩余 3 天时看到到期提醒
- 商户名下 agent 在剩余 3 天时看到到期提醒
- 管理员续期后到期提醒消失或按新的剩余天数刷新
- 商户到期后登录失败
- 商户到期后其名下 agent 登录失败
- 续期后商户与 agent 恢复正常

## 不在本期范围内

为了控制复杂度，这些明确不放进第一期：

- 多商户共享同一个 inbox
- 商户自定义账单和订阅中心
- 商户自助购买和续费
- 商户自定义权限组合器
- 商户级报表权限拆分
- 商户之间的数据转移自动化
- 多层级商户组织架构

## 推荐实现策略

从工程复杂度看，第一期建议采用以下策略：

- 新增基础角色 `merchant`
- 明确新增资源归属字段
- 不复用 Enterprise 的 `custom_role` 来硬拼商户能力
- 商户权限采用“固定能力集合”
- 后续如果商户套餐需要更细权限，再考虑在 `merchant` 之上追加能力开关

原因：

- 商户不是“更细粒度的客服”，而是“受限制的二级管理员”
- 这和当前 `custom_role` 的定位不一样
- 直接做 `merchant` 更清晰，也更方便后面做套餐化

## 文档维护说明

本文件用于沉淀 `merchant` 角色的一期设计边界、实施顺序和验收口径。随着实现推进，文档应持续更新，以保持以下内容与代码一致：

- 角色模型与数据结构
- 权限矩阵
- 功能边界
- 验收场景

如果后续方案发生明显调整，应优先更新本文档，再推进实现或补充后续设计记录。

## 后续审查标准

后续每次验收，都按下面三条判断是否完成：

1. 数据边界是否正确  
   商户和其 agent 是否只能访问自己名下资源。

2. 权限边界是否正确  
   商户是否能做该做的事，但不能碰管理员能力。

3. 商业规则是否正确  
   agent 上限、有效期、停用恢复是否按管理员设置生效。
