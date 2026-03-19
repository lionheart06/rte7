//
//  kitkatTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 2/23/26.
//

import Foundation
import CFNetwork
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
