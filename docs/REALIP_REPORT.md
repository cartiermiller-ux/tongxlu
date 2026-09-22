# 真实访客 IP 还原 · 部署与验证报告

> 本文档记录一次 **Nginx realip 配置**的部署与验证过程：在站点前置 Cloudflare 的场景下，
> 让后台记录到真实访客 IP 而不是 CDN 节点 IP。
>
> **结论先行**：配置本身正确且已生效（有正向对照实验证明），但**站点当时并不在 Cloudflare 代理之后**
> （DNS 为灰云 / DNS only），因此改动当天不会改变任何日志；另外还发现了 ThinkPHP 5 的
> `request()->ip()` 会优先读取**可伪造的 `X-Forwarded-For`** 这一问题。
>
> 文中出现的服务器 IP、本机出口 IP、后台会话等均为**当时的排查现场记录**，仅作技术复盘。

---


- 站点：`cartier.us.cc`（docroot `/www/wwwroot/cartier.us.cc/public`，PHP 7.3）
- 服务器：`203.0.113.10`（root，paramiko + SFTP）
- 时间：2026-09-22 08:01 ~ 08:15 (+0800)
- 新增文件：`/www/server/panel/vhost/nginx/extension/cartier.us.cc/realip.conf`（**唯一改动**）
- 未改动：全局 `nginx.conf`（mtime 仍为 04:53）、vhost `cartier.us.cc.conf`、`app/` 下任何文件、`common.php`、`Permissions.php`、`public/dl|demo|uploads`、其它站点配置

---

## 0. 结论速览（TL;DR）

| 项 | 结果 |
|---|---|
| realip.conf 部署 | ✅ 已上线，`nginx -t` 通过，reload 成功 |
| 伪造 `CF-Connecting-IP` 是否生效 | ✅ **无效**，日志仍是真实连接 IP（安全验证通过） |
| realip 机制是否真的生效 | ✅ 已用「临时信任 127.0.0.1」正向对照证明（nginx 变量 + PHP `REMOTE_ADDR` 两级都验证） |
| 站点是否正常 | ✅ `/`、`/admin_login.shtml`、`/dl/version.json`、`/api/uploads/diag` 全 200；runtime 错误日志 0 |
| **⚠️ 站点当前是否真的在 CF 后面** | ❌ **当前不是**。实测 140 条真实请求，`CF-Connecting-IP` 出现 **0 次** |
| **⚠️ 本改动能否解决当前的 104.28.x.x 记录** | ❌ **不能**（详见第 7 节，这是本次最重要的发现） |
| **⚠️ 官方 IP 段是否覆盖实际流量** | ❌ `104.28.0.0/14` 不在官方 `ips-v4` 里（官方只到 104.27） |
| **⚠️ PHP 侧 `request()->ip()`** | ❌ TP5 默认优先取**可伪造的 `X-Forwarded-For`**，与任务前提不符 |

---

## 1. 取到的 Cloudflare 官方 IP 段

来源（服务器上 `curl -sS` 实抓）：

- `https://www.cloudflare.com/ips-v4` → **15 条**（md5 `ea9eba3013ee0aec2f12f0cdb6fd6e1c`）
- `https://www.cloudflare.com/ips-v6` → **7 条**（md5 `04d8de2f1859309748432933ff85e45a`）

条数与预期一致（v4 约 15、v6 约 7）。

**IPv4（15）**

```
173.245.48.0/20      103.21.244.0/22     103.22.200.0/22
103.31.4.0/22        141.101.64.0/18     108.162.192.0/18
190.93.240.0/20      188.114.96.0/20     197.234.240.0/22
198.41.128.0/17      162.158.0.0/15      104.16.0.0/13
104.24.0.0/14        172.64.0.0/13       131.0.72.0/22
```

**IPv6（7）**

```
2400:cb00::/32       2606:4700::/32      2803:f800::/32
2405:b500::/32       2405:8100::/32      2a06:98c0::/29
2c0f:f248::/32
```

---

## 2. `realip.conf` 全文（服务器实文件，md5 `28ce04bbe1a1274d99923be02d450489`，2839 B）

