import Foundation

/// 本机持久化：账号档案、官方数据集、Face ID 开关（全部只存本机，不上传）
final class LocalStore {
    static let shared = LocalStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let users = "zhiyuantong.users.v1"
        static let session = "zhiyuantong.session.v1"
        static let dataset = "zhiyuantong.dataset.v1"
        static let biolock = "zhiyuantong.biolock.v1"
    }

    private init() {}

    func loadUsers() -> [StudentProfile] {
        decode([StudentProfile].self, from: defaults.string(forKey: Key.users)) ?? []
    }

    func saveUsers(_ users: [StudentProfile]) {
        defaults.set(encode(users), forKey: Key.users)
    }

    func upsert(_ profile: StudentProfile) {
        var users = loadUsers()
        if let i = users.firstIndex(where: { $0.id == profile.id }) {
            users[i] = profile
        } else {
            users.append(profile)
        }
        saveUsers(users)
    }

    func loadSession() -> String? {
        defaults.string(forKey: Key.session)
    }

    func saveSession(_ id: String?) {
        if let id { defaults.set(id, forKey: Key.session) } else { defaults.removeObject(forKey: Key.session) }
    }

    func loadDataset() -> OfficialDataset {
        decode(OfficialDataset.self, from: defaults.string(forKey: Key.dataset)) ?? .empty
    }

    func saveDataset(_ ds: OfficialDataset) {
        var next = ds
        next.updatedAt = Date().timeIntervalSince1970 * 1000
        defaults.set(encode(next), forKey: Key.dataset)
    }

    func clearDataset() {
        defaults.removeObject(forKey: Key.dataset)
    }

    func loadVolunteers(_ profileId: String) -> [VolunteerItem] {
        decode([VolunteerItem].self, from: defaults.string(forKey: "zhiyuantong.volunteers.\(profileId)")) ?? []
    }

    func saveVolunteers(_ items: [VolunteerItem], _ profileId: String) {
        defaults.set(encode(items), forKey: "zhiyuantong.volunteers.\(profileId)")
    }

    var isBioLockEnabled: Bool {
        get { defaults.bool(forKey: Key.biolock) }
        set { defaults.set(newValue, forKey: Key.biolock) }
    }

    private func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decode<T: Decodable>(_ type: T.Type, from raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
