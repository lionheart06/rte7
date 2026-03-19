import Foundation

struct WorkweekGoalCalculator {
    private static let minimumDailyTarget = 5
    private static let workweekDivisor = 5.0

    static func dailyTarget(from dayCounts: [String: Int]) -> Int {
        let totalAcrossAllDays = dayCounts.values.reduce(0, +)
        let computedAverage = Double(totalAcrossAllDays) / workweekDivisor
        return max(minimumDailyTarget, Int(ceil(computedAverage)))
    }
}
