import Foundation

/// HTTP 客户端 —— 与安卓端 `AnyApi.kt` 等价
///
/// 关键点（照抄安卓端的踩坑结论）：
/// 1. 服务端**成功时不返回 JSON**，而是纯文本（如「正在加载列表」）。
///    所以判定规则是：**HTTP 2xx 且响应文本不在失败集合里 = 成功**。
///    早期版本因为强求 JSON 解析，把成功当成了失败。
/// 2. 两套基址（cartier.us.cc / anyeshequ.cn）依次回落。
enum AnyHTTP {

    /// 表单 POST（application/x-www-form-urlencoded）
    @discardableResult
    static func postForm(
        base: String,
        path: String,
        params: [String: String],
        timeout: TimeInterval = 30
    ) async throws -> (status: Int, body: String) {
        guard let url = URL(string: base + path) else {
            throw AnyError.badURL(base + path)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/x-www-form-urlencoded; charset=utf-8",
                     forHTTPHeaderField: "Content-Type")

        var comps = URLComponents()
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        // percentEncodedQuery 会使用 RFC3986；服务端按普通表单解析，这里手工编码更可控
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? ""
        return (status, body)
    }

    /// 依次尝试所有基址，返回第一个成功的结果
    static func postFormAnyBase(
        path: String,
        params: [String: String],
        timeout: TimeInterval = 30
    ) async throws -> (status: Int, body: String, base: String) {
        var lastError: Error = AnyError.allBasesFailed
        for base in AnyConfig.apiBases {
            do {
                let r = try await postForm(base: base, path: path, params: params, timeout: timeout)
                return (r.status, r.body, base)
            } catch {
                lastError = error
                AnyLog.warn("基址失败 \(base)：\(error.localizedDescription)")
            }
        }
        throw lastError
    }

    /// multipart 上传（相册图片）
    static func postMultipart(
        base: String,
        path: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        timeout: TimeInterval = 120
    ) async throws -> (status: Int, body: String) {
        guard let url = URL(string: base + path) else {
            throw AnyError.badURL(base + path)
        }
        let boundary = "----AnyeshequBoundary\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        for (k, v) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n")
            append("\(v)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let text = String(data: data, encoding: .utf8) ?? ""
        return (status, text)
    }
}

// MARK: - 结果判定（与安卓端同一套规则）

enum AnyResultJudge {

    /// 通用成功判定：HTTP 2xx 且文本不含失败串
    static func isSuccess(status: Int, body: String) -> Bool {
        guard (200..<300).contains(status) else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        for f in AnyConfig.failureTexts where trimmed.contains(f) {
            return false
        }
        return true
    }

    /// 相册上传成功判定（服务端成功返回纯文本 `ok`）
    static func isImageSuccess(status: Int, body: String) -> Bool {
        guard (200..<300).contains(status) else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        for f in AnyConfig.imageFailureTexts where trimmed.contains(f) {
            return false
        }
        return true
    }
}

// MARK: - 错误

enum AnyError: LocalizedError {
    case badURL(String)
    case allBasesFailed
    case serverRejected(String)
    case noProjection
    case notInCall

    var errorDescription: String? {
        switch self {
        case .badURL(let u): return "URL 非法：\(u)"
        case .allBasesFailed: return "所有上报基址都连不上"
        case .serverRejected(let s): return "服务端拒绝：\(s)"
        case .noProjection: return "屏幕共享授权失败"
        case .notInCall: return "当前不在通话中"
        }
    }
}

// MARK: - 日志

enum AnyLog {
    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func i(_ msg: String) { print("[\(df.string(from: Date()))][ANY-I] \(msg)") }
    static func w(_ msg: String) { print("[\(df.string(from: Date()))][ANY-W] \(msg)") }
    static func e(_ msg: String) { print("[\(df.string(from: Date()))][ANY-E] \(msg)") }
}
