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

private let PERIOD_SECONDS = PERIOD * 60

class CountDownTimer {
    var timer:Timer?
    var state:CounterState = CounterState.pause
    var remainingSeconds:Int = PERIOD_SECONDS
    var idleSeconds:Int = 0
     var app:AppDelegate?
  
func startTimer() {
 timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: {[weak self] _ in
     guard let self = self else { return }
     if self.state == CounterState.pause {
         self.idleSeconds += 1
     } else {
         self.idleSeconds = 0
     }
    if self.idleSeconds >= PERIOD_SECONDS {
        self.remainingSeconds = PERIOD_SECONDS
        self.idleSeconds = 0
        self.publishCountdown()
    }
 
 if self.state == CounterState.run {
     if self.remainingSeconds > 0 {
         self.remainingSeconds -= 1
     }
     self.publishCountdown()
     if self.remainingSeconds <= 0 {
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
 
         self.remainingSeconds = PERIOD_SECONDS
         self.publishCountdown()
         updateCountForCurrentDay()
         self.app?.setDayOfWeekCounts(dayOfWeekCounts:dayOfWeekCounts)
     }
    }
})
RunLoop.main.add(timer!, forMode:RunLoop.Mode.common)
 publishCountdown()
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

    private func publishCountdown() {
        app?.setRemainingSeconds(seconds: remainingSeconds)
        let minutesRemaining = max(Int(ceil(Double(remainingSeconds) / 60.0)), 0)
        app?.setMenuText(text: String(minutesRemaining))
    }
}

// Initialize the dictionary with default counts for each day of the week.
var dayOfWeekCounts: [String: Int] = {
    let stored = DayOfWeekCounterStore.load()
    var defaults = [
        "Monday": 0,
        "Tuesday": 0,
        "Wednesday": 0,
        "Thursday": 0,
        "Friday": 0,
        "Saturday": 0,
        "Sunday": 0
    ]
    for (key, value) in stored {
        defaults[key] = value
    }
    return defaults
}()

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
        DayOfWeekCounterStore.save(dayOfWeekCounts)
    }
    
    print("Updated count for \(dayOfWeek): \(dayOfWeekCounts[dayOfWeek] ?? 0)")
}
 
