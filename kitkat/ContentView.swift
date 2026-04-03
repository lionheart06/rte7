//
//  ContentView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//

import SwiftUI
import SwiftData
import Charts

struct IdentifiableString: Identifiable {
    let id = UUID()
    let text: String
}

struct ContentView: View {
    @Binding var dayOfWeekCounts: [String:Int]
    @Binding var dailyHistoryCounts: [String:Int]
    @Binding var menuText: String
    @Binding var idleCount: Int
    @Binding var keyboardAccessStatus: KeyboardAccessStatus
    // @EnvironmentObject var windowController: WindowController
    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                GroupBox("Count & Idle") {
                    VStack(spacing: 8) {
                        Text("KitKat. Take a Break")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: keyboardAccessStatus.iconSystemName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    keyboardAccessStatus == .connected ? .green : Color.orange
                                )
                            Text(keyboardAccessStatus.accessibilityText)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(keyboardAccessStatus.accessibilityText)

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
                }
                .frame(maxWidth: .infinity)
                .groupBoxStyle(.automatic)

                GroupBox("Workweek Average Goal") {
                    HStack(alignment: .center, spacing: 16) {
                        CoffeeCupGoalView(
                            progress: coffeeFillProgress,
                            todayCount: todayCount,
                            goalCount: averagePerWorkdayGoal,
                            isUnlocked: hasReachedCoffeeGoal
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Average per day to reach")
                                .foregroundStyle(.secondary)
                            Text(hasReachedCoffeeGoal ? "Goal reached for today. Coffee unlocked." : "Fill the cup by meeting your daily goal.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Text("\(averagePerWorkdayGoal)")
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .padding(.trailing, 50)
                    }
                }
                .frame(maxWidth: .infinity)
                .groupBoxStyle(.automatic)
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 16) {
                GroupBox("Daily Streak") {
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
                    .frame(height: dailyStreakTableHeight)
                }
                .frame(maxWidth: .infinity)
                .groupBoxStyle(.automatic)

                GroupBox("Weekday Averages (Last 13 Weeks)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Chart(weekdayAverageItems) { item in
                            BarMark(
                                x: .value("Weekday", item.day),
                                y: .value("Average", item.average),
                                width: .fixed(14)
                            )
                            .foregroundStyle(color(for: item.day))
                            .annotation(position: .top, spacing: 4) {
                                Text("\(item.average)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartYScale(domain: 0...averageChartUpperBound)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 220)

                        Text("Rounded up average breaks per weekday (only days with data, Monday-Friday).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .groupBoxStyle(.automatic)

                GroupBox("Weekday Most Productive (Last 13 Weeks)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Chart(weekdayProductiveItems) { item in
                            BarMark(
                                x: .value("Weekday", item.day),
                                y: .value("Peak", item.peak),
                                width: .fixed(14)
                            )
                            .foregroundStyle(productiveColor(for: item.day))
                            .annotation(position: .top, spacing: 4) {
                                Text("\(item.peak)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartYScale(domain: 0...productiveChartUpperBound)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 220)

                        Text("Peak single-day breaks per weekday in rolling 13 weeks (Monday-Friday).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .groupBoxStyle(.automatic)
            }
            .frame(maxWidth: .infinity)
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

    private var weekdayAverageItems: [WeekdayAverageRow] {
        WeekdayAverageCalculator.averageRows(from: dailyHistoryCounts)
    }

    private var averageChartUpperBound: Int {
        max(1, (weekdayAverageItems.map(\.average).max() ?? 0) + 1)
    }

    private var weekdayProductiveSummary: WeekdayProductiveSummary {
        WeekdayAverageCalculator.productiveSummary(from: dailyHistoryCounts)
    }

    private var weekdayProductiveItems: [WeekdayProductiveRow] {
        weekdayProductiveSummary.rows
    }

    private var productiveChartUpperBound: Int {
        max(1, (weekdayProductiveItems.map(\.peak).max() ?? 0) + 1)
    }

    private var productiveWinners: Set<String> {
        weekdayProductiveSummary.winners
    }

    private var dailyStreakTableHeight: CGFloat {
        260
    }

    private var averagePerWorkdayGoal: Int {
        let allDayAverages = WeekdayAverageCalculator.allDayAverages(
            from: dailyHistoryCounts
        )
        return WorkweekGoalCalculator.dailyTarget(from: allDayAverages)
    }

    private var todayCount: Int {
        dayOfWeekCounts[currentDay] ?? 0
    }

    private var hasReachedCoffeeGoal: Bool {
        todayCount >= averagePerWorkdayGoal
    }

    private var coffeeFillProgress: Double {
        return min(Double(todayCount) / Double(averagePerWorkdayGoal), 1.0)
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

    private func productiveColor(for day: String) -> Color {
        productiveWinners.contains(day)
            ? Color(red: 0.0, green: 0.35, blue: 0.12)
            : Color.secondary.opacity(0.5)
    }
}

struct DayCount:Identifiable {
    let id = UUID()
    let day: String
    let count: Int
}

struct CoffeeCupGoalView: View {
    let progress: Double
    let todayCount: Int
    let goalCount: Int
    let isUnlocked: Bool

    private let cupBodyWidth: CGFloat = 72
    private let cupHeight: CGFloat = 62
    private let handleWidth: CGFloat = 22

    private var normalizedProgress: CGFloat {
        CGFloat(max(0, min(progress, 1)))
    }

    private var liquidHeight: CGFloat {
        (cupHeight - 6) * normalizedProgress
    }

    private var outlineColor: Color {
        isUnlocked ? Color(red: 0.38, green: 0.20, blue: 0.08) : .secondary
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ZStack {
                    VStack(spacing: 0) {
                        if liquidHeight > 0 {
                            ZStack(alignment: .top) {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.56, green: 0.34, blue: 0.18),
                                                Color(red: 0.34, green: 0.20, blue: 0.10)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                Rectangle()
                                    .fill(Color(red: 0.77, green: 0.57, blue: 0.36).opacity(0.65))
                                    .frame(height: 1.5)
                            }
                            .frame(height: liquidHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(3)
                    .clipShape(CoffeeCupBodyShape())
                    .animation(.easeInOut(duration: 0.35), value: normalizedProgress)

                    CoffeeCupBodyShape()
                        .stroke(outlineColor, lineWidth: 2)
                }
                .frame(width: cupBodyWidth, height: cupHeight)

                CoffeeCupHandleShape()
                    .stroke(outlineColor, lineWidth: 2)
                    .frame(width: handleWidth, height: 28)
                    .offset(x: cupBodyWidth / 2 + 7, y: 4)
            }
            .frame(width: cupBodyWidth + handleWidth + 8, height: cupHeight)
            .overlay(alignment: .top) {
                if isUnlocked {
                    Image(systemName: "steam.lines.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.29, blue: 0.18))
                        .offset(y: -18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Text("\(todayCount) / \(goalCount)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 92)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStatus)
    }

    private var accessibilityStatus: String {
        if isUnlocked {
            return "Coffee unlocked. \(todayCount) of \(goalCount) breaks today."
        }
        return "Coffee progress. \(todayCount) of \(goalCount) breaks today."
    }
}

struct CoffeeCupBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * 0.08
        let bottomInset = rect.width * 0.24
        let topY = rect.minY + 2
        let bottomY = rect.maxY - 2
        let rimRadius = min(7, rect.width * 0.12)
        let baseRadius = min(6, rect.width * 0.10)

        let topLeft = CGPoint(x: rect.minX + topInset, y: topY)
        let topRight = CGPoint(x: rect.maxX - topInset, y: topY)
        let bottomRight = CGPoint(x: rect.maxX - bottomInset, y: bottomY)
        let bottomLeft = CGPoint(x: rect.minX + bottomInset, y: bottomY)

        var path = Path()
        path.move(to: CGPoint(x: topLeft.x + rimRadius, y: topLeft.y))
        path.addLine(to: CGPoint(x: topRight.x - rimRadius, y: topRight.y))
        path.addQuadCurve(
            to: CGPoint(x: topRight.x, y: topRight.y + rimRadius),
            control: topRight
        )
        path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - baseRadius))
        path.addQuadCurve(
            to: CGPoint(x: bottomRight.x - baseRadius, y: bottomRight.y),
            control: bottomRight
        )
        path.addLine(to: CGPoint(x: bottomLeft.x + baseRadius, y: bottomLeft.y))
        path.addQuadCurve(
            to: CGPoint(x: bottomLeft.x, y: bottomLeft.y - baseRadius),
            control: bottomLeft
        )
        path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + rimRadius))
        path.addQuadCurve(
            to: CGPoint(x: topLeft.x + rimRadius, y: topLeft.y),
            control: topLeft
        )
        path.closeSubpath()
        return path
    }
}

struct CoffeeCupHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let outer = rect.insetBy(dx: 1, dy: 1)
        let outerRadius = min(outer.width, outer.height) / 2
        let innerRadius = max(outerRadius - 5, 1)
        let startRadians = -70.0 * Double.pi / 180.0

        var path = Path()
        path.addArc(
            center: CGPoint(x: outer.midX, y: outer.midY),
            radius: outerRadius,
            startAngle: .degrees(-70),
            endAngle: .degrees(70),
            clockwise: false
        )
        path.move(to: CGPoint(
            x: outer.midX + innerRadius * CGFloat(cos(startRadians)),
            y: outer.midY + innerRadius * CGFloat(sin(startRadians))
        ))
        path.addArc(
            center: CGPoint(x: outer.midX, y: outer.midY),
            radius: innerRadius,
            startAngle: .degrees(-70),
            endAngle: .degrees(70),
            clockwise: false
        )
        return path
    }
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
    @State static var keyboardAccessStatus: KeyboardAccessStatus = .connected
    @State static var sampleDailyHistoryData: [String: Int] = [
        "2026-01-05": 4,
        "2026-01-06": 2,
        "2026-01-07": 5,
        "2026-01-08": 3,
        "2026-01-09": 1,
        "2026-01-12": 3,
        "2026-01-13": 4,
        "2026-01-14": 6,
        "2026-01-15": 2,
        "2026-01-16": 4
    ]

    static var previews: some View {
        ContentView(
            dayOfWeekCounts: $sampleData,
            dailyHistoryCounts: $sampleDailyHistoryData,
            menuText: $menuText,
            idleCount: $idleCount,
            keyboardAccessStatus: $keyboardAccessStatus
        )
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
