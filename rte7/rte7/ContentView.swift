//
//  ContentView.swift
//  rte7
//
//  Created by Richard El Kadi on 5/13/24.
//

import SwiftUI

struct IdentifiableString: Identifiable {
    let id = UUID()
    let text: String
}

struct ContentView: View {
    @Binding var dayOfWeekCounts: [String:Int]
    @EnvironmentObject var windowController: WindowController
    var body: some View {
        VStack {
            Text("KitKat. Take a break")
            /*Button("Close Window") {
                windowController.isVisible = false
            }*/
            
            Table(items) {
                TableColumn("Day", value: \.day)
                TableColumn("Count") { item in
                    Text("\(item.count)")
                }
            }
        }
    }
    
    private var items: [DayCount] {
        let days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
        
        var items: [DayCount] = []
        days.forEach{ day in
            items.append(DayCount(day:day, count:dayOfWeekCounts[day] ?? 0 ))
        }
   
        return items
    }
}

struct DayCount:Identifiable {
    let id = UUID()
    let day: String
    let count: Int
}

struct ContentView_Previews: PreviewProvider {
    @State static var sampleData: [String: Int] = [
        "Monday": 5,
        "Tuesday": 3,
        "Wednesday": 7,
        "Thursday": 2,
        "Friday": 6,
        "Saturday": 8,
        "Sunday": 4
    ]
    
    static var previews: some View {
        ContentView(dayOfWeekCounts: $sampleData)
    }
}
