//
//  BreakWindowSwift.swift
//  rte7
//
//  Created by Richard El Kadi on 8/26/24.
//

import Foundation
import SwiftUI

struct BreakWindowSwift: View {
    // @Binding var isPresented: Bool
    
    var body: some View {
        BreakViewSwift().frame(width:600,height:200)
    }
    
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
                    self.message = quote.quote.body
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}

struct BreakViewSwift: View {
    @StateObject private var viewModel = QuoteViewModel()

    var body: some View {
        VStack {
          
                        Text(viewModel.message)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .multilineTextAlignment(.center)
                        
                        Button("Get Quote") {
                            viewModel.getQuote()
                        }
                    }
                    .frame(width: 600, height: 200)
        }
    
}
