//
//  ContentView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//

import SwiftUI
import SwiftData

struct IdentifiableString: Identifiable {
    let id = UUID()
    let text: String
}

struct ContentView: View {
    @Binding var dayOfWeekCounts: [String:Int]
    @Binding var menuText: String
    @Binding var idleCount: Int
    // @EnvironmentObject var windowController: WindowController
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("KitKat. Take a Break")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .center, spacing: 24) {
                    Label {
                        Text(formattedTime)
                            .font(.system(size: 56, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "timer")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 44)

                    Label {
                        Text("Idle count: \(idleCount)")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "pause.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Next break arrives when the countdown hits zero.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            GroupBox("Weekly Break Streak") {
                Table(items) {
                    TableColumn("Day") { item in
                        Text(item.day)
                            .foregroundStyle(color(for: item.day))
                            .fontWeight(fontWeight(for: item.day))
                    }
                    TableColumn("Count") { item in
                        Text("\(item.count)")
                            .monospacedDigit()
                            .foregroundStyle(color(for: item.day))
                            .fontWeight(fontWeight(for: item.day))
                    }
                }
                .frame(maxHeight: 220)
            }
            .groupBoxStyle(.automatic)

            GroupBox("Workweek Average Goal") {
                HStack {
                    Text("Average per day to reach")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(averagePerWorkdayGoal)")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
            }
            .groupBoxStyle(.automatic)
        }
        .padding(32)
    }
    
    private var items: [DayCount] {
        let days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
        
        var items: [DayCount] = []
        days.forEach{ day in
            items.append(DayCount(day:day, count:dayOfWeekCounts[day] ?? 0 ))
        }
   
        return items
    }

    private var formattedTime: String {
        return menuText
    }

    private var averagePerWorkdayGoal: Int {
        let total = dayOfWeekCounts.values.reduce(0, +)
        let rawAverage = Double(total) / 5.0
        return Int(ceil(rawAverage))
    }

    private var currentDay: String {
        let calendar = Calendar.current
        let weekdayIndex = calendar.component(.weekday, from: Date()) - 1
        return calendar.weekdaySymbols[weekdayIndex]
    }

    private func color(for day: String) -> Color {
        isCurrentDay(day) ? Color(red: 0.0, green: 0.35, blue: 0.12) : .primary
    }

    private func fontWeight(for day: String) -> Font.Weight {
        isCurrentDay(day) ? .bold : .regular
    }

    private func isCurrentDay(_ day: String) -> Bool {
        day == currentDay
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
    @State static var menuText: String = "15"
    @State static var idleCount: Int = 4

    static var previews: some View {
        ContentView(dayOfWeekCounts: $sampleData, menuText: $menuText, idleCount: $idleCount)
    }
}

struct ContentView2: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView2()
        .modelContainer(for: Item.self, inMemory: true)
}
