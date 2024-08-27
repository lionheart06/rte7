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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(windowController)
                .onAppear() {
                    self.cancellable = appDelegate.$menuText.sink { text in
                        self.menuText = text
                    }
                }
        }
            
        MenuBarExtra(menuText) {
            Button("MyApp", action:{NotificationCenter.default.post(name: Notification.Name("ShowMainWindow"), object: nil)})
            Button("Quit", action:{NSApp.terminate(self)})
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var menuText:String = "30"
    
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
            let otherWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 600, height: 200),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            otherWindow.title = "Take a break, have a kitkat"
            otherWindow.center()
            let hostingView = NSHostingView(rootView: BreakWindowSwift())
            otherWindow.contentView = hostingView
            otherWindow.makeKeyAndOrderFront(nil)
            otherWindow.isReleasedWhenClosed = false
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
}


