//
//  QuoteDetails.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  QuoteModel.swift
//  rte7
//
//  Created by Richard El Kadi on 8/28/24.
//

import Foundation
import Combine

struct QuoteDetails: Codable {
    let body: String
    let author: String
}

struct Quote:Codable {
    let qotd_date: String
    let quote: QuoteDetails
}

class QuoteViewModel: ObservableObject {
    @Published var message: String = "Hello, Custom Window!"
    private let apiClient = RESTAPIClient(baseURL: "https://favqs.com")
    
    func getQuote() {
        apiClient.request("/api/qotd") { (result: Result<Quote, Error>) in
            switch result {
            case .success(let quote):
                print("Hello \(quote.qotd_date)")
                DispatchQueue.main.async {
                    self.message = quote.quote.body + " - " + quote.quote.author
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}