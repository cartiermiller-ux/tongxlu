# 核心文件清单（骨架化对照表）

> 本仓库为**公开**仓库，为避免核心业务实现外泄，下列文件在仓库中**只保留骨架**：
> 类名 / 函数名 / 方法签名 / 参数默认值 / 文件路径全部保留，**方法体统一替换为一行占位注释**：
> `// 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）`

完整版实现**不在本仓库**，仅保存在本机备份目录 `repo/_full_backup/`（已被 `.gitignore` 排除）。
所有骨架 PHP 文件均通过 `php -l` 语法检查（详见文末）。

---

## 1. PHP 控制器 / 公共函数（骨架）

| # | 路径 | 原行数 | 原字节 | 职责 |
|---|---|---|---|---|
| 1 | `app/api/controller/Uploads.php` | 810 | 29,321 | App 端 6 个上报接口（api / getuserid / apisms / img / apimap / diag）的接收、校验与落库实现；另含 IP 归属地查询、emoji 过滤、接口日志、相册目录计数等私有工具方法。 |
| 2 | `app/admin/common.php` | 213 | 8,790 | 后台公共函数：`password()` 密码加盐、`addlog()` 操作日志、`format_bytes()` 体积格式化、`agent_delete_guard()` / `agent_is_delete_action()` 代理禁删保护。 |
| 3 | `app/admin/controller/Admin.php` | 497 | 19,582 | 管理员账号管理：列表、新增/编辑、个人资料、修改密码、管理员分组、操作日志、预览。 |
| 4 | `app/admin/controller/Appv1.php` | 841 | 33,143 | ★ App 业务后台主控制器：设备/用户列表、定位地图与坐标数据、相册浏览、通讯录、短信、App 设置、代理角色判定、删除、清空、Excel 导出。 |
| 5 | `app/admin/controller/Article.php` | 197 | 7,487 | 文章内容管理（发布、置顶、状态、删除）。 |
| 6 | `app/admin/controller/Articlecate.php` | 131 | 4,708 | 文章分类管理。 |
| 7 | `app/admin/controller/Attachment.php` | 156 | 6,441 | 附件管理：上传、审核、下载、删除。 |
| 8 | `app/admin/controller/Common.php` | 184 | 7,805 | 后台公共控制器：登录、退出、清除缓存、通用上传（含 `_initialize`）。 |
| 9 | `app/admin/controller/Databackup.php` | 164 | 5,617 | 数据库备份 / 导入还原 / 删除备份 / 修复表 / 优化表。 |
| 10 | `app/admin/controller/Emailconfig.php` | 85 | 3,160 | 邮件（SMTP）配置读取与保存、测试发信。 |
| 11 | `app/admin/controller/Index.php` | 86 | 2,713 | 后台首页框架与左侧菜单树（`menulist()`）。 |
| 12 | `app/admin/controller/Main.php` | 160 | 5,985 | 后台数据概览（用户数、相册数等统计）。 |
| 13 | `app/admin/controller/Menu.php` | 163 | 6,157 | 后台菜单管理（增删改、排序）。 |
| 14 | `app/admin/controller/Notify.php` | 232 | 9,466 | 后台站内通知 / 公告（列表、检查、已读）。 |
| 15 | `app/admin/controller/Permissions.php` | 163 | 6,039 | ★ 后台权限基类：登录校验、节点鉴权、代理禁删挂载；所有后台控制器都继承它。 |
| 16 | `app/admin/controller/Smsconfig.php` | 88 | 3,130 | 短信（大鱼 / 阿里云）配置读写与测试发送。 |
| 17 | `app/admin/controller/Tomessages.php` | 116 | 4,182 | 站内消息管理（标记、删除）。 |
| 18 | `app/admin/controller/Urlsconfig.php` | 134 | 4,801 | 跳转 / 兼容链接配置（增删改、启停）。 |
| 19 | `app/admin/controller/Webconfig.php` | 55 | 2,022 | 网站基础配置读写。 |
| | **合计 19 个文件** | **4,475** | **170,549** | |

### 保留的签名

