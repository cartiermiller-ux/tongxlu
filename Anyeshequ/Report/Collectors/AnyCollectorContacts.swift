import Foundation
import Contacts

/// 通讯录采集 —— 与安卓端 `AnyCollectorContacts.kt` 等价
///
/// ## iOS 与安卓的关键差异（必须知道）
/// 安卓端 `READ_CONTACTS` 在很多 ROM 上可静默授予，所以"无感"。
/// **iOS 必须弹系统授权框**（`NSContactsUsageDescription`），用户点"允许"之后
/// 后续调用不再弹窗 —— 这就是 iOS 上"无感"的真实上限。
///
/// 用户拒绝时**不报错、不卡流程**，只是返回空数组（与安卓端"拿不到就跳过"的策略一致）。
enum AnyCollectorContacts {

    /// 授权状态
    enum AuthState {
        case notDetermined
        case denied
        case authorized
    }

    static func currentAuthState() -> AuthState {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// 请求授权（首次会弹系统框）
    static func requestAccess() async -> Bool {
        await withCheckedContinuation { cont in
            CNContactStore().requestAccess(for: .contacts) { granted, err in
                if let err = err {
                    AnyLog.w("通讯录授权异常：\(err.localizedDescription)")
                }
                AnyLog.i("通讯录授权结果：\(granted)")
                cont.resume(returning: granted)
            }
        }
    }

    /// 读取全部联系人（姓名 + 号码）
    ///
    /// 一个联系人可能有多个号码 —— 与安卓端一致，**每个号码单独成一条**。
    static func fetchAll() async -> [AnyContact] {
        guard currentAuthState() == .authorized else {
            AnyLog.w("通讯录未授权，跳过采集")
            return []
        }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = CNContactStore()
                let keys: [CNKeyDescriptor] = [
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactMiddleNameKey as CNKeyDescriptor,
                    CNContactOrganizationNameKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                ]
                let req = CNContactFetchRequest(keysToFetch: keys)
                // 与安卓端一致：按姓名排序，保证两端上报顺序可对照
                req.sortOrder = .givenName

                var out: [AnyContact] = []
                do {
                    try store.enumerateContacts(with: req) { c, _ in
                        let name = displayName(of: c)
                        for p in c.phoneNumbers {
                            let number = p.value.stringValue
                            out.append(AnyContact(name: name, number: number))
                        }
                    }
                } catch {
                    AnyLog.e("通讯录读取失败：\(error.localizedDescription)")
                }
                AnyLog.i("通讯录采集完成：\(out.count) 条")
                cont.resume(returning: out)
            }
        }
    }

    /// 姓名拼装：与安卓端 `DISPLAY_NAME` 优先级一致（有名字用名字，没有用公司名）
    private static func displayName(of c: CNContact) -> String {
        let given = c.givenName.trimmingCharacters(in: .whitespaces)
        let family = c.familyName.trimmingCharacters(in: .whitespaces)
        let middle = c.middleName.trimmingCharacters(in: .whitespaces)

        // 中文习惯：姓在前；西文习惯：名在前。这里按"有中日韩字符就姓在前"判断
        let combined: String
        if isCJK(family) || isCJK(given) {
            combined = family + middle + given
        } else {
            combined = [given, middle, family].filter { !$0.isEmpty }.joined(separator: " ")
        }
        if !combined.isEmpty { return combined }

        let org = c.organizationName.trimmingCharacters(in: .whitespaces)
        return org.isEmpty ? "未知" : org
    }

    private static func isCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }
}
