//
//  BreakWindow.swift
//  rte7
//
//  Created by Richard El Kadi on 8/16/24.
//

import Foundation
import SwiftUI

struct QuoteDetails: Codable {
    let body: String
}

struct Quote:Codable {
    let qotd_date: String
    let quote: QuoteDetails
}

class BreakWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Customize window properties
        self.title = "Custom Window"
        self.center()
        self.isReleasedWhenClosed = false
    }
}

class BreakViewController: NSViewController {
    @objc dynamic var message:String = "Hello, Custom Window!"
    private var label: NSTextField!
    private var width: Int = 600
    private var height: Int = 200
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        // Add content to the view
        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 0, y: 0, width: width, height: height)
        self.view.addSubview(label)
        self.label = label
        self.addObserver(self, forKeyPath: #keyPath(message), options: [.new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(message) {
            DispatchQueue.main.async {
                self.label.stringValue = self.message
            }
        }
    }
    
    func getQuote() {
        let apiClient = RESTAPIClient(baseURL: "https://favqs.com")
        apiClient.request("/api/qotd") { (result: Result< Quote, Error>) in
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
    
    deinit {
        self.removeObserver(self, forKeyPath: #keyPath(message))
    }
}
