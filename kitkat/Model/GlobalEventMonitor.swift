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
         guard AccessibilityPermissionManager.ensureAccessibilityPermissions() else {
             Logger.shared.log("Accessibility permission not granted", level: .error)
             return
         }

         counter.continueCounter()
         monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: {event in self.handleKeyboardEvent(event)})
         Logger.shared.log("GlobalMonitor added")
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
 