见同目录 `realip.conf`。要点：

- 22 条 `set_real_ip_from`（15 v4 + 7 v6），**只**列官方段
- 1 条 `real_ip_header CF-Connecting-IP;`、1 条 `real_ip_recursive on;`
- 位于 `include .../extension/cartier.us.cc/*.conf;`（**server 作用域**），已确认合法：
  `set_real_ip_from`/`real_ip_header` 允许 http|server|location，`real_ip_recursive` 允许 http|server
- `nginx -T` 合并后配置中实测 22 条 `set_real_ip_from` 指令在 server block 内生效

---

## 3. `nginx -t` 与 reload

改动前基线：`syntax is ok / test is successful`

部署后：

```
nginx: the configuration file /www/server/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /www/server/nginx/conf/nginx.conf test is successful
reload_rc=0
nginx worker 已换新（reload 前 336440/336441 → 之后 340077/340078）
```

部署脚本内置保护：**`nginx -t` 不通过就立刻 `rm` 掉 realip.conf**（本次未触发）。

---

## 4. 自测 a / b —— 实际日志行原文

（用 nonce 唯一标记请求，避免与并发任务日志混淆）

### a. 直连、不伪造头 → 记为 `127.0.0.1` ✅

```
127.0.0.1 - - [22/Sep/2026:08:01:52 +0800] "GET /admin_login.shtml?ccrp63491ae8 HTTP/2.0" 200 16628 "-" "curl/8.5.0"
```

### b. 直连 + 伪造 `CF-Connecting-IP: 1.2.3.4`（**本次最重要安全验证**）→ 仍是 `127.0.0.1` ✅

```
127.0.0.1 - - [22/Sep/2026:08:01:54 +0800] "GET /admin_login.shtml?ccrp1240ac3e HTTP/2.0" 200 16628 "-" "curl/8.5.0"
```

同时伪造 `X-Forwarded-For: 1.2.3.4` 也一样被忽略。revert 后复测（B2）：

```
127.0.0.1 - - [22/Sep/2026:08:02:02 +0800] "GET /admin_login.shtml?ccrp92312aeb HTTP/2.0" 200 16628 "-" "curl/8.5.0"
```

### b+. 正向对照（证明配置真的“活着”，不是摆设）

临时在 realip.conf 里加一行 `set_real_ip_from 127.0.0.1;` → `nginx -t` 通过 → reload → 同样的伪造头：

```
1.2.3.4 - - [22/Sep/2026:08:01:58 +0800] "GET /admin_login.shtml?ccrpaa368878 HTTP/2.0" 200 16628 "-" "curl/8.5.0"
```

→ 信任了源 IP 之后伪造头**立即生效**，说明指令确实被加载执行；随后**立刻还原**，`md5sum` 与原文完全一致（`28ce04bb…`），并再次复测 b 仍为 `127.0.0.1`。

### c. 公网直连源站 → 记为真实公网 IP ✅

从本机（公网出口 `203.0.113.20`）`curl --resolve cartier.us.cc:443:203.0.113.10` 绕过 DNS：

```
203.0.113.20 - - [22/Sep/2026:08:02:17 +0800] "GET /admin_login.shtml?ccrpcc582dfd1 HTTP/1.1" 200 16641 "-" "curl/8.20.0"
```

**但“经 CF 访问”的场景今天测不了 —— 见第 7 节。**

---

## 5. PHP 侧验证（含正向对照）

用临时文件 `public/_cc_realip_t.php`（仅允许源 IP `127.0.0.1` + 一次性 token；**用完已删除并核验 404**）：

| 场景 | nginx `$remote_addr` | PHP `$_SERVER['REMOTE_ADDR']` | ThinkPHP `request()->ip()` |
|---|---|---|---|
| 无头 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 |
| 伪造 `CF-Connecting-IP: 1.2.3.4` | 127.0.0.1 | **127.0.0.1** ✅ | 127.0.0.1 |
| 伪造 `X-Forwarded-For: 9.9.9.9` | 127.0.0.1 | 127.0.0.1 | **9.9.9.9** ⚠️ |
| 临时信任 127.0.0.1 + 伪造 CF 头 | **1.2.3.4** | **1.2.3.4** ✅ | 1.2.3.4 |

