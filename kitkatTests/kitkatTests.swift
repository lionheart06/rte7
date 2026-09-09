//
//  kitkatTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 2/23/26.
//

import Foundation
import CFNetwork
import AppKit
import Testing
@testable import kitkat

struct kitkatTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

struct RESTAPIClientTests {
    @Test func makeURL_joinsBaseURLAndRelativeEndpoint() throws {
        let client = RESTAPIClient(baseURL: "https://favqs.com")
        let url = try client.makeURL(endpoint: "/api/qotd")
        #expect(url.absoluteString == "https://favqs.com/api/qotd")
    }

    @Test func makeURL_allowsAbsoluteEndpoint() throws {
        let client = RESTAPIClient(baseURL: "https://favqs.com")
        let url = try client.makeURL(endpoint: "https://example.com/test")
        #expect(url.absoluteString == "https://example.com/test")
    }

    @Test func makeURL_trimsWhitespace() throws {
        let client = RESTAPIClient(baseURL: "  https://favqs.com  ")
        let url = try client.makeURL(endpoint: "  /api/qotd  ")
        #expect(url.absoluteString == "https://favqs.com/api/qotd")
    }

    @Test func makeURL_throwsForInvalidBaseURL() {
        let client = RESTAPIClient(baseURL: "   ")
        do {
            _ = try client.makeURL(endpoint: "/api/qotd")
            #expect(Bool(false))
        } catch let error as RESTAPIClient.RESTAPIClientError {
            switch error {
            case .invalidBaseURL:
                #expect(Bool(true))
            case .couldNotFormURL:
                #expect(Bool(false))
            case .invalidResponse:
                #expect(Bool(false))
            case .unexpectedStatusCode:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }

    @Test func proxyDictionary_parsesHttpsProxyFromEnvironment() {
        let proxyDictionary = RESTAPIClient.makeProxyDictionary(environment: ["HTTPS_PROXY": "http://proxy.example:8080"])
        #expect(proxyDictionary != nil)
        #expect(proxyDictionary?[kCFNetworkProxiesHTTPSEnable as String] as? Int == 1)
        #expect(proxyDictionary?[kCFNetworkProxiesHTTPSProxy as String] as? String == "proxy.example")
        #expect(proxyDictionary?[kCFNetworkProxiesHTTPSPort as String] as? Int == 8080)
    }

    @Test func proxyDictionary_parsesNoProxyExceptions() {
        let proxyDictionary = RESTAPIClient.makeProxyDictionary(environment: [
            "HTTP_PROXY": "proxy.example:8080",
            "NO_PROXY": "localhost, 127.0.0.1, .example.com",
        ])
        let exceptions = proxyDictionary?[kCFNetworkProxiesExceptionsList as String] as? [String]
        #expect(exceptions == ["localhost", "127.0.0.1", ".example.com"])
    }
}

struct WorkweekGoalCalculatorTests {
    @Test func dailyTarget_returnsFiveWhenAveragesAreEmpty() {
        let goal = WorkweekGoalCalculator.dailyTarget(from: [:])
        #expect(goal == 5)
    }

    @Test func dailyTarget_returnsFiveWhenAllDailyAveragesAreZero() {
        let dailyAverages = [
            "Monday": 0,
            "Tuesday": 0,
            "Wednesday": 0,
            "Thursday": 0,
            "Friday": 0,
            "Saturday": 0,
            "Sunday": 0
        ]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dailyAverages)
        #expect(goal == 5)
    }

    @Test func dailyTarget_appliesMinimumFloorWhenTotalDividedByFiveIsUnderFive() {
        let dailyAverages = ["Monday": 20]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dailyAverages)
        #expect(goal == 5)
    }

    @Test func dailyTarget_includesWeekendInTotalButDividesByFive() {
        let dailyAverages = [
            "Saturday": 10,
            "Sunday": 5
        ]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dailyAverages)
        #expect(goal == 5)
    }

    @Test func dailyTarget_usesFixedWeekdayDivisorEvenWithAllSevenDaysPresent() {
        let dailyAverages = [
            "Monday": 10,
            "Tuesday": 10,
            "Wednesday": 10,
            "Thursday": 10,
            "Friday": 10,
            "Saturday": 10,
            "Sunday": 10
        ]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dailyAverages)
        #expect(goal == 14)
    }
}

struct DailyCountHistoryStoreTests {
    @Test func load_returnsEmptyHistoryWhenStorageHasNoData() throws {
        let isolatedDefaults = try makeIsolatedUserDefaults(suffix: "bootstrap")
        let userDefaults = isolatedDefaults.userDefaults

        let loaded = DailyCountHistoryStore.load(userDefaults: userDefaults)

        #expect(loaded.isEmpty)
        clear(userDefaults: userDefaults, suiteName: isolatedDefaults.suiteName)
    }

