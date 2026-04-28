import Foundation

enum ProfileStore {
    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("DualSenseMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profile.json")
    }

    static func load() -> Profile {
        guard let data = try? Data(contentsOf: fileURL),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return .defaultProfile
        }
        return profile
    }

    static func save(_ profile: Profile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