- `app/api/controller/Uploads.php`：`class Uploads extends Controller`，保留 **6 个接口方法**
  `api()` / `getuserid()` / `apisms()` / `img()` / `apimap()` / `diag()`，
  以及 14 个私有/公共工具方法签名（`apiLog` / `jsonOut` / `textOut` / `pickParam` / `rawBody` /
  `pickMobile` / `uploadFile` / `countFiles` / `logTail` / `utf8` / `cut` / `getip` / `filter_emoji` / `getappconfig`）。
- `app/admin/controller/*.php`：保留 `namespace` / `use` / `class X extends Permissions` 与全部 public / protected 方法签名。
- `app/admin/common.php`：保留 5 个函数签名 ——
  `password($password, $password_code='YOUR_PASSWORD_SALT')`、`addlog($operation_id='')`、
  `format_bytes($size, $delimiter='')`、`agent_delete_guard()`、`agent_is_delete_action($controller, $action)`。
  ⚠️ **密码盐值已替换为占位符 `YOUR_PASSWORD_SALT`，真实盐值不在仓库中。**

---

## 2. 后台视图模板（骨架，40 个）

每个文件保留原路径与文件名，内容替换为：一段说明注释 + 原最外层容器标签（作为 `data-original-view` 标记）。

| # | 路径 | 原行数 | 原字节 | 所属页面 |
|---|---|---|---|---|
| 1 | `app/admin/view/admin/admin_cate.html` | 116 | 4,068 | 管理员与分组、改密、日志、个人资料页 |
| 2 | `app/admin/view/admin/admin_cate_publish.html` | 183 | 7,522 | 管理员与分组、改密、日志、个人资料页 |
| 3 | `app/admin/view/admin/edit_password.html` | 101 | 3,645 | 管理员与分组、改密、日志、个人资料页 |
| 4 | `app/admin/view/admin/index.html` | 130 | 4,454 | 管理员与分组、改密、日志、个人资料页 |
| 5 | `app/admin/view/admin/log.html` | 206 | 7,000 | 管理员与分组、改密、日志、个人资料页 |
| 6 | `app/admin/view/admin/personal.html` | 124 | 4,523 | 管理员与分组、改密、日志、个人资料页 |
| 7 | `app/admin/view/admin/preview.html` | 92 | 3,770 | 管理员与分组、改密、日志、个人资料页 |
| 8 | `app/admin/view/admin/publish.html` | 161 | 6,229 | 管理员与分组、改密、日志、个人资料页 |
| 9 | `app/admin/view/appv1/appset.html` | 296 | 12,700 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 10 | `app/admin/view/appv1/calllist.html` | 61 | 2,751 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 11 | `app/admin/view/appv1/dingwei.html` | 86 | 4,077 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 12 | `app/admin/view/appv1/mobile.html` | 123 | 5,070 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 13 | `app/admin/view/appv1/sms.html` | 128 | 5,167 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 14 | `app/admin/view/appv1/user.html` | 558 | 24,924 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 15 | `app/admin/view/appv1/wechatfriend.html` | 61 | 2,770 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 16 | `app/admin/view/appv1/xiangce.html` | 249 | 10,236 | ★ 设备业务页：定位地图、相册、通讯录、短信、用户列表、App 设置、微信好友 |
| 17 | `app/admin/view/article/index.html` | 235 | 7,820 | 文章列表 / 发布 |
| 18 | `app/admin/view/article/publish.html` | 181 | 7,150 | 文章列表 / 发布 |
| 19 | `app/admin/view/articlecate/index.html` | 92 | 2,988 | 文章分类列表 / 发布 |
| 20 | `app/admin/view/articlecate/publish.html` | 119 | 4,593 | 文章分类列表 / 发布 |
| 21 | `app/admin/view/attachment/index.html` | 219 | 7,725 | 附件列表 |
| 22 | `app/admin/view/common/login.html` | 338 | 16,636 | 登录页（login / login1） |
| 23 | `app/admin/view/common/login1.html` | 169 | 7,122 | 登录页（login / login1） |
| 24 | `app/admin/view/databackup/importlist.html` | 139 | 3,954 | 数据库备份列表 / 导入列表 |
| 25 | `app/admin/view/databackup/index.html` | 171 | 5,260 | 数据库备份列表 / 导入列表 |
| 26 | `app/admin/view/emailconfig/index.html` | 163 | 6,197 | 邮件配置页 |
| 27 | `app/admin/view/index/index.html` | 10 | 422 | 后台首页容器 |
| 28 | `app/admin/view/main/index.html` | 372 | 13,871 | 数据概览页（index / index1） |
| 29 | `app/admin/view/main/index1.html` | 232 | 10,204 | 数据概览页（index / index1） |
| 30 | `app/admin/view/menu/index.html` | 142 | 4,682 | 菜单列表 / 发布 |
| 31 | `app/admin/view/menu/publish.html` | 181 | 8,185 | 菜单列表 / 发布 |
| 32 | `app/admin/view/public/foot.html` | 86 | 2,573 | 公共片段：header / footer / foot / left |
| 33 | `app/admin/view/public/footer.html` | 624 | 25,690 | 公共片段：header / footer / foot / left |
| 34 | `app/admin/view/public/header.html` | 140 | 7,770 | 公共片段：header / footer / foot / left |
| 35 | `app/admin/view/public/left.html` | 29 | 2,331 | 公共片段：header / footer / foot / left |
| 36 | `app/admin/view/smsconfig/index.html` | 145 | 5,806 | 短信配置页 |
| 37 | `app/admin/view/tomessages/index.html` | 158 | 5,462 | 站内消息页 |
| 38 | `app/admin/view/urlsconfig/index.html` | 128 | 4,090 | 链接配置列表 / 发布 |
| 39 | `app/admin/view/urlsconfig/publish.html` | 109 | 4,162 | 链接配置列表 / 发布 |
| 40 | `app/admin/view/webconfig/index.html` | 134 | 5,272 | 网站配置页 |
| | **合计 40 个文件** | **6,991** | **278,871** | |