    @Test func saveAndLoad_roundTripsPersistedHistory() throws {
        let isolatedDefaults = try makeIsolatedUserDefaults(suffix: "roundtrip")
        let userDefaults = isolatedDefaults.userDefaults
        let history = [
            "2026-03-23": 3,
            "2026-03-24": 5
        ]

        DailyCountHistoryStore.save(history, userDefaults: userDefaults)
        let loaded = DailyCountHistoryStore.load(userDefaults: userDefaults)

        #expect(loaded == history)
        clear(userDefaults: userDefaults, suiteName: isolatedDefaults.suiteName)
    }

    @Test func prunedHistory_keepsBoundaryDateAndDropsOlderEntries() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 23, calendar: calendar)

        let pruned = DailyCountHistoryStore.prunedHistory(
            [
                "2025-12-28": 99,
                "2025-12-29": 4,
                "2026-03-20": 7
            ],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(pruned["2025-12-28"] == nil)
        #expect(pruned["2025-12-29"] == 4)
        #expect(pruned["2026-03-20"] == 7)
    }
}

struct WeekdayAverageCalculatorTests {
    @Test func weekdayAverages_skipMissingDaysFromDenominator() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-23": 13
        ]

        let averages = WeekdayAverageCalculator.weekdayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(averages["Monday"] == 13)
        #expect(averages["Tuesday"] == 0)
        #expect(averages["Wednesday"] == 0)
    }

    @Test func weekdayAverages_bucketCountsByMatchingWeekday() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-23": 10,
            "2026-03-24": 6
        ]

        let averages = WeekdayAverageCalculator.weekdayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(averages["Monday"] == 10)
        #expect(averages["Tuesday"] == 6)
        #expect(averages["Friday"] == 0)
    }

    @Test func weekdayAverages_alwaysRoundUpFractionalAverages() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-23": 3,
            "2026-03-16": 2
        ]

        let averages = WeekdayAverageCalculator.weekdayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(averages["Monday"] == 3)
    }

    @Test func weekdayAverages_excludesWeekendRows() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-21": 20,
            "2026-03-22": 30
        ]

        let averages = WeekdayAverageCalculator.weekdayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(averages.keys.count == 5)
        #expect(averages["Saturday"] == nil)
        #expect(averages["Sunday"] == nil)
    }

    @Test func weekdayAverages_ignoreEntriesOlderThanRollingWindow() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2025-12-22": 1300,
            "2025-12-29": 13
        ]

        let averages = WeekdayAverageCalculator.weekdayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(averages["Monday"] == 13)
    }

    @Test func allDayAverages_includesWeekendRows() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 29, calendar: calendar)
        let history = [
            "2026-03-28": 8,
            "2026-03-29": 6
        ]

        let averages = WeekdayAverageCalculator.allDayAverages(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(averages["Saturday"] == 8)
        #expect(averages["Sunday"] == 6)
        #expect(averages.keys.count == 7)
    }
}

struct WeekdayProductiveCalculatorTests {
    @Test func productiveSummary_returnsPeakPerWeekdayFromMultipleEntries() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-23": 9,
            "2026-03-16": 7,
            "2026-03-24": 5,
            "2026-03-17": 6
        ]

        let summary = WeekdayAverageCalculator.productiveSummary(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let peaks = Dictionary(uniqueKeysWithValues: summary.rows.map { ($0.day, $0.peak) })

        #expect(peaks["Monday"] == 9)
        #expect(peaks["Tuesday"] == 6)
        #expect(peaks["Wednesday"] == 0)
    }

    @Test func productiveSummary_replacesPeakWhenNewerHigherValueAppears() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-02-23": 9,
            "2026-03-23": 10
        ]

        let summary = WeekdayAverageCalculator.productiveSummary(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let peaks = Dictionary(uniqueKeysWithValues: summary.rows.map { ($0.day, $0.peak) })

        #expect(peaks["Monday"] == 10)
    }

    @Test func productiveSummary_dropsOldPeakWhenItFallsOutsideWindow() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2025-12-22": 12,
            "2026-01-05": 7
        ]

        let summary = WeekdayAverageCalculator.productiveSummary(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let peaks = Dictionary(uniqueKeysWithValues: summary.rows.map { ($0.day, $0.peak) })

        #expect(peaks["Monday"] == 7)
    }

    @Test func productiveSummary_excludesWeekendsFromRowsAndPeaks() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-21": 50,
            "2026-03-22": 60,
            "2026-03-23": 2
        ]

        let summary = WeekdayAverageCalculator.productiveSummary(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let peaks = Dictionary(uniqueKeysWithValues: summary.rows.map { ($0.day, $0.peak) })

        #expect(summary.rows.count == 5)
        #expect(peaks["Monday"] == 2)
        #expect(peaks["Friday"] == 0)
    }

    @Test func productiveSummary_returnsAllTiedWinners() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)
        let history = [
            "2026-03-23": 8,
            "2026-03-24": 8,
            "2026-03-25": 4
        ]

        let summary = WeekdayAverageCalculator.productiveSummary(
            from: history,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(summary.winners == Set(["Monday", "Tuesday"]))
    }
}