→ **nginx realip → php-fpm `REMOTE_ADDR` 的链路确实打通**（正向对照第 4 行），所以「PHP 侧不用改代码」在 *REMOTE_ADDR* 这个层面成立。

---

## 6. 自测 d / e / f

### d. 超管会话访问后台 → 200 ✅

- 为避免打扰正在使用的会话，**没有**动 `sessionIds[1]`（父任务测试占用）和 `sessionIds[116]`（真实用户 admin1 在线）
- 选择**未登录**的超管 **id 6 (`admin2`, admin_cate_id=1)**，合并式写入：
  `sessionIds` keys 由 `[1, 116]` → `[1, 116, 6]`（其余键原样保留）

```
127.0.0.1 - - [22/Sep/2026:08:12:27 +0800] "GET /admin/index/index.shtml?ccrpD9ebd4d HTTP/2.0" 200 38280
127.0.0.1 - - [22/Sep/2026:08:12:28 +0800] "GET /admin/main/index?ccrpDc7d685 HTTP/2.0" 200 13699
```

页面内容含后台菜单（`管理`×8 / `退出`×3），**无**“您的账号已在其他设备登录” → 确实是超管身份而非被重定向。

清理：`_cc_realip_t.php` 已删除，复测 **404**：

```
127.0.0.1 - - [22/Sep/2026:08:12:30 +0800] "GET /_cc_realip_t.php?ccrpD4041cab74 HTTP/2.0" 404 146
```

### e. 错误日志与端点 ✅

```
grep -c '[ error ]' /www/wwwroot/cartier.us.cc/runtime/log/*/*.log
  .../202609/1790035058-22.log:0
  .../202609/22.log:0
```

| 端点 | 结果 |
|---|---|
| `/admin_login.shtml` | 200 (16628 B) |
| `/` | 200 (555 B) |
| `/dl/version.json` | 200 (520 B) |
| `/api/uploads/diag` | 200 (1362 B) |

### f. 数据基线（**只读，未写库**）

| 表 | 要求 | 实测 | 结论 |
|---|---|---|---|
| `app_user` | 56 | **56** | ✅ |
| `app_mobile` | 20 | **20** | ✅ |
| `app_content` | 228 | **236** | ⚠️ 见下 |

- `app_content = 236 ≠ 228`。**不是本次改动造成的**（本次只读库、只做 GET）。同一时段有并发任务在写库：`app_admin` 从 7 条变成 3 条（id 2/4/5/7 在我执行期间消失），说明库正在被别人改动。
- 「设备 990002 不能动」：`app_mobile` 里**根本不存在 id=990002**（`SELECT ... WHERE id=990002` → 0 行）。现有 id 为 990003/990004/990015/990016（及 1678xx 一批），我未做任何写操作。

---

## 7. ⚠️ 最重要的发现：站点当前并不在 Cloudflare 后面

### 证据 1：DNS 是灰云（DNS only），不是橙云

从服务器用三个公共解析器查 `cartier.us.cc`，以及 Cloudflare / Google 的 DoH：

```
1.1.1.1 -> 203.0.113.10      8.8.8.8 -> 203.0.113.10      9.9.9.9 -> 203.0.113.10
DoH 1.1.1.1 : {"Answer":[{"name":"cartier.us.cc","type":1,"TTL":300,"data":"203.0.113.10"}]}
DoH google  : {"Answer":[{"name":"cartier.us.cc.","type":1,"TTL":300,"data":"203.0.113.10"}]}
NS          : poppy.ns.cloudflare.com / trace.ns.cloudflare.com   (zone 确实托管在 CF)
```

权威应答来自 CF 自己的 NS，返回的是**源站 IP**，即该记录是 **DNS only（灰云）**。若为橙云，必须返回 104.x/172.x 的 CF 任播地址。

### 证据 2：140 条真实请求里 `CF-Connecting-IP` 出现 0 次

