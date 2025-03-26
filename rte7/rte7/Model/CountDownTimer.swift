//
//  CountDownTimer.swift
//  rte7
//
//  Created by Richard El Kadi on 6/13/24.
//

import Foundation
import UserNotifications

enum CounterState {
    case run
    case pause
}

let PERIOD:Int = 30

class CountDownTimer {
    var timer:Timer?
    var state:CounterState = CounterState.pause
    var count:Int = PERIOD
    var idleCount:Int = 0
    var app:AppDelegate?
 
 func startTimer() {
 timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true, block: {_ in
     if (self.state == CounterState.pause) {
         self.idleCount += 1
     } else {
         self.idleCount = 0
     }
     if (self.idleCount >= PERIOD) {
         self.count = PERIOD
         self.idleCount = 0
     }
     
 if (self.state == CounterState.run) {
     //self.state = CounterState.pause
     let value: Int = self.count
     self.app?.setMenuText(text:String(value))
     self.count -= 1
     if self.count <= 0 {
         let content = UNMutableNotificationContent()
         content.title = "Notification Title"
         content.body = "This is the notification message."
         content.sound = UNNotificationSound.default
         let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats:false)
         let request = UNNotificationRequest(identifier: "notifcation.id", content: content, trigger: trigger)
         UNUserNotificationCenter.current().add(request) { error in
             if let error = error {
                 Logger.shared.log("Error scheduling notification: \(error.localizedDescription)", level: .error)
             } else {
                 Logger.shared.log("Notification scheduled successfully")
             }
         }
         NotificationCenter.default.post(name: Notification.Name("ShowMainWindow"), object: nil)
 
         self.count = PERIOD
         updateCountForCurrentDay()
         self.app?.setDayOfWeekCounts(dayOfWeekCounts:dayOfWeekCounts)
     }
    }
 })
 RunLoop.main.add(timer!, forMode:RunLoop.Mode.common)
 }
 
 func stopTimer() {
     timer?.invalidate()
 }
 
 func continueCounter() {
     self.state = CounterState.run
 }
 
 func setDelegate(appDelegate:AppDelegate) {
     self.app = appDelegate
    }
 }

// Initialize the dictionary with default counts for each day of the week.
var dayOfWeekCounts: [String: Int] = [
    "Monday": 0,
    "Tuesday": 0,
    "Wednesday": 0,
    "Thursday": 0,
    "Friday": 0,
    "Saturday": 0,
    "Sunday": 0
]

var g_dayOfWeek = ""

// Function to update the count for the current day of the week.
func updateCountForCurrentDay() {
    // Get the current date.
    let currentDate = Date()
    let calendar = Calendar.current
    
    // Extract the day of the week as a string (e.g., "Monday").
    let dayOfWeek = calendar.weekdaySymbols[calendar.component(.weekday, from: currentDate) - 1]
    if (g_dayOfWeek != dayOfWeek) {
        if g_dayOfWeek != "" {
            dayOfWeekCounts[g_dayOfWeek] = 0
        }
        g_dayOfWeek = dayOfWeek
    }
    // Update the count for the current day.
    if let currentCount = dayOfWeekCounts[dayOfWeek] {
        dayOfWeekCounts[dayOfWeek] = currentCount + 1
    }
    
    print("Updated count for \(dayOfWeek): \(dayOfWeekCounts[dayOfWeek] ?? 0)")
}
 
