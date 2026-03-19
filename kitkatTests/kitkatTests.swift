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
    @Test func dailyTarget_returnsFiveWhenTotalIsZero() {
        let goal = WorkweekGoalCalculator.dailyTarget(from: [:])
        #expect(goal == 5)
    }

    @Test func dailyTarget_returnsFiveWhenAverageIsFour() {
        let dayCounts = ["Monday": 20]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dayCounts)
        #expect(goal == 5)
    }

    @Test func dailyTarget_returnsFiveWhenAverageIsExactlyFive() {
        let dayCounts = ["Monday": 25]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dayCounts)
        #expect(goal == 5)
    }

    @Test func dailyTarget_roundsUpWhenAverageIsFivePointTwo() {
        let dayCounts = ["Monday": 26]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dayCounts)
        #expect(goal == 6)
    }

    @Test func dailyTarget_roundsUpWhenAverageIsFivePointEight() {
        let dayCounts = ["Monday": 29]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dayCounts)
        #expect(goal == 6)
    }

    @Test func dailyTarget_usesAllDaysTotalWithDivisorFive() {
        let dayCounts = ["Saturday": 30]
        let goal = WorkweekGoalCalculator.dailyTarget(from: dayCounts)
        #expect(goal == 6)
    }
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
        #expect(KeyboardAccessStatus.connected.accessibilityText == "Keyboard access: On")
    }

    @Test func disconnectedStatus_usesDisconnectedIconAndOffLabel() {
        #expect(KeyboardAccessStatus.disconnected.iconSystemName == "keyboard.badge.exclamationmark")
        #expect(KeyboardAccessStatus.disconnected.accessibilityText == "Keyboard access: Off")
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