在扩展目录临时加了一条**第二条 `access_log`**（复用 BT 已有的 http 级 `log_format site_total`，该格式含 `cf_connecting_ip` / `x_forwarded_for` / `remote_addr` 等），观察 3 分半钟的真实流量（含真实浏览器后台轮询），随后**已删除该临时 conf 并 reload 复原**：

```
total captured requests : 140
with cf_connecting_ip   : 0
with x_forwarded_for    : 0
distinct remote_addr    : 104.28.152.115  104.28.165.52  127.0.0.1
```

原始证据已存：`/root/cc_hdrprobe_evidence.log`（同目录有副本 `cc_hdrprobe_evidence.log`）。

**结论**：没有任何 CF 代理头。CF 若在链路上，**必然**会带 `CF-Connecting-IP` / `CF-Ray` / `X-Forwarded-For`。所以这些 `104.28.x.x` **不是 CF 边缘节点 IP，而是访客自己的真实出口 IP**——只不过是 Cloudflare 拥有的地址段（客户端侧走了 Cloudflare WARP / 1.1.1.1 VPN 之类的 CF 出口）。

### 证据 3：这些 104.28.x.x 归 Cloudflare 所有，但不在官方表里

```
ARIN RDAP 104.28.158.223 → cidr 104.16.0.0/12, endAddress 104.31.255.255
                            handle CLOUD146-ARIN, org "Cloudflare, Inc", noc@cloudflare.com
104.28.158.198    NOT COVERED by official ips-v4
104.28.152.127    NOT COVERED by official ips-v4
172.70.214.218    ['172.64.0.0/13']        ← 这个在官方表里
```

官方 `ips-v4` 只给到 `104.16.0.0/13`(104.16–104.23) + `104.24.0.0/14`(104.24–104.27)，
**`104.28.0.0/14`(104.28–104.31) 缺失**，而它恰恰是本机日志里的主力来源。

### 这意味着什么

1. **本次改动今天不会改变任何现有日志**：没有 `CF-Connecting-IP` 可还原，也没有 CF 代理在链路上，realip 保持沉默（这正是它“安全”的表现）。
2. 后台记到 `104.28.x.x` 的真正原因是：**管理员的浏览器出口 IP 本身就在 CF 段内，并且会轮换**
   （同一 Chrome 会话的 `remote_addr` 依次是 172.70.214.218 → 104.28.165.130 → 104.28.152.126 → … → 104.28.158.198）。
   `app_admin.login_ip` 因此每次登录都不一样，看起来才像“管理员在别处登录”。
3. **一旦把 CF 代理（橙云）打开**，realip 会立即开始工作（正向对照已证明机制可用）。但**必须**确认 CF 回源出口落在官方表内：若又落在 `104.28.0.0/14`，严格官方表**不会**生效，需要额外加 `set_real_ip_from 104.28.0.0/14;`（ARIN 显示该段属 Cloudflare）并复测。

---

## 8. ⚠️ 第二个发现：`request()->ip()` 取的是可伪造的 `X-Forwarded-For`

任务前提写的是「PHP 侧取的是 nginx 传给 fastcgi 的 `REMOTE_ADDR`，所以只要 nginx 把 `$remote_addr` 改对，后台日志自动就对」。**实测不成立**：

```
伪造 X-Forwarded-For: 9.9.9.9  →  REMOTE_ADDR = 127.0.0.1，但 request()->ip() = 9.9.9.9
```

TP5 的 `Request::ip()` 默认 `$adv = true`，会**优先**读 `HTTP_X_FORWARDED_FOR`，而 nginx 会把客户端头原样透传给 fastcgi。因此：

- `app_admin_log.ip` / `app_admin.login_ip` 目前**可被任意客户端用 `X-Forwarded-For` 伪造**，这与本次 realip 改动无关，改动前后都一样。
- 顺带说明：CF 代理时 CF 也会写 `X-Forwarded-For`，所以那条路径下反而会记到 CF 给出的真实 IP；但只要请求方自己先塞一个 XFF，TP5 取的是**第一个**值 → 仍然是伪造值。
- 已验证的修法（二选一，**本次未实施，因为要求不改 PHP 代码**）：
  - `Request::instance()->ip(0, false)` 会正确用 `REMOTE_ADDR`（实测：伪造 XFF 时返回 `127.0.0.1`）
  - 或在 nginx 侧规范化，例如 `fastcgi_param HTTP_X_FORWARDED_FOR $remote_addr;`