struct DailyHistoryBreakUpdateIntegrationTests {
    @Test func updateDailyHistoryForCurrentDay_incrementsTodayAndPrunesOldEntries() throws {
        let isolatedDefaults = try makeIsolatedUserDefaults(suffix: "integration")
        let userDefaults = isolatedDefaults.userDefaults
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 27, calendar: calendar)

        DailyCountHistoryStore.save(
            [
                "2025-12-22": 50,
                "2026-03-27": 1
            ],
            userDefaults: userDefaults
        )
        dailyHistoryCounts = [:]

        let updated = updateDailyHistoryForCurrentDay(
            on: referenceDate,
            calendar: calendar,
            userDefaults: userDefaults
        )

        #expect(updated["2025-12-22"] == nil)
        #expect(updated["2026-03-27"] == 2)
        #expect(DailyCountHistoryStore.load(userDefaults: userDefaults)["2026-03-27"] == 2)
        clear(userDefaults: userDefaults, suiteName: isolatedDefaults.suiteName)
    }
}

private func makeIsolatedUserDefaults(suffix: String) throws -> (userDefaults: UserDefaults, suiteName: String) {
    let suiteName = "kitkat.tests.\(suffix).\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        throw NSError(domain: "kitkatTests", code: 1)
    }
    userDefaults.removePersistentDomain(forName: suiteName)
    return (userDefaults, suiteName)
}

private func clear(userDefaults: UserDefaults, suiteName: String) {
    userDefaults.removePersistentDomain(forName: suiteName)
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return calendar.date(from: components) ?? Date()
}

private final class TrustCheckerMock: KeyboardAccessTrustChecking {
    private let responses: [Bool]
    private var currentIndex: Int = 0
    private(set) var promptFlags: [Bool] = []

    init(responses: [Bool]) {
        self.responses = responses
    }

    func isKeyboardAccessTrusted(promptIfNeeded: Bool) -> Bool {
        promptFlags.append(promptIfNeeded)
        let safeIndex = min(currentIndex, max(responses.count - 1, 0))
        currentIndex += 1
        return responses[safeIndex]
    }
}

private final class GlobalEventMonitorDelegateSpy: GlobalEventMonitorDelegate {
    private(set) var statuses: [KeyboardAccessStatus] = []

    func globalEventMonitor(
        _ monitor: GlobalEventMonitor,
        didUpdateKeyboardAccessStatus status: KeyboardAccessStatus
    ) {
        statuses.append(status)
    }
}

struct KeyboardAccessStatusTests {
    @Test func connectedStatus_usesGreenKeyboardIconAndOnLabel() {
        #expect(KeyboardAccessStatus.connected.iconSystemName == "keyboard.fill")
        #expect(KeyboardAccessStatus.connected.accessibilityText == "Input Monitoring: On")
    }

    @Test func disconnectedStatus_usesDisconnectedIconAndOffLabel() {
        #expect(KeyboardAccessStatus.disconnected.iconSystemName == "keyboard.badge.exclamationmark")
        #expect(KeyboardAccessStatus.disconnected.accessibilityText == "Input Monitoring: Off")
    }
}

struct CountDownTimerActivityTests {
    @Test func continueCounter_startsCountdownAndClearsIdleCount() {
        let timer = CountDownTimer()
        timer.state = .pause
        timer.idleCount = 4

        timer.continueCounter()

        #expect(timer.state == .run)
        #expect(timer.idleCount == 0)
    }
}

struct GlobalEventMonitorPermissionTests {
    @Test func refreshKeyboardAccessStatus_mapsTrustedToConnected() {
        let trustChecker = TrustCheckerMock(responses: [true])
        let monitor = GlobalEventMonitor(counter: CountDownTimer(), trustChecker: trustChecker)
        let delegate = GlobalEventMonitorDelegateSpy()
        monitor.delegate = delegate

        monitor.refreshKeyboardAccessStatus(promptForPermission: false)

        #expect(delegate.statuses == [.connected])
        #expect(trustChecker.promptFlags == [false])
    }

