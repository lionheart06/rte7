//
//  rte7App.swift
//  rte7
//
//  Created by Richard El Kadi on 5/13/24.
//

import SwiftUI
import UserNotifications

@main
struct rte7App: App {
    @StateObject private var windowController = WindowController()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var menuText = "Something"
    @State var cancellable: AnyObject? = nil
    @State var cancellable2: AnyObject? = nil
    @State private var isWindowVisible = false
    @State private var dayOfTheWeekCounts: [String: Int] = [
        "Monday":0
    ]
    
    var body: some Scene {
        WindowGroup {
            ContentView(dayOfWeekCounts: $dayOfTheWeekCounts)
                .environmentObject(windowController)
                .onAppear() {
                    self.cancellable = appDelegate.$menuText.sink { text in
                        self.menuText = text
                    }
                    self.cancellable2 = appDelegate.$dayOfTheWeekCounts.sink {d in
                        self.dayOfTheWeekCounts = d
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
            
        MenuBarExtra(menuText) {
            Button("MyApp", action:{NotificationCenter.default.post(name: Notification.Name("ShowMainWindow"), object: nil)})
            Button("Quit", action:{NSApp.terminate(self)})
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var menuText:String = "30"
    @Published var dayOfTheWeekCounts: [String:Int] = ["Monday":0]
    var window:NSWindow?
    
    var globalEventMonitor: GlobalEventMonitor!
    var countDownTimer: CountDownTimer!
    
    override init() {
        countDownTimer = CountDownTimer()
        globalEventMonitor = GlobalEventMonitor(counter:countDownTimer)
    }
    
    func applicationDidFinishLaunching(_ notification:Notification) {
        countDownTimer.setDelegate(appDelegate: self)
               
        NotificationCenter.default.addObserver(forName:Notification.Name("ShowMainWindow"),object:nil,queue:.main) { _ in
            NSApp.activate(ignoringOtherApps: true)
            self.window = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 600, height: 200),
                styleMask: [/*.titled, .closable, .miniaturizable, */.resizable],
                backing: .buffered,
                defer: false
            )
            self.window?.backgroundColor = .clear
            self.window?.isOpaque = false
            let screenFrame = NSScreen.main!.frame
                       let padding: CGFloat = 100
                       let newFrame = NSRect(
                           x: screenFrame.origin.x + padding,
                           y: screenFrame.origin.y + padding,
                           width: screenFrame.width - (padding * 2),
                           height: screenFrame.height - (padding * 2)
                       )
            
            self.window?.setFrame(newFrame, display:true)
            self.window?.titlebarAppearsTransparent = true
            self.window?.titleVisibility = .hidden
            self.window?.backgroundColor = NSColor(white: 1.0, alpha: 0.8)
            
            self.window?.title = "Take a break, have a kitkat"
            self.window?.center()
            let hostingView = NSHostingView(rootView: BreakWindow(window: self.window))
            self.window?.contentView = hostingView
            self.window?.makeKeyAndOrderFront(self)
            self.window?.isReleasedWhenClosed = false
        }
        countDownTimer.startTimer()
        globalEventMonitor.start()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // window.makeKeyAndOrderFront(self)
        }
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification:Notification) {
        //globalEventMonitor.stop()
        // countDownTimer.stopTimer()
    }
    
    func setMenuText(text:String) {
        menuText = text
    }
    
    func setDayOfWeekCounts(dayOfWeekCounts:[String:Int]) {
        dayOfTheWeekCounts = dayOfWeekCounts
    }
}