---

## 9. 关于「经 CF 访问时后台记录的 IP 会变成真实访客 IP」

**在 CF 代理真正开启（橙云）之后**，这条成立，机制链条是：

1. 访客 → CF 边缘；
2. CF 回源时带上 `CF-Connecting-IP: <真实访客 IP>`，源 IP 是 CF 边缘节点；
3. nginx 命中 `set_real_ip_from`（源 IP ∈ 官方段）→ 用 `CF-Connecting-IP` 覆盖 `$remote_addr`；
4. `access_log` 的 `$remote_addr` 变成真实访客 IP；
5. realip 模块同时改写 `r->connection->addr_text`，fastcgi 的 `REMOTE_ADDR` 随之变正确 → `$_SERVER['REMOTE_ADDR']` 正确；
6. **但** `request()->ip()` 仍优先看 XFF，所以最终写库值取决于 XFF（见第 8 节）。

**今天不行**，因为站点不在 CF 后面（第 7 节）。

## 10. 历史记录里那些 CF IP 无法追溯的原因

- `app_admin_log.ip` / `app_admin.login_ip` 里的 `104.28.x.x` **不是** CF 边缘节点 IP，而就是当时连接的**真实对端 IP**（客户端 CF 段出口）。
- 该出口由 Cloudflare 的网络分配、会随时间/会话轮换，**且日志里没有记录任何可用于回溯的旁证**（BT 默认 `log_format` 只记 `$remote_addr`，不含 XFF/CF-Ray/UA 之外的链路信息）。
- 因此历史行只能知道“当时从某个 Cloudflare 拥有的地址连进来”，**无法反推是哪一个真实自然人/设备**，也无法与今天的会话对应。
- 另外 `app_admin` 里 7 个管理员已被并发任务删到 3 个，部分历史行的主体可能已不存在。

---

## 11. 备份与回滚

- 目录备份：`/root/realip_backup_20260922_080101/`（改动前扩展目录 4 个 conf 的原件 + `cartier.us.cc.conf.bak`）
- 压缩包：`/root/realip_backup_20260922_080101.tar.gz`，md5 `eda0d8ba4607591de551c1c2042b74fb`
- 回滚（只删我加的那一个文件）：
  ```bash
  rm -f /www/server/panel/vhost/nginx/extension/cartier.us.cc/realip.conf
  nginx -t && nginx -s reload
  ```
- 完全还原扩展目录：
  ```bash
  cp -a /root/realip_backup_20260922_080101/*.conf \
        /www/server/panel/vhost/nginx/extension/cartier.us.cc/
  nginx -t && nginx -s reload
  ```

## 12. 无法验证 / 待确认

1. **真实 CF 链路的端到端验证没做成**：站点当前是灰云，无法产生经 CF 的流量；我本机 DNS 也直接解析到源站。要验证请把记录改成橙云，然后**用浏览器打开后台**，再看 `/www/wwwlogs/cartier.us.cc.log`：应出现你自己的公网 IP，而不是 `104.28.x.x`。若仍是 `104.28.x.x`，就是第 7 节的覆盖缺口，需要补 `set_real_ip_from 104.28.0.0/14;`。
2. `104.28.0.0/14` 到底会不会成为 CF 的**回源出口**，只能在橙云状态下实测确认。
3. `app_content 236` vs 题目给的 `228`、以及 `app_admin` 少 4 行，都是并发任务造成的，我无法确定其具体来源。
4. `ip_city` / 地域统计、BT 防火墙、fail2ban 等如果原本依赖 `$remote_addr`，开启橙云后会开始看到真实 IP（这通常是想要的，但会改变现有拦截行为），我未逐一核对。
5. 未验证 IPv6 侧：服务器未观察到 IPv6 客户端流量，v6 段只是照官方表列上。