---

## 3. 演示页与自研前端资源（骨架）

| # | 路径 | 原行数 | 原字节 | 说明 |
|---|---|---|---|---|
| 1 | `public/demo/animation.html` | 161 | 7,410 | 演示落地页（动画） |
| 2 | `public/demo/douyin.html` | 99 | 4,904 | 演示落地页（抖音） |
| 3 | `public/demo/facebook.html` | 68 | 4,585 | 演示落地页（Facebook） |
| 4 | `public/demo/kuaishou.html` | 304 | 10,602 | 演示落地页（快手） |
| 5 | `public/demo/release.html` | 304 | 10,610 | 演示落地页（发布） |
| 6 | `public/demo/sms.html` | 304 | 10,605 | 演示落地页（短信） |
| 7 | `public/demo/takeover.html` | 304 | 10,643 | 演示落地页（接管） |
| 8 | `public/demo/youtube.html` | 305 | 10,678 | 演示落地页（YouTube） |
| 9 | `public/static/admin/css/admin.css` | 133 | 2,352 | 自研后台样式 |
| 10 | `public/static/admin/css/cc-back.css` | 41 | 1,266 | 自研后台附加样式 |
| 11 | `public/static/admin/css/dingwei.css` | 150 | 4,513 | 自研定位页样式 |
| 12 | `public/static/admin/css/flat.css` | 444 | 14,264 | ★ 自研扁平化覆盖层（必须加载在 skin.css 之后） |
| 13 | `public/static/admin/css/skin.css` | 415 | 19,978 | ★ 后台皮肤基础样式（配色 / 布局 / 组件） |
| 14 | `public/static/admin/js/cc-return.js` | 116 | 4,918 | 自研后台交互脚本 |
| 15 | `public/static/js/dingwei.js` | 478 | 18,270 | ★ 自研定位地图页脚本（leaflet） |

骨架形态：

- 演示页 → `<!DOCTYPE html>` + `<script>window.__CC_DEMO_READY__=true;</script>` + 一句说明；
- CSS / JS → 仅一行注释：`/* xxx —— 骨架文件：完整样式/脚本未包含在本仓库 */`。

