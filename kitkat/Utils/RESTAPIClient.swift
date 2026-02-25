//
//  RESTAPIClient.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  RESTAPIClient.swift
//  rte7
//
//  Created by Richard El Kadi on 8/21/24.
//

import Foundation

class RESTAPIClient {
    
    // MARK: - Properties
    private let session: URLSession
    private let baseURL: String
    
    // MARK: - Initialization
    init(baseURL: String) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // Set timeout to 30 seconds
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - HTTP Methods
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    // MARK: - API Call Method
    func request<T: Codable>(_ endpoint: String,
                             method: HTTPMethod = .get,
                             parameters: [String: Any]? = nil,
                             completion: @escaping (Result<T, Error>) -> Void) {
        
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
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
}
