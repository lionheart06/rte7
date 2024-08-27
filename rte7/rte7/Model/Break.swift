//
//  File.swift
//  rte7
//
//  Created by Richard El Kadi on 5/31/24.
//

import Foundation


struct Break: Identifiable {
    let id = UUID()
    var period:Int
    
    init(period:Int) {
        self.period = period
    }
    
    
    static func example() -> Break {
        Break(period:30);
    }
}