    @Test func refreshKeyboardAccessStatus_mapsUntrustedToDisconnected() {
        let trustChecker = TrustCheckerMock(responses: [false])
        let monitor = GlobalEventMonitor(counter: CountDownTimer(), trustChecker: trustChecker)
        let delegate = GlobalEventMonitorDelegateSpy()
        monitor.delegate = delegate

        monitor.refreshKeyboardAccessStatus(promptForPermission: false)

        #expect(delegate.statuses == [.disconnected])
        #expect(trustChecker.promptFlags == [false])
    }

    @Test func refreshKeyboardAccessStatus_supportsPromptedAndUnpromptedChecks() {
        let trustChecker = TrustCheckerMock(responses: [false, true, true])
        let monitor = GlobalEventMonitor(counter: CountDownTimer(), trustChecker: trustChecker)
        let delegate = GlobalEventMonitorDelegateSpy()
        monitor.delegate = delegate

        monitor.refreshKeyboardAccessStatus(promptForPermission: true)
        monitor.refreshKeyboardAccessStatus(promptForPermission: false)
        monitor.refreshKeyboardAccessStatus(promptForPermission: false)

        #expect(trustChecker.promptFlags == [true, false, false])
        #expect(delegate.statuses == [.disconnected, .connected, .connected])
    }
}

private final class KeyboardAccessMonitorMock: KeyboardAccessMonitoring {
    weak var delegate: GlobalEventMonitorDelegate?
    private(set) var promptFlags: [Bool] = []

    func start() {}
    func stop() {}

    func refreshKeyboardAccessStatus(promptForPermission: Bool) {
        promptFlags.append(promptForPermission)
    }
}

struct AppDelegateKeyboardRefreshTests {
    @Test func applicationDidBecomeActive_refreshesWithoutPrompt() {
        let appDelegate = AppDelegate()
        let monitor = KeyboardAccessMonitorMock()
        appDelegate.globalEventMonitor = monitor
        monitor.delegate = appDelegate

        appDelegate.applicationDidBecomeActive(
            Notification(name: NSApplication.didBecomeActiveNotification)
        )

        #expect(monitor.promptFlags == [false])
    }

    @Test func periodicPollingRefresh_usesUnpromptedCheck() {
        let appDelegate = AppDelegate()
        let monitor = KeyboardAccessMonitorMock()
        appDelegate.globalEventMonitor = monitor
        monitor.delegate = appDelegate

        appDelegate.refreshKeyboardAccessStatusForPeriodicPolling()

        #expect(monitor.promptFlags == [false])
    }
}

struct StretchSuggestionRotationTests {
    private let catalog = [
        StretchSuggestion(id: "a", title: "A", detail: "detail a", systemImage: "1.circle"),
        StretchSuggestion(id: "b", title: "B", detail: "detail b", systemImage: "2.circle"),
        StretchSuggestion(id: "c", title: "C", detail: "detail c", systemImage: "3.circle")
    ]

    @Test func rotation_startsAtCatalogHeadForFirstBreak() {
        let rotation = StretchSuggestion.rotation(count: 2, breakIndex: 0, from: catalog)

        #expect(rotation.map(\.id) == ["a", "b"])
    }

    @Test func rotation_advancesWindowOnEachSubsequentBreak() {
        let first = StretchSuggestion.rotation(count: 2, breakIndex: 0, from: catalog)
        let second = StretchSuggestion.rotation(count: 2, breakIndex: 1, from: catalog)

        #expect(second.map(\.id) == ["b", "c"])
        #expect(first.map(\.id) != second.map(\.id))
    }

    @Test func rotation_wrapsAroundPastEndOfCatalog() {
        let rotation = StretchSuggestion.rotation(count: 2, breakIndex: 2, from: catalog)

        #expect(rotation.map(\.id) == ["c", "a"])
    }

    @Test func rotation_wrapsAroundForBreakIndexBeyondCatalogLength() {
        let rotation = StretchSuggestion.rotation(count: 2, breakIndex: 4, from: catalog)

        #expect(rotation.map(\.id) == ["b", "c"])
    }

    @Test func rotation_clampsWindowToCatalogSizeWithoutRepeating() {
        let rotation = StretchSuggestion.rotation(count: 10, breakIndex: 1, from: catalog)

        #expect(rotation.count == catalog.count)
        #expect(Set(rotation.map(\.id)).count == catalog.count)
    }

    @Test func rotation_returnsEmptyForEmptyCatalogOrNonPositiveCount() {
        #expect(StretchSuggestion.rotation(count: 4, breakIndex: 0, from: []).isEmpty)
        #expect(StretchSuggestion.rotation(count: 0, breakIndex: 0, from: catalog).isEmpty)
    }

    @Test func defaultCatalog_hasUniqueIdsAndPopulatedCopy() {
        let ids = StretchSuggestion.catalog.map(\.id)

        #expect(Set(ids).count == ids.count)
        #expect(StretchSuggestion.catalog.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }
}