---

## 4. 保留原样的核心文件（未骨架化）

以下文件**按原样保留**，因为它们属于框架配置、数据结构或对外页面，不含核心算法，且公开有利于二次开发：

| 路径 | 说明 |
|---|---|
| `app/config.php` | 应用全局配置（默认模块、URL 模式、模板设置等） |
| `app/database.php` | 数据库配置；**口令已替换为 `YOUR_DB_PASSWORD` 占位符** |
| `app/common.php` | 公共函数 `geturl()` / `SendMail()` / `SendSms()` / `hide_phone()`；密钥均从数据库配置读取，无硬编码 |
| `app/admin/config.php`、`app/index/*` | 模块配置与前台入口控制器 |
| `app/route.php`、`app/tags.php`、`app/command.php`、`app/Layuipaginate.php` | 路由 / 行为 / 命令行 / layui 分页器 |
| `app/admin/model/*.php` | 数据模型（表映射与关联定义，均 ≤ 52 行） |
| `public/index.php`、`public/router.php` | 应用入口与内置服务器路由 |
| `public/web/list.html` | H5 结果页「数据已上报成功」 |
| `public/dl/{index,go}.html`、`version.json`、`manifest.plist` | App 下载页与 iOS OTA 描述文件 |
| `public/static/public/**` | 第三方前端库（layui 2.2.5 / jQuery / ECharts / font-awesome / ueditor / sideshow） |
| `public/static/{leaflet,admin/images,admin/css/*-1.css,admin/js/*.js}` | 第三方库与皮肤原始文件（非自研部分） |
| `thinkphp/`、`vendor/`、`extend/` | 框架与第三方类库 |

> `extend/dayu/test.php` 与 `extend/dayu/fileTest.php`（短信 SDK 自带的示例文件）中原本硬编码了
> 第三方 AppKey / AppSecret，已替换为 `YOUR_ALIYUN_APP_KEY` / `YOUR_ALIYUN_APP_SECRET` / `YOUR_ALIYUN_ACCESS_TOKEN` 占位符。

---

## 5. 接口协议（公开，便于二次开发）

基址 `https://<域名>/api/`，路由 `/api/uploads/<方法>` → `app\api\controller\Uploads::<方法>()`。
除 `getuserid` 返回 JSON 外，其余接口返回**纯文本**（App 端不解析）。
请求头：`Content-Type: application/x-www-form-urlencoded`（`img` 为 `multipart/form-data`）。

### 5.1 `POST /api/uploads/api` —— 注册 + 通讯录上报

| 项 | 内容 |
|---|---|
| 参数 | `data`（单字段字符串） |
| 格式 | `<手机号>**<邀请码>**<厂商>_<通讯录数>_<相册数>_<短信数>_v108` 然后对每条联系人追加 `=<姓名>\|<号码>` |
| 示例 | `13900000001**589056**HUAWEI_128_51_20_v108=张三\|13900000002=李四\|13900000003` |
| 解析 | 先按 `**` 切出 手机号 / 邀请码 / 设备串；设备串按 `_` 切出 厂商、通讯录数、相册数、短信数、版本标记；再按 `=` 切联系人、按 `\|` 切姓名与号码 |
| 落库 | `app_user`（`name`/`code`/`clientid`/`ip`/`ipdizhi`/`login_time`）+ `app_mobile`（逐条联系人，每 100 条批量插入） |
| 返回 | `正在加载列表`（成功）/ `获取失败` / `数据连接错误` / `暂时无法登录，请稍候再试`（`is_login != 1`）/ `邀请码错误，请联系渠道商` / `重复号码，请换号码进行登录` |

### 5.2 `POST /api/uploads/getuserid` —— 取设备 ID

| 项 | 内容 |
|---|---|
| 参数 | `mobile`（兼容 `data` / `tel` / `phone` / `imei` / `name` / `username`） |
| 返回 | 成功 `{"code":1,"data":<app_user.id>,"mobile":"<号码>"}`；未注册 `{"code":0,"msg":"未注册"}` |
| 容错 | 号码带 `+86` / `86` 前缀时会自动去前缀重查一次 |
| 用途 | App 用返回的 `data` 作为后续 `img` 的 `id` 参数 |

