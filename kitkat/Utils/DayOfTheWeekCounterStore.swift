import Foundation

struct DayOfTheWeekCounterStore {
    private static let storageKey = "DayOfWeekCounts"

    private static let defaults: [String: Int] = [
        "Monday": 0,
        "Tuesday": 0,
        "Wednesday": 0,
        "Thursday": 0,
        "Friday": 0,
        "Saturday": 0,
        "Sunday": 0
    ]

    static func load() -> [String: Int] {
        guard let stored = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] else {
            return defaults
        }
        var merged = defaults
        for (key, value) in stored {
            merged[key] = value
        }
        return merged
    }

    static func save(_ counts: [String: Int]) {
        UserDefaults.standard.set(counts, forKey: storageKey)
    }
}
