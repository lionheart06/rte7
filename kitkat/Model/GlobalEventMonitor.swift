//
//  GlobalEventMonitor.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  GlobalEventMonitor.swift
//  rte7
//
//  Created by Richard El Kadi on 6/4/24.
//

import Cocoa
import ApplicationServices


 class GlobalEventMonitor {
 private var monitor: Any?
 private var counter: CountDownTimer
 
     init(counter:CountDownTimer) {
         self.counter = counter
     }
 
     func start() {
         counter.continueCounter()
         NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
             self.counter.continueCounter()
             return event // return nil to consume the event (prevent further handling)
         }
         monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: {event in self.handleKeyboardEvent(event)})
         Logger.shared.log("GlobalMonitor added")
         let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
         let options: CFDictionary = [promptKey: true] as CFDictionary
         let trusted = AXIsProcessTrustedWithOptions(options)
         if (trusted) {
             Logger.shared.log("KitKat is allowed to listen to keyboard input")
         } else {
             Logger.shared.log("KitKat is NOT ALLOWED to listen to keyboard input")
         }
     }
 
     func stop() {
         if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
             self.monitor = nil
         }
     }
 
     private func handleKeyboardEvent(_ event: NSEvent) {
         counter.continueCounter()
         Logger.shared.log("Keyboard is Clicked")
     }
 }
 