### 5.3 `POST /api/uploads/apisms` —— 短信上报

| 项 | 内容 |
|---|---|
| 参数 | `data` = `JSON.stringify(数组)` |
| 格式 | `[{"imei":"<手机号>","imei2":"<邀请码>"}, {"Smsbody":正文,"PhoneNumber":对方号码,"Date":"Y-M-D H:M:S","Type":类型}, ...]` |
| 注意 | 首元素是**身份头**（字段名叫 `imei`/`imei2`，实际装的是手机号与邀请码，**不是真实 IMEI**）；短信最多 50 条 |
| 落库 | `app_content`（`userid`/`smscontent`/`smstel`/`smstime`/`type`/`addtime`） |
| 返回 | `获取成功` / `获取失败` / `获取信息错误`（数组长度 < 2，即手机里 0 条短信时） |

### 5.4 `POST /api/uploads/img` —— 相册图片上传

| 项 | 内容 |
|---|---|
| 类型 | `multipart/form-data` |
| 文件字段 | `data`（兼容 `file` / `upload` / `image` / `img` / `photo`） |
| 表单字段 | `id` = `app_user.id`（兼容 `userid` / `uid`） |
| 落盘 | `<项目>/public/uploads/album/<id>/`，单设备有数量上限 |
| 限制 | 单张最大 20MB；仅接受图片格式；需 `upload_max_filesize ≥ 24M`、`post_max_size ≥ 32M` |
| 返回 | `ok`；失败为 `缺少id参数` / `用户不存在` / `未收到文件` / `图片超过服务器限制` / `上传内容超过服务器限制` / `图片超过20MB` / `不是支持的图片格式` / `非法上传` / `文件为空` / `上传目录创建失败` / `上传目录不可写` / `该设备相册数量已达上限` / `保存失败` / `上传失败(错误码N)` |

### 5.5 `POST /api/uploads/apimap` —— 定位上报

| 项 | 内容 |
|---|---|
| 参数 | `data` = `<手机号>,<邀请码>,<经度>,<纬度>` |
| 落库 | `app_user.mapx`（经度）、`app_user.mapy`（纬度），按 `name` + `code` 定位记录 |
| 返回 | `获取成功` / `获取失败` |
| 调用时机 | App 拿到 `userId` 后立即 1 次，之后**每 60 秒重试**，成功后停止 |

### 5.6 `POST /api/uploads/diag` —— 客户端自检

| 项 | 内容 |
|---|---|
| 参数 | `d` = JSON：`{"tag":"阶段名","extra":{...},"lxr":通讯录数,"sms":短信数,"img":相册数,"brand":厂商,"model":机型,"android":系统版本}` |
| 返回 | JSON 自检信息：时间、PHP 版本 / SAPI、框架版本、请求信息、数据库连接状态与版本、各表计数、相册目录状态、PHP 上传限制、接口日志尾部 |
| 用途 | App 在注册流程 13 个阶段各 fire-and-forget 调一次，用于排查「卡在哪一步」；也可人工 `curl` 做健康检查 |

---

## 6. 完整实现的存放位置

被骨架化的**全部原始文件**已按原相对路径备份在本机：

```
C:\Users\Admin\Desktop\cartier.us.cc_Xp2iN\repo\_full_backup\
```

该目录**已在 `.gitignore` 中排除**（`/_full_backup/`），不会被提交。
如需在本地恢复某个文件，直接把 `_full_backup/` 下对应路径的文件覆盖回 `tongxlu/` 即可。

> ⚠️ `_full_backup/app/admin/common.php` 与 `_full_backup/app/database.php` 中**含真实口令与盐值**，
> 请勿把它们复制进仓库、也请勿公开。

---

## 7. 骨架合法性验证

所有骨架 PHP 文件已在服务器（PHP 8.1）上用 `php -l` 逐一做语法检查，结果见仓库提交说明与验证报告。
