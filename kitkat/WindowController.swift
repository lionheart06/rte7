//
//  WindowController.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  WindowController.swift
//  rte7
//
//  Created by Richard El Kadi on 6/26/24.
//

import Foundation
import Combine

class WindowController: ObservableObject {
    @Published var isVisible:Bool = true
    
    func showWindow() {
        isVisible = true
    }
}
