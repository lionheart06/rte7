import Foundation

struct WeekdayAverageRow: Identifiable, Equatable {
    let day: String
    let average: Int
    var id: String { day }
}

struct WeekdayProductiveRow: Identifiable, Equatable {
    let day: String
    let peak: Int
    var id: String { day }
}

struct WeekdayProductiveSummary: Equatable {
    let rows: [WeekdayProductiveRow]
    let winners: Set<String>
}

struct WeekdayAverageCalculator {
    private static let orderedWeekdays: [(number: Int, name: String)] = [
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
    ]
    private static let orderedWeekdaysIncludingWeekend: [(number: Int, name: String)] = [
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday"),
        (1, "Sunday"),
    ]

    static func weekdayAverages(
        from history: [String: Int],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [String: Int] {
        averages(
            from: history,
            orderedDays: orderedWeekdays,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func allDayAverages(
        from history: [String: Int],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [String: Int] {
        averages(
            from: history,
            orderedDays: orderedWeekdaysIncludingWeekend,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private static func averages(
        from history: [String: Int],
        orderedDays: [(number: Int, name: String)],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: Int] {
        let startDate = DailyCountHistoryStore.windowStartDate(referenceDate: referenceDate, calendar: calendar)
        let endDate = calendar.startOfDay(for: referenceDate)

        var totals = orderedDays.reduce(into: [String: Int]()) { result, item in
            result[item.name] = 0
        }
        var occurrences = orderedDays.reduce(into: [String: Int]()) { result, item in
            result[item.name] = 0
        }

        var cursor = startDate
        while cursor <= endDate {
            let weekdayNumber = calendar.component(.weekday, from: cursor)
            if let weekdayName = orderedDays.first(where: { $0.number == weekdayNumber })?.name {
                let key = DailyCountHistoryStore.dateKey(for: cursor, calendar: calendar)
                let dayCount = history[key, default: 0]
                if dayCount > 0 {
                    totals[weekdayName, default: 0] += dayCount
                    occurrences[weekdayName, default: 0] += 1
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDate
        }

        return orderedDays.reduce(into: [String: Int]()) { result, item in
            let total = totals[item.name, default: 0]
            let count = occurrences[item.name, default: 0]
            result[item.name] = roundedUpAverage(total: total, count: count)
        }
    }

    static func averageRows(
        from history: [String: Int],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeekdayAverageRow] {
        let averages = weekdayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return orderedWeekdays.map { item in
            WeekdayAverageRow(day: item.name, average: averages[item.name, default: 0])
        }
    }

    private static func roundedUpAverage(total: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (total + count - 1) / count
    }

    static func productiveSummary(
        from history: [String: Int],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> WeekdayProductiveSummary {
        let startDate = DailyCountHistoryStore.windowStartDate(referenceDate: referenceDate, calendar: calendar)
        let endDate = calendar.startOfDay(for: referenceDate)

        var peaks = orderedWeekdays.reduce(into: [String: Int]()) { result, item in
            result[item.name] = 0
        }

        for (dateKey, count) in history {
            guard
                let date = DailyCountHistoryStore.date(from: dateKey, calendar: calendar),
                date >= startDate,
                date <= endDate
            else { continue }

            let weekdayNumber = calendar.component(.weekday, from: date)
            guard let weekdayName = orderedWeekdays.first(where: { $0.number == weekdayNumber })?.name else {
                continue
            }

            peaks[weekdayName] = max(peaks[weekdayName, default: 0], count)
        }

        let rows = orderedWeekdays.map { item in
            WeekdayProductiveRow(day: item.name, peak: peaks[item.name, default: 0])
        }
        let maxPeak = rows.map(\.peak).max() ?? 0
        let winners = Set(rows.filter { $0.peak == maxPeak }.map(\.day))

        return WeekdayProductiveSummary(rows: rows, winners: winners)
    }
}
