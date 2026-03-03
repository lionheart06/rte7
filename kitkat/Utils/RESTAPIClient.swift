//
//  RESTAPIClient.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//

import Foundation
import CFNetwork

final class RESTAPIClient {
    
    // MARK: - Properties
    private let session: URLSession
    private let baseURLString: String
    private let baseURL: URL?
    
    // MARK: - Initialization
    init(baseURL: String) {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURLString = trimmedBaseURL
        if let url = URL(string: trimmedBaseURL), url.scheme != nil, url.host != nil {
            self.baseURL = url.appendingPathComponent("")
        } else {
            self.baseURL = nil
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // Set timeout to 30 seconds

        if let proxyDictionary = Self.makeProxyDictionary(environment: ProcessInfo.processInfo.environment) {
            config.connectionProxyDictionary = proxyDictionary
        }

        self.session = URLSession(configuration: config)
    }
    
    // MARK: - HTTP Methods
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    enum RESTAPIClientError: LocalizedError {
        case invalidBaseURL(String)
        case couldNotFormURL(baseURL: String, endpoint: String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL(let baseURL):
                return "Invalid base URL: \(baseURL)"
            case .couldNotFormURL(let baseURL, let endpoint):
                return "Couldn’t form URL from baseURL=\(baseURL) and endpoint=\(endpoint)"
            }
        }
    }

    // MARK: - API Call Method
    func request<T: Codable>(_ endpoint: String,
                             method: HTTPMethod = .get,
                             parameters: [String: Any]? = nil,
                             completion: @escaping (Result<T, Error>) -> Void) {
        
        let url: URL
        do {
            url = try makeURL(endpoint: endpoint)
        } catch {
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let decodedObject = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedObject))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }

    func makeURL(endpoint: String) throws -> URL {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        if let absolute = URL(string: trimmedEndpoint), absolute.scheme != nil, absolute.host != nil {
            return absolute
        }

        guard let baseURL else {
            throw RESTAPIClientError.invalidBaseURL(baseURLString)
        }

        if trimmedEndpoint.isEmpty {
            return baseURL
        }

        guard let url = URL(string: trimmedEndpoint, relativeTo: baseURL)?.absoluteURL else {
            throw RESTAPIClientError.couldNotFormURL(baseURL: baseURLString, endpoint: trimmedEndpoint)
        }

        return url
    }

    static func makeProxyDictionary(environment: [String: String]) -> [AnyHashable: Any]? {
        let env = environment.reduce(into: [String: String]()) { partialResult, pair in
            partialResult[pair.key.lowercased()] = pair.value
        }

        let httpProxyValue = env["http_proxy"] ?? env["all_proxy"]
        let httpsProxyValue = env["https_proxy"] ?? env["all_proxy"]
        let noProxyValue = env["no_proxy"]

        var httpProxy = ProxyEndpoint.parse(from: httpProxyValue)
        var httpsProxy = ProxyEndpoint.parse(from: httpsProxyValue)

        if httpProxy == nil, httpsProxy == nil {
            return nil
        }

        if httpProxy == nil { httpProxy = httpsProxy }
        if httpsProxy == nil { httpsProxy = httpProxy }

        var dictionary: [AnyHashable: Any] = [:]

        if let httpProxy {
            dictionary[kCFNetworkProxiesHTTPEnable as String] = 1
            dictionary[kCFNetworkProxiesHTTPProxy as String] = httpProxy.host
            dictionary[kCFNetworkProxiesHTTPPort as String] = httpProxy.port
        }

        if let httpsProxy {
            dictionary[kCFNetworkProxiesHTTPSEnable as String] = 1
            dictionary[kCFNetworkProxiesHTTPSProxy as String] = httpsProxy.host
            dictionary[kCFNetworkProxiesHTTPSPort as String] = httpsProxy.port
        }

        if let exceptionsList = noProxyValue?
            .split(separator: ",")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }),
           !exceptionsList.isEmpty
        {
            dictionary[kCFNetworkProxiesExceptionsList as String] = exceptionsList
        }

        return dictionary.isEmpty ? nil : dictionary
    }
}

private struct ProxyEndpoint: Equatable {
    let host: String
    let port: Int

    static func parse(from value: String?) -> ProxyEndpoint? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        let candidateURLString: String
        if trimmedValue.contains("://") {
            candidateURLString = trimmedValue
        } else {
            candidateURLString = "http://\(trimmedValue)"
        }

        guard let components = URLComponents(string: candidateURLString),
              let host = components.host, !host.isEmpty
        else {
            return nil
        }

        let port = components.port ?? (components.scheme?.lowercased() == "https" ? 443 : 80)
        return ProxyEndpoint(host: host, port: port)
    }
}
