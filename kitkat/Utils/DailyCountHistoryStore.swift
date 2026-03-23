import Foundation

struct DailyCountHistoryEntry: Equatable {
    let dateKey: String
    let count: Int
}

struct DailyCountHistoryStore {
    static let storageKey = "DailyCountHistory"
    private static let totalWeeksToKeep = 13
    private static let weeksToSubtractForWindowStart = totalWeeksToKeep - 1

    static func load(userDefaults: UserDefaults = .standard) -> [String: Int] {
        userDefaults.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }

    static func save(_ history: [String: Int], userDefaults: UserDefaults = .standard) {
        userDefaults.set(history, forKey: storageKey)
    }

    @discardableResult
    static func recordBreak(
        on date: Date = Date(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) -> [String: Int] {
        var history = load(userDefaults: userDefaults)
        let key = dateKey(for: date, calendar: calendar)
        history[key, default: 0] += 1
        let pruned = prunedHistory(history, referenceDate: date, calendar: calendar)
        save(pruned, userDefaults: userDefaults)
        return pruned
    }

    static func prunedHistory(
        _ history: [String: Int],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [String: Int] {
        let windowStart = windowStartDate(referenceDate: referenceDate, calendar: calendar)

        return history.reduce(into: [:]) { result, item in
            guard
                let date = date(from: item.key, calendar: calendar),
                date >= windowStart
            else { return }
            result[item.key] = item.value
        }
    }

    static func windowStartDate(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let daysFromMonday = (weekday + 5) % 7

        guard
            let startOfCurrentWeek = calendar.date(
                byAdding: .day,
                value: -daysFromMonday,
                to: startOfToday
            ),
            let windowStart = calendar.date(
                byAdding: .weekOfYear,
                value: -weeksToSubtractForWindowStart,
                to: startOfCurrentWeek
            )
        else {
            return startOfToday
        }

        return windowStart
    }

    static func entries(
        from history: [String: Int],
        calendar: Calendar = .current
    ) -> [DailyCountHistoryEntry] {
        history
            .compactMap { key, value in
                guard date(from: key, calendar: calendar) != nil else { return nil }
                return DailyCountHistoryEntry(dateKey: key, count: value)
            }
            .sorted { $0.dateKey < $1.dateKey }
    }

    static func dateKey(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(
        from dateKey: String,
        calendar: Calendar = .current
    ) -> Date? {
        let segments = dateKey.split(separator: "-")
        guard
            segments.count == 3,
            let year = Int(segments[0]),
            let month = Int(segments[1]),
            let day = Int(segments[2])
        else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }
}
