import Foundation

struct WorkweekGoalCalculator {
    private static let minimumDailyTarget = 5
    private static let workweekDivisor = 5.0
    private static let orderedDays = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
    ]

    static func dailyTarget(from dailyAverages: [String: Int]) -> Int {
        let totalAcrossAllDays = orderedDays.reduce(0) { partialResult, day in
            partialResult + max(0, dailyAverages[day, default: 0])
        }
        let computedAverage = Double(totalAcrossAllDays) / workweekDivisor
        return max(minimumDailyTarget, Int(ceil(computedAverage)))
    }
}
