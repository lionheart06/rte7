import Foundation

struct WeekdayAverageRow: Identifiable, Equatable {
    let day: String
    let average: Int
    var id: String { day }
}

struct WeekdayAverageCalculator {
    private static let orderedWeekdays: [(number: Int, name: String)] = [
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
    ]

    static func weekdayAverages(
        from history: [String: Int],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [String: Int] {
        let startDate = DailyCountHistoryStore.windowStartDate(referenceDate: referenceDate, calendar: calendar)
        let endDate = calendar.startOfDay(for: referenceDate)

        var totals = orderedWeekdays.reduce(into: [String: Int]()) { result, item in
            result[item.name] = 0
        }
        var occurrences = orderedWeekdays.reduce(into: [String: Int]()) { result, item in
            result[item.name] = 0
        }

        var cursor = startDate
        while cursor <= endDate {
            let weekdayNumber = calendar.component(.weekday, from: cursor)
            if let weekdayName = orderedWeekdays.first(where: { $0.number == weekdayNumber })?.name {
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

        return orderedWeekdays.reduce(into: [String: Int]()) { result, item in
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
}
