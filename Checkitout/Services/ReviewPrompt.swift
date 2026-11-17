import Foundation

/// Decides whether to ask for an App Store review right after the user saves
/// a sound they recorded. Asks only after 3 saves, 3 days after the first
/// launch, and at most once per version (the system still decides whether the
/// prompt actually appears).
enum ReviewPrompt {
    private static let firstLaunchKey = "reviewFirstLaunchDate"
    private static let achievementCountKey = "reviewAchievementCount"
    private static let requestedVersionKey = "reviewRequestedVersion"

    static let minimumDays = 3
    static let minimumAchievements = 3

    static func recordLaunch(defaults: UserDefaults = .standard, now: Date = .now) {
        if defaults.object(forKey: firstLaunchKey) == nil { defaults.set(now, forKey: firstLaunchKey) }
    }

    /// Call after a recording is saved. Returns true when the review prompt
    /// should be requested now, and marks this version as asked.
    static func recordAchievement(defaults: UserDefaults = .standard, now: Date = .now) -> Bool {
        let count = defaults.integer(forKey: achievementCountKey) + 1
        defaults.set(count, forKey: achievementCountKey)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date ?? now
        let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0
        let requests = count >= minimumAchievements && days >= minimumDays
            && defaults.string(forKey: requestedVersionKey) != version
        if requests { defaults.set(version, forKey: requestedVersionKey) }
        return requests
    }
}
