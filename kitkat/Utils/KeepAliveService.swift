//
//  KeepAliveService.swift
//  kitkat
//
//  Created by Codex on 3/18/26.
//

import Foundation

final class KeepAliveService {
    private let apiClient: RESTAPIClient
    private let keepAliveEndpoint: String

    init(baseURL: String = "http://saida.oraclecorp.com",
         endpoint: String? = ProcessInfo.processInfo.environment["KITKAT_KEEPALIVE_ENDPOINT"]) {
        self.apiClient = RESTAPIClient(baseURL: baseURL)
        let trimmedEndpoint = endpoint?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedEndpoint, !trimmedEndpoint.isEmpty {
            self.keepAliveEndpoint = trimmedEndpoint
        } else {
            self.keepAliveEndpoint = "/api/keepalive"
        }
    }

    func sendKeepAlive() {
        apiClient.requestVoid(keepAliveEndpoint, method: .post) { result in
            switch result {
            case .success:
                Logger.shared.log("Keepalive POST succeeded at endpoint: \(self.keepAliveEndpoint)")
            case .failure(let error):
                Logger.shared.log("Keepalive POST failed at endpoint \(self.keepAliveEndpoint): \(error.localizedDescription)", level: .error)
            }
        }
    }
}
